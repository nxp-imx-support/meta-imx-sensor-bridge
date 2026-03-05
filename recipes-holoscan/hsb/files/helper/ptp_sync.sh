#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

# PTP setup and synchronization helper.
# - Single gptp.cfg used for both master and slave; slave adds -s flag to ptp4l.
# - Resilient to 'timedatectl' failures (NTP not supported).
# - Robust Ctrl+C cleanup for root-owned background phc2sys (Jetson-safe).
# - CLI options: --ptp, --iface, --role (defaults: /dev/ptp0, eth1, master).

set -euo pipefail

# -------- Defaults --------
PTP_DEV="/dev/ptp0"   # e.g., /dev/ptp0
IFACE="eth1"          # e.g., eth1 / eno1 / enp2s0
ROLE="master"         # master | slave
CFG_FILE="./gptp.cfg" # common cfg for both master and slave

# -------- Internal state --------
PHC2SYS_PID=""
PTP4L_PID=""

print_help() {
  cat <<'EOF'
Usage: ptp_sync.sh [options]

Options:
  -p, --ptp <device>     PTP device path (default: /dev/ptp0)
  -i, --iface <name>     Ethernet interface (default: eth1)
  -r, --role <role>      Role: master|slave (default: master)
  -c, --cfg <file>       ptp4l config file to use (default: ./gptp.cfg)
  -h, --help             Show this help

Examples:
  ./ptp_sync.sh
  ./ptp_sync.sh -p /dev/ptp1 -i eno1 -r slave
  ./ptp_sync.sh --ptp /dev/ptp2 --iface enp2s0 --role master --cfg /etc/ptp/gptp.cfg
EOF
}

# -------- Parse args --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--ptp)   PTP_DEV="${2:-}"; shift 2 ;;
    -i|--iface) IFACE="${2:-}";   shift 2 ;;
    -r|--role)  ROLE="${2:-}";    shift 2 ;;
    -c|--cfg)   CFG_FILE="${2:-}"; shift 2 ;;
    -h|--help)  print_help; exit 0 ;;
    *) echo "Unknown option: $1"; print_help; exit 1 ;;
  esac
done

# -------- Validate --------
if [[ ! "$ROLE" =~ ^(master|slave)$ ]]; then
  echo "ERROR: --role must be 'master' or 'slave' (got: $ROLE)"; exit 1
fi
if [[ ! -e "$PTP_DEV" ]]; then
  echo "ERROR: PTP device not found: $PTP_DEV"
  ls -l /dev/ptp* || true
  exit 1
fi
if ! ip link show "$IFACE" >/dev/null 2>&1; then
  echo "ERROR: Interface not found: $IFACE"
  echo "Available interfaces:"
  ip -o link show | awk -F': ' '{print " - " $2}'
  exit 1
fi
if [[ ! -f "$CFG_FILE" ]]; then
  echo "ERROR: Config file not found: $CFG_FILE"
  exit 1
fi

echo "=== PTP Sync Configuration ==="
echo "PTP device : $PTP_DEV"
echo "Interface  : $IFACE"
echo "Role       : $ROLE"
echo "Config     : $CFG_FILE"
echo "================================"

# -------- Cleanup on exit / Ctrl+C --------
cleanup() {
  echo -e "\n[cleanup] Stopping background processes..."

  # Kill phc2sys if started (root-owned on Jetson)
  if [[ -n "${PHC2SYS_PID}" ]]; then
    if sudo kill -0 "${PHC2SYS_PID}" 2>/dev/null; then
      echo "[cleanup] Killing phc2sys (PID ${PHC2SYS_PID})"
      sudo kill -TERM "${PHC2SYS_PID}" 2>/dev/null || true
      sleep 0.7
      if sudo kill -0 "${PHC2SYS_PID}" 2>/dev/null; then
        echo "[cleanup] Forcing phc2sys (PID ${PHC2SYS_PID})"
        sudo kill -KILL "${PHC2SYS_PID}" 2>/dev/null || true
      fi
    fi
  fi

  # If you ever background ptp4l (not in this script), stop it similarly
  if [[ -n "${PTP4L_PID}" ]]; then
    if sudo kill -0 "${PTP4L_PID}" 2>/dev/null; then
      echo "[cleanup] Killing ptp4l (PID ${PTP4L_PID})"
      sudo kill -TERM "${PTP4L_PID}" 2>/dev/null || true
      sleep 0.5
      sudo kill -KILL "${PTP4L_PID}" 2>/dev/null || true
    fi
  fi

  echo "[cleanup] Done."
}
trap cleanup EXIT INT TERM

# -------- System time setup (tolerant) --------
if ! sudo timedatectl set-ntp false; then
  echo "[warn] 'timedatectl set-ntp false' failed or NTP not supported. Continuing..."
fi
if ! sudo timedatectl set-timezone Asia/Kolkata; then
  echo "[warn] 'timedatectl set-timezone Asia/Kolkata' failed. Continuing..."
fi
# Optional manual time:
# if ! sudo timedatectl set-time '2026-01-27 14:30:15'; then
#   echo "[warn] 'timedatectl set-time' failed. Continuing..."
# fi

# -------- Inspect PTP --------
ls -l /dev/ptp* || true
sudo phc_ctl "$PTP_DEV" get || echo "[warn] phc_ctl get failed. Continuing..."

# -------- Enable HW timestamping on PHY --------
if ! sudo ethtool --set-phy-timestamp "$IFACE" on; then
  echo "[warn] '--set-phy-timestamp' may not be supported on this NIC/driver. Continuing..."
fi

# -------- PTP management client (pmc) --------
sudo pmc -u -b 0 'GET TIME_STATUS_NP' || echo "[warn] pmc query failed. Continuing..."
# sudo pmc -u -b 0 'GET GRANDMASTER_SETTINGS_NP' || true

# -------- Sync system clock from PHC (background, capture real root PID) --------
# Capture the actual phc2sys PID from inside sudo; log to /tmp/phc2sys.log
PHC2SYS_PID=$(sudo bash -c \
  "phc2sys -s \"$PTP_DEV\" -c CLOCK_REALTIME -O 0 -m > /tmp/phc2sys.log 2>&1 & echo \$!")
echo "[info] phc2sys started (PID ${PHC2SYS_PID}), logs: /tmp/phc2sys.log"

# -------- Run ptp4l in foreground (common config; add -s for slave) --------
PTP4L_ARGS=(-i "$IFACE" -f "$CFG_FILE" -m)
if [[ "$ROLE" == "slave" ]]; then
  PTP4L_ARGS=(-i "$IFACE" -f "$CFG_FILE" -s -m)
fi

echo "Starting ptp4l as ${ROLE^^} with config: $CFG_FILE"
# Foreground run; Ctrl+C will trigger trap -> cleanup -> kill phc2sys
sudo ptp4l "${PTP4L_ARGS[@]}"

# When ptp4l exits (e.g., Ctrl+C), the trap runs 'cleanup' and kills phc2sys.

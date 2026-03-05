#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

# get_clock.sh - Query PHC and system time every second, asking user for PTP device.

read -rp "Enter PTP device path (e.g., /dev/ptp0): " PTP_DEV

# Basic validation
if [[ -z "$PTP_DEV" ]]; then
  echo "Error: No device provided." >&2
  exit 1
fi

if [[ ! -e "$PTP_DEV" ]]; then
  echo "Error: Device '$PTP_DEV' does not exist." >&2
  exit 1
fi

# Ensure phc_ctl is available
if ! command -v phc_ctl >/dev/null 2>&1; then
  echo "Error: 'phc_ctl' not found in PATH." >&2
  exit 1
fi

# Trap Ctrl-C for clean exit
trap 'echo; echo "Exiting."; exit 0' INT

while true; do
    sudo phc_ctl "$PTP_DEV" get
    date -Ins
    sleep 1
done

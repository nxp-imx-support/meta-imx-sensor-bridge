#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 NXP

ifconfig eth1 down
ip addr add 192.168.1.200/24 broadcast 192.168.1.255 dev eth1
sleep 1
ifconfig eth1 up
ifconfig eth1 mtu 9000 up

insmod /lib/modules/$(uname -r)/updates/kpage_ncache/kpage_ncache.ko

mkdir -p /mnt/hugepages
mount -t hugetlbfs none /mnt/hugepages
echo 512 > /proc/sys/vm/nr_hugepages

echo 1 > /sys/bus/pci/devices/0002\:00\:10.0/sriov_numvfs
echo uio_pci_generic > /sys/bus/pci/devices/0002\:00\:12.0/driver_override
echo 0002:00:12.0 > /sys/bus/pci/drivers/fsl_enetc_vf/unbind
echo 0002:00:12.0 > /sys/bus/pci/drivers/uio_pci_generic/bind
ip link set eth1 vf 0 trust on

echo "I/F eth1 configured"

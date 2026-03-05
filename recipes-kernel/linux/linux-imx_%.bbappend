DESCRIPTION = "Enable video capture through ISI & 4K@60 Camera Module in linux-imx for i.MX95 19x19 EVK HSB"
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
    file://0001-arm64-dts-freescale-imx95-Add-OS08A20-camera-HSB-con.patch \
    file://0002-media-imx8-isi-Add-buffer-physical-address-query-sup.patch \
    file://0003-media-videobuf2-dma-contig-Enable-cached-DMA-buffer-.patch \
    file://0004-LF-15101-media-ox05b1s-Support-30-30-fps-for-OS08A20.patch \
"

KERNEL_DEVICETREE:append = " freescale/imx95-19x19-evk-os08a20-hsb.dtb"


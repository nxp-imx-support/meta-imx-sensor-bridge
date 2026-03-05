i.MX HSB demo software - Meta Layers
====================================
This layer enables NXP-supported enablement of the Holoscan Sensor
Bridge (HSB) on the i.MX95 platform, including datapath latency,
packetization enhancements, and interworking with NVIDIA Holoscan
Receiver like DGX Spark & AGX Orin.

Compile i.MX 95 EVK Yocto Image with HSB enabled
------------------------------------------------
1. Intialiaze the repo
For more information on Yocto build setup instructions, refer to the
i.MX Yocto Project User's Guide (https://www.nxp.com/docs/en/user-guide/UG10164.pdf)

```bash
$ repo init -u https://github.com/nxp-imx/imx-manifest -b imx-linux-walnascar -m imx-6.12.49-2.2.0.xml
$ repo sync
```

2. To set up HSB meta layer repo, clone and checkout required BSP branch: LF6.12.49_2.2.0

```bash
$ git clone https://github.com/nxp-imx-support/meta-imx-sensor-bridge.git
$ git checkout LF6.12.49_2.2.0
```

3. Move this repo into the 'sources' directory in your Yocto_Directory

4. Build the image

```bash
$ source sources/meta-imx-sensor-bridge/setup/setup-env-imx95-hsb -b build
$ bitbake imx-image-full -k
```

Test
----
1. Plug os08a20 (4K@60) sensor to the i.MX95 EVK board MIPI CSI
   interface using a XRPI-CAM-MINISAS adaptor board.

2. Flash a Micro SD card with "imx-image-full-imx95-19x19-lpddr5-evk.rootfs.wic.zst"
   image in build/tmp/deploy/images/imx95-19x19-lpddr5-evk/

3. Set device tree in uboot:

   ```bash
   u-boot => setenv fdtfile imx95-19x19-evk-os08a20-hsb.dtb
   u-boot => setenv mmcargs 'setenv bootargs ${jh_clk} ${mcore_args} console=${console} root=${mmcroot} default_hugepagesz=2m hugepagesz=2m hugepages=448 isolcpus=1-5 iommu.passthrough=1'
   u-boot => saveenv
   Saving Environment to MMC... Writing to MMC(1)... OK
   u-boot => boot
   ```

4. Identify capture device id for libcamera

   ```bash
   root@imx95evk:~# cam -l
    	
   Available cameras:
   1: 'os08a20' (/base/soc/bus@42000000/i2c@42530000/os08a20_mipi@36)
   ```
	
5. Run

   ```bash
   root@imx95evk:~# ./hsb_if.sh
   root@imx95evk:~# ./os08a20_media.sh
   root@imx95evk:~# ./serve_linux_stream_dpdk-roce-on 192.168.1.200 /dev/video0 -f 0
   ```


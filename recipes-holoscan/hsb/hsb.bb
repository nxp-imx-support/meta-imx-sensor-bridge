# SPDX-License-Identifier: MIT
# Copyright 2026 NXP

DESCRIPTION = "Holoscan Sensor Bridge for i.MX95 with DPDK"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=86d3f3a95c324c9479bd8986968f4327"

SRC_URI = "\
    git://github.com/nvidia-holoscan/holoscan-sensor-bridge.git;protocol=https;branch=main;lfs=0 \
    file://0001-add-support-for-cross-compilation.patch \
    file://0002-Introduce-serve_linux_stream_dpdk-with-RoCEv2-and-in.patch \
    file://helper/ \
    file://include/dlpack/dlpack.h \
"
SRCREV = "10a919f453095b9ee279d761016ead79062428ea"
S = "${WORKDIR}/git"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# --- Build dependencies ---
DEPENDS = "cmake ninja-native pkgconfig-native dpdk zlib fmt "
# Clears the version so the module calls: find_package(fmt QUIET CONFIG)
inherit cmake pkgconfig

INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
RDEPENDS:${PN} += "bash"

# --- Dual-build directories inside ${B} (the cmake class sets ${B}=${WORKDIR}/build) ---
BUILD_ROCE_ON  = "${B}/build-roce-on"
BUILD_ROCE_OFF = "${B}/build-roce-off"

# Common CMake options (adjust if your upstream adds/removes flags)
OECMAKE_COMMON = " \
    -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DHOLOLINK_BUILD_ONLY_NATIVE=ON \
    -DHOLOLINK_BUILD_PYTHON=OFF \
    -DHOLOLINK_BUILD_EXAMPLES=ON \
    -DHOLOLINK_BUILD_TESTS=OFF \
    -DHOLOLINK_BUILD_TOOLS=OFF \
    -DHOLOLINK_USE_DPDK=ON \
    -DCMAKE_PREFIX_PATH=${RECIPE_SYSROOT}${prefix}\;${WORKDIR}/sources-unpack/ \
    -Dfmt_DIR=${RECIPE_SYSROOT}/usr/lib/cmake/fmt \
    -DDLPACK_INCLUDE_DIR=${WORKDIR}/sources-unpack \
"

APP_BIN = "serve_linux_stream_dpdk"
# --- Configure twice (ROCEv2 ON/OFF) ---

do_configure() {
    cmake -S ${S} -B ${BUILD_ROCE_ON}  ${OECMAKE_COMMON} -DENABLE_ROCEV2=ON
    cmake -S ${S} -B ${BUILD_ROCE_OFF} ${OECMAKE_COMMON} -DENABLE_ROCEV2=OFF
}

# --- Build both ---
do_compile() {
    make -C ${BUILD_ROCE_ON}  -j${@oe.utils.cpu_count()}
    make -C ${BUILD_ROCE_OFF} -j${@oe.utils.cpu_count()}
}

# --- Install helpers and both binaries into /root ---
do_install() {
    # Create /root on target
    install -d ${D}/root

    # Helper scripts and configs
    for f in ${WORKDIR}/sources-unpack/helper/*; do
        if [ -f "$f" ]; then
            # If it's a .sh script, mark executable; configs remain readable
            case "$f" in
                *.sh) install -m 0755 "$f" ${D}/root/ ;;
                *)    install -m 0644 "$f" ${D}/root/ ;;
            esac
        fi
    done

    # Application binaries (ROCEv2 ON/OFF)
    # Try common output locations; adjust if your project outputs elsewhere.
    # ROCEv2 ON
    if [ -x "${BUILD_ROCE_ON}/examples/${APP_BIN}" ]; then
        install -m 0755 ${BUILD_ROCE_ON}/examples/${APP_BIN} ${D}/root/${APP_BIN}-roce-on
    else
        bbfatal "ROCEv2 ON binary '${APP_BIN}' not found; adjust install path in recipe."
    fi

    # ROCEv2 OFF
    if [ -x "${BUILD_ROCE_OFF}/examples/${APP_BIN}" ]; then
        install -m 0755 ${BUILD_ROCE_OFF}/examples/${APP_BIN} ${D}/root/${APP_BIN}-roce-off
    else
        bbfatal "ROCEv2 OFF binary '${APP_BIN}' not found; adjust install path in recipe."
    fi
}

# --- Packaging ---
# Place everything we installed under /root into the main package by default
FILES:${PN} += " /root/* "

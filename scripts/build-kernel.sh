#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

# Clone the kernel repo
if ! git -C linux-rockchip pull; then
    git clone --progress -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" linux-rockchip --depth=2
fi

cd linux-rockchip
git checkout "${KERNEL_BRANCH}"

#
sed -i 's/ap6275p/ap6276p/g' debian.rockchip/config/config.common.ubuntu
cp ../../overlay/kernel/rk3588-smart-am60.dts arch/arm64/boot/dts/rockchip/
echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-smart-am60.dtb' >> arch/arm64/boot/dts/rockchip/Makefile
sed -i '187a\        seq_puts(m, "model name\\t: Rockchip RK3588\\n");' arch/arm64/kernel/cpuinfo.c

# shellcheck disable=SC2046
export $(dpkg-architecture -aarm64)
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export LANG=C

# Compile the kernel into a deb package
fakeroot debian/rules clean binary-headers binary-rockchip do_mainline_build=true

#!/bin/bash

# machine specific information
# PATH_PPC=/opt/poky/1.4.0-1/sysroots/x86_64-pokysdk-linux/usr/bin/ppc64e5500-poky-linux
PATH_PPC=/opt/poky/1.5.1/sysroots/x86_64-pokysdk-linux/usr/bin/powerpc64-poky-linux
PATH_X86=/opt/poky/1.4.0-1/sysroots/x86_64-pokysdk-linux/usr/bin
PREFIX=powerpc64-poky-linux-
ARCH=powerpc
QEMUCMD=/opt/buildbot/bin/qemu-system-ppc
KERNEL_IMAGE=vmlinux
QEMU_MACH=mac99

PATH=${PATH_PPC}:${PATH_X86}:${PATH}
dir=$(cd $(dirname $0); pwd)

. ${dir}/../scripts/common.sh

runkernel()
{
    local defconfig=$1
    local mach=$2
    local rootfs=$3
    local dtb=$4
    local pid
    local retcode
    local logfile=/tmp/runkernel-$$.log
    local waitlist=("Restarting" "Boot successful" "Rebooting")

    echo -n "Building ${ARCH}:${defconfig} ... "

    dosetup ${ARCH} ${PREFIX} "" ${rootfs} ${defconfig}
    if [ $? -ne 0 ]
    then
	return 1
    fi

    echo -n "running ..."

    if [ "${mach}" = "mac99" ]
    then
      ${QEMUCMD} -kernel ${KERNEL_IMAGE} -M ${mach} -cpu G4 \
	-hda ${rootfs} -usb -usbdevice wacom-tablet -no-reboot -m 128 \
	--append "root=/dev/hda rw mem=128M console=ttyS0 console=tty doreboot" \
	-nographic > ${logfile} 2>&1 &
    else
      ${QEMUCMD} -kernel ${KERNEL_IMAGE} -M ${mach} -no-reboot -m 256 \
        --append "rdinit=/sbin/init console=ttyS0 console=tty doreboot" \
	-dtb ${dtb} -nographic > ${logfile} 2>&1 &
    fi

    pid=$!

    dowait ${pid} ${logfile} automatic waitlist[@]
    retcode=$?
    rm -f ${logfile}
    return ${retcode}
}

echo "Build reference: $(git describe)"
echo

VIRTEX_DTB=arch/powerpc/boot/dts/virtex440-ml507.dtb
if [ -e arch/powerpc/boot/dts/virtex440-ml507.dts ]
then
    dtc -I dts -O dtb arch/powerpc/boot/dts/virtex440-ml507.dts -o ${VIRTEX_DTB} >/dev/null 2>&1
fi

runkernel qemu_ppc_book3s_defconfig mac99 core-image-minimal-qemuppc.ext3
retcode=$?
runkernel qemu_ppc_book3s_smp_defconfig mac99 core-image-minimal-qemuppc.ext3
retcode=$((${retcode} + $?))
runkernel qemu_virtex440_defconfig virtex-ml507 busybox-ppc.cpio ${VIRTEX_DTB}
retcode=$((${retcode} + $?))

exit ${retcode}

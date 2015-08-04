#!/bin/bash

PREFIX=arm-poky-linux-gnueabi-
ARCH=arm
rootfs=core-image-minimal-qemuarm.ext3
# PATH_ARM=/opt/poky/1.3/sysroots/x86_64-pokysdk-linux/usr/bin/armv5te-poky-linux-gnueabi
PATH_ARM=/opt/poky/1.4.2/sysroots/x86_64-pokysdk-linux/usr/bin/armv7a-vfp-neon-poky-linux-gnueabi

PATH=${PATH_ARM}:${PATH}

dir=$(cd $(dirname $0); pwd)

skip_32="arm:vexpress-a15:qemu_arm_vexpress_defconfig \
	arm:vexpress-a9:multi_v7_defconfig \
	arm:vexpress-a15:multi_v7_defconfig"
skip_34="arm:versatilepb:qemu_arm_versatile_defconfig \
	arm:vexpress-a15:qemu_arm_vexpress_defconfig \
	arm:vexpress-a9:multi_v7_defconfig \
	arm:vexpress-a15:multi_v7_defconfig"
skip_310="arm:vexpress-a9:multi_v7_defconfig \
	arm:vexpress-a15:multi_v7_defconfig"

. ${dir}/../scripts/common.sh

cached_config=""

runkernel()
{
    local defconfig=$1
    local mach=$2
    local rootfs=$3
    local dtb=$4
    local dtbfile="arch/arm/boot/dts/${dtb}"
    local pid
    local retcode
    local logfile=/tmp/runkernel-$$.log
    local waitlist=("Boot successful" "Rebooting" "Restarting")
    local rel=$(git describe | cut -f1 -d- | cut -f1,2 -d. | sed -e 's/\.//' | sed -e 's/v//')
    local tmp="skip_${rel}"
    local skip=(${!tmp})
    local s
    local build=${ARCH}:${mach}:${defconfig}

    echo -n "Building ${build} ... "

    for s in ${skip[*]}
    do
	if [ "$s" = "${build}" ]
	then
	    echo "skipped"
	    return 0
	fi
    done

    if [ "${cached_config}" != "${defconfig}" ]
    then
	# KALLSYMS_EXTRA_PASS is needed for earlier kernels (3.2, 3.4) due to
	# a bug in kallsyms which would be too difficult to back-port.
	# See upstream commits f6537f2f0e and 7122c3e915.
	dosetup ${ARCH} ${PREFIX} "KALLSYMS_EXTRA_PASS=1" ${rootfs} ${defconfig}
	retcode=$?
	if [ ${retcode} -ne 0 ]
	then
	    return 1
	fi
    fi
    cached_config=${defconfig}

    echo -n "running ..."

    # if we have a dtb file use it
    dtbcmd=""
    if [ -n "${dtb}" -a -f "${dtbfile}" ]
    then
	dtbcmd="-dtb ${dtbfile}"
    fi

    if [ "${rootfs}" = "busybox-arm.cpio" ]
    then
      /opt/buildbot/bin/qemu-system-arm -M ${mach} -m 512 \
	-kernel arch/arm/boot/zImage -no-reboot \
	--append "rdinit=/sbin/init console=ttyAMA0,115200 doreboot" \
	-serial stdio -monitor null -nographic ${dtbcmd} \
	-initrd ${rootfs} > ${logfile} 2>&1 &
      pid=$!
    elif [ "${defconfig}" = "qemu_arm_versatile_defconfig" ]
    then
      /opt/buildbot/bin/qemu-system-arm  -M ${mach} \
	-kernel arch/arm/boot/zImage \
	-drive file=${rootfs},if=scsi -no-reboot \
	-m 128 ${dtbcmd} \
	--append "root=/dev/sda rw mem=128M console=ttyAMA0,115200 console=tty doreboot" \
	-nographic > ${logfile} 2>&1 & 
      pid=$!
    else
      /opt/buildbot/bin/qemu-system-arm -M ${mach} \
	-kernel arch/arm/boot/zImage \
	-drive file=${rootfs},if=sd -no-reboot \
	-append "root=/dev/mmcblk0 rw console=ttyAMA0,115200 console=tty1 doreboot" \
	-nographic ${dtbcmd} > ${logfile} 2>&1 &
      pid=$!
    fi

    dowait ${pid} ${logfile} auto waitlist[@]
    retcode=$?
    rm -f ${logfile}
    return ${retcode}
}

echo "Build reference: $(git describe)"
echo

runkernel qemu_arm_versatile_defconfig versatilepb core-image-minimal-qemuarm.ext3
retcode=$?
runkernel qemu_arm_vexpress_defconfig vexpress-a9 core-image-minimal-qemuarm.ext3 vexpress-v2p-ca9.dtb
retcode=$((${retcode} + $?))
runkernel qemu_arm_vexpress_defconfig vexpress-a15 core-image-minimal-qemuarm.ext3 vexpress-v2p-ca15-tc1.dtb
retcode=$((${retcode} + $?))
runkernel multi_v7_defconfig vexpress-a9 core-image-minimal-qemuarm.ext3 vexpress-v2p-ca9.dtb
retcode=$((${retcode} + $?))
runkernel multi_v7_defconfig vexpress-a15 core-image-minimal-qemuarm.ext3 vexpress-v2p-ca15-tc1.dtb
retcode=$((${retcode} + $?))
runkernel qemu_arm_realview_defconfig realview-pb-a8 busybox-arm.cpio
retcode=$((${retcode} + $?))

exit ${retcode}

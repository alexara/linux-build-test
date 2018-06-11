#!/bin/bash

machine=$1
cputype=$2


dir=$(cd $(dirname $0); pwd)
. ${dir}/../scripts/config.sh
. ${dir}/../scripts/common.sh

QEMU=${QEMU:-${QEMU_BIN}/qemu-system-x86_64}
ARCH=x86_64

# Older releases don't like gcc 6+
rel=$(git describe | cut -f1 -d- | cut -f1,2 -d.)
case ${rel} in
v3.16|v3.18)
	PATH_X86=/opt/poky/1.3/sysroots/x86_64-pokysdk-linux/usr/bin/x86_64-poky-linux
	PREFIX="x86_64-poky-linux-"
	;;
*)
	PATH_X86=/opt/kernel/x86_64/gcc-6.3.0/usr/bin/
	PREFIX="x86_64-linux-"
	;;
esac

PATH=${PATH_X86}:${PATH}

cached_defconfig=""

runkernel()
{
    local defconfig=$1
    local cpu=$2
    local mach=$3
    local drive
    local pid
    local retcode
    local rootfs=rootfs.ext2
    local logfile=/tmp/runkernel-$$.log
    local waitlist=("machine restart" "Restarting" "Boot successful" "Rebooting")
    local pbuild="${ARCH}:${mach}:${cpu}:${defconfig}"

    if [ -n "${machine}" -a "${machine}" != "${mach}" ]
    then
	echo "Skipping ${pbuild} ... "
	return 0
    fi

    if [ -n "${cputype}" -a "${cputype}" != "${cpu}" ]
    then
	echo "Skipping ${pbuild} ... "
	return 0
    fi

    echo -n "Building ${pbuild} ... "

    if [ "${cached_defconfig}" != "${defconfig}" ]
    then
	dosetup ${ARCH} ${PREFIX} "" ${rootfs} ${defconfig}
	if [ $? -ne 0 ]
	then
	    return 1
	fi
	cached_defconfig=${defconfig}
    fi

    echo -n "running ..."

    case "${mach}" in
    pc)
	drive=hda
	usb="-usb -device usb-wacom-tablet"
	;;
    q35)
	drive=sda
	usb="-usb -device usb-wacom-tablet"
	;;
    *)
        echo "failed (unsupported machine type ${mach})"
	return 1
	;;
    esac

    kvm=""
    mem="-m 256"
    if [ "${cpu}" = "kvm64" ]
    then
	kvm="-enable-kvm -smp 4"
	mem="-m 1024"
    fi

    ${QEMU} -kernel arch/x86/boot/bzImage \
	-M ${mach} -cpu ${cpu} ${kvm} ${usb} -no-reboot ${mem} \
	-drive file=${rootfs},format=raw,if=ide \
	--append "root=/dev/${drive} rw console=ttyS0 console=tty doreboot" \
	-nographic > ${logfile} 2>&1 &

    pid=$!
    dowait ${pid} ${logfile} manual waitlist[@]
    retcode=$?
    rm -f ${logfile}
    return ${retcode}
}

echo "Build reference: $(git describe)"
echo

retcode=0

# runkernel qemu_x86_64_pc_defconfig kvm64 q35
# retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig Broadwell-noTSX q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig IvyBridge q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig SandyBridge q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig Haswell q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig core2duo pc
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig Nehalem q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig phenom pc
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_defconfig Opteron_G1 q35
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_nosmp_defconfig Opteron_G4 pc
retcode=$((${retcode} + $?))
runkernel qemu_x86_64_pc_nosmp_defconfig IvyBridge q35
retcode=$((${retcode} + $?))

exit ${retcode}

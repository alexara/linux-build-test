#!/bin/bash

dir=$(cd $(dirname $0); pwd)
. ${dir}/../scripts/config.sh
. ${dir}/../scripts/common.sh

QEMU=${QEMU:-${QEMU_BIN}/qemu-system-ppc64}

mach=$1
variant=$2
boottype=$3

# machine specific information
# PATH_PPC=/opt/poky/1.6/sysroots/x86_64-pokysdk-linux/usr/bin/powerpc64-poky-linux
ARCH=powerpc

rel=$(git describe | cut -f1 -d- | cut -f1,2 -d.)
case "${rel}" in
v3.16|v3.18)
	PATH_PPC=/opt/poky/1.5.1/sysroots/x86_64-pokysdk-linux/usr/bin/powerpc64-poky-linux
	PREFIX=powerpc64-poky-linux-
	;;
*)
	PATH_PPC=/opt/kernel/gcc-7.3.0-nolibc/powerpc64-linux/bin
	PREFIX=powerpc64-linux-
	;;
esac

PATH=${PATH_PPC}:${PATH}
dir=$(cd $(dirname $0); pwd)

. ${dir}/../scripts/common.sh

skip_316="powerpc:powernv_defconfig"
skip_318="powerpc:powernv_defconfig"

patch_defconfig()
{
    local defconfig=$1
    local fixup=$2

    if [ "${fixup}" = "devtmpfs_le" ]; then
	sed -i -e '/CONFIG_CPU_BIG_ENDIAN/d' ${defconfig}
	sed -i -e '/CONFIG_CPU_LITTLE_ENDIAN/d' ${defconfig}
	echo "CONFIG_CPU_LITTLE_ENDIAN=y" >> ${defconfig}
    fi

    if [ "${fixup}" = "devtmpfs" -o "${fixup}" = "devtmpfs_le" ]
    then
	sed -i -e '/CONFIG_DEVTMPFS/d' ${defconfig}
	echo "CONFIG_DEVTMPFS=y" >> ${defconfig}
	echo "CONFIG_DEVTMPFS_MOUNT=y" >> ${defconfig}
    elif [ "${fixup}" = "nosmp" ]
    then
	sed -i -e '/CONFIG_SMP/d' ${defconfig}
	echo "# CONFIG_SMP is not set" >> ${defconfig}
    elif [ "${fixup}" = "smp4" ]
    then
	sed -i -e '/CONFIG_SMP/d' ${defconfig}
	sed -i -e '/CONFIG_NR_CPUS/d' ${defconfig}
	echo "CONFIG_SMP=y" >> ${defconfig}
	echo "CONFIG_NR_CPUS=4" >> ${defconfig}
    elif [ "${fixup}" = "smp" ]
    then
	sed -i -e '/CONFIG_SMP/d' ${defconfig}
	echo "CONFIG_SMP=y" >> ${defconfig}
    fi
}

cached_config=""

runkernel()
{
    local defconfig=$1
    local fixup=$2
    local machine=$3
    local cpu=$4
    local console=$5
    local kernel=$6
    local rootfs=$7
    local reboot=$8
    local dt=$9
    local pid
    local retcode
    local logfile=/tmp/runkernel-$$.log
    local waitlist=("Restarting system" "Restarting" "Boot successful" "Rebooting")
    local buildconfig="${machine}:${defconfig}:${fixup}"
    local msg="${machine}:${defconfig}"
    local initcli
    local diskcmd
    local _boottype

    if [ -n "${fixup}" ]; then
	msg+=":${fixup}"
    fi

    if [[ "${rootfs%gz}" == *cpio ]]; then
	msg+=":initrd"
	_boottype="initrd"
    else
	msg+=":rootfs"
	_boottype="rootfs"
    fi

    if [ -n "${mach}" -a "${mach}" != "${machine}" ]
    then
	echo "Skipping ${msg} ... "
	return 0
    fi

    if [ -n "${variant}" -a "${fixup}" != "${variant}" ]
    then
	echo "Skipping ${msg} ... "
	return 0
    fi

    if [ -n "${boottype}" -a "${boottype}" != "${_boottype}" ]
    then
	echo "Skipping ${msg} ..."
	return 0
    fi

    echo -n "Building ${msg} ... "

    if [ "${cached_config}" != "${buildconfig}" ]; then
	dosetup -f "${fixup}" "${rootfs}" "${defconfig}"
	retcode=$?
	if [ ${retcode} -ne 0 ]; then
	    if [ ${retcode} -eq 2 ]; then
		return 0
	    fi
	    return 1
	fi
	cached_config="${buildconfig}"
    else
	setup_rootfs "${rootfs}"
    fi

    if [[ "${rootfs}" == *.gz ]]; then
	gunzip -f "${rootfs}"
	rootfs="${rootfs%.gz}"
    fi

    echo -n "running ..."

    dt_cmd=""
    if [ -n "${dt}" ]; then
	dt_cmd="-machine ${dt}"
    fi

    if [[ "${rootfs}" == *cpio ]]; then
	initcli="rdinit=/sbin/init"
	diskcmd="-initrd $(basename ${rootfs})"
    else
	local hddev="sda"
	local iftype="scsi"
	if [[ "${machine}" = "mac99" ]]; then
	    iftype="ide"
	    grep -q "CONFIG_IDE=y" .config >/dev/null 2>&1
	    if [[ $? -eq 0 ]]; then
		hddev="hda"
	    fi
	fi
	initcli="root=/dev/${hddev} rw"
	diskcmd="-drive file=$(basename ${rootfs}),if=${iftype},format=raw"
    fi

    mem=1G
    if [[ "${machine}" = "powernv" ]]; then
	mem=2G
    fi

    ${QEMU} -M ${machine} -cpu ${cpu} -m ${mem} \
	-kernel ${kernel} \
	${diskcmd} \
	-nographic -vga none -monitor null -no-reboot \
	--append "${initcli} console=tty console=${console} doreboot" \
	${dt_cmd} > ${logfile} 2>&1 &

    pid=$!

    dowait ${pid} ${logfile} ${reboot} waitlist[@]
    retcode=$?
    rm -f ${logfile}
    return ${retcode}
}

echo "Build reference: $(git describe)"
echo

runkernel qemu_ppc64_book3s_defconfig nosmp mac99 ppc64 ttyS0 vmlinux \
	rootfs.cpio.gz manual
retcode=$?
runkernel qemu_ppc64_book3s_defconfig smp4 mac99 ppc64 ttyS0 vmlinux \
	rootfs.cpio.gz manual
retcode=$((${retcode} + $?))
runkernel qemu_ppc64_book3s_defconfig smp4 mac99 ppc64 ttyS0 vmlinux \
	rootfs.ext2.gz manual
retcode=$((${retcode} + $?))
runkernel pseries_defconfig devtmpfs pseries POWER8 hvc0 vmlinux \
	rootfs.cpio.gz auto
retcode=$((${retcode} + $?))
runkernel pseries_defconfig devtmpfs pseries POWER9 hvc0 vmlinux \
	rootfs.ext2.gz auto
retcode=$((${retcode} + $?))
runkernel pseries_defconfig devtmpfs_le pseries POWER9 hvc0 vmlinux \
	rootfs-el.cpio.gz auto
retcode=$((${retcode} + $?))
runkernel pseries_defconfig devtmpfs_le pseries POWER8 hvc0 vmlinux \
	rootfs-el.ext2.gz auto
retcode=$((${retcode} + $?))
runkernel qemu_ppc64_e5500_defconfig nosmp mpc8544ds e5500 ttyS0 \
	arch/powerpc/boot/uImage \
	../ppc/busybox-ppc.cpio auto "dt_compatible=fsl,,P5020DS"
retcode=$((${retcode} + $?))
runkernel qemu_ppc64_e5500_defconfig smp mpc8544ds e5500 ttyS0 \
	arch/powerpc/boot/uImage \
	../ppc/busybox-ppc.cpio auto "dt_compatible=fsl,,P5020DS"
retcode=$((${retcode} + $?))
runkernel powernv_defconfig devtmpfs powernv POWER8 hvc0 \
	arch/powerpc/boot/zImage.epapr rootfs-el.cpio.gz manual
retcode=$((${retcode} + $?))

exit ${retcode}

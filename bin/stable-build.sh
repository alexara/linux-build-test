#!/bin/bash

basedir=$(cd $(dirname $0); pwd)
. ${basedir}/stable-build-targets.sh

LOG=/tmp/log.$$
MAIL_FILE=/tmp/mail.$$

PATH_ALPHA=/opt/kernel/gcc-4.6.3-nolibc/alpha-linux/bin
PATH_ARM=/opt/poky/1.3/sysroots/x86_64-pokysdk-linux/usr/bin/armv5te-poky-linux-gnueabi
PATH_BFIN=/opt/kernel/gcc-4.6.3-nolibc/bfin-uclinux/bin
PATH_CRIS=/opt/kernel/gcc-4.6.3-nolibc/cris-linux/bin
PATH_FRV=/opt/kernel/gcc-4.6.3-nolibc/frv-linux/bin
PATH_IA64=/opt/kernel/gcc-4.6.3-nolibc/ia64-linux/bin
PATH_M68=/opt/kernel/gcc-4.9.0-nolibc/m68k-linux/bin
PATH_M68_NOMMU=/usr/local/bin
PATH_MICROBLAZE=/opt/kernel/gcc-4.8.0-nolibc/microblaze-linux/bin
PATH_MIPS=/opt/poky/1.3/sysroots/x86_64-pokysdk-linux/usr/bin/mips32-poky-linux
PATH_PARISC=/opt/kernel/gcc-4.6.3-nolibc/hppa-linux/bin
PATH_PARISC64=/opt/kernel/gcc-4.6.3-nolibc/hppa64-linux/bin
PATH_PPC=/opt/poky/1.6/sysroots/x86_64-pokysdk-linux/usr/bin/powerpc64-poky-linux
PATH_S390=/opt/kernel/gcc-4.6.3-nolibc/s390x-linux/bin
PATH_SH4=/opt/kernel/gcc-4.6.3-nolibc/sh4-linux/bin
PATH_SPARC=/opt/kernel/gcc-4.6.3-nolibc/sparc64-linux/bin
PATH_TILE=/opt/kernel/gcc-4.6.2-nolibc/tilegx-linux/bin
PATH_UC32=/opt/kernel/unicore32/uc4-1.0.5-hard/bin
PATH_X86=/opt/poky/1.3/sysroots/x86_64-pokysdk-linux/usr/bin/x86_64-poky-linux
# PATH_XTENSA=/opt/kernel/gcc-4.6.3-nolibc/xtensa-linux/bin
PATH_XTENSA=/opt/kernel/xtensa/gcc-4.7.3/usr/bin

rel=$(git describe | cut -f1 -d- | cut -f1,2 -d.)

errors=0
builds=0

send_mail()
{
	echo "From Guenter Roeck <linux@roeck-us.net>" > ${MAIL_FILE}
	echo "Subject: $1" >> ${MAIL_FILE}
	echo "MIME-Version: 1.0" >> ${MAIL_FILE}
	echo "Content-Transfer-Encoding: 8bit" >> ${MAIL_FILE}
	echo "Content-Type: text/plain; charset=utf-8" >> ${MAIL_FILE}
	echo >> ${MAIL_FILE}
	cat $2 >> ${MAIL_FILE}
	git send-email --quiet --to=linux@roeck-us.net \
		    --suppress-cc=all --confirm=never --no-chain-reply-to \
		    ${MAIL_FILE} >/dev/null 2>/dev/null
	rm -f ${MAIL_FILE}
}

doit()
{
    ARCH=$1

    # clean up source directory
    git clean -x -f -d -q

    case ${ARCH} in
    alpha)
	cmd=(${cmd_alpha[*]})
	PREFIX="alpha-linux-"
	PATH=${PATH_ALPHA}:${PATH}
	;;
    arm)
	cmd=(${cmd_arm[*]})
	PREFIX="arm-poky-linux-gnueabi-"
	PATH=${PATH_ARM}:${PATH}
	;;
    blackfin)
	cmd=(${cmd_blackfin[*]})
	PREFIX="bfin-uclinux-"
	PATH=${PATH_BFIN}:${PATH}
	;;
    cris)
	cmd=(${cmd_cris[*]})
	PREFIX="cris-linux-"
	PATH=${PATH_CRIS}:${PATH}
	;;
    frv)
	cmd=(${cmd_frv[*]})
	PREFIX="frv-linux-"
	PATH=${PATH_FRV}:${PATH}
	;;
    i386)
	cmd=(${cmd_i386[*]})
	PREFIX="x86_64-poky-linux-"
	PATH=${PATH_X86}:${PATH}
	;;
    ia64)
	cmd=(${cmd_ia64[*]})
	PREFIX="ia64-linux-"
	PATH=${PATH_IA64}:${PATH}
	;;
    m68k)
    	cmd=(${cmd_m68k[*]})
	PREFIX="m68k-linux-"
	PATH=${PATH_M68}:${PATH}
	;;
    m68k_nommu)
	PREFIX="m68k-linux-"
	PATH=${PATH_M68}:${PATH}
	ARCH=m68k
        ;;
    microblaze)
	cmd=(${cmd_microblaze[*]})
	PREFIX="microblaze-linux-"
	PATH=${PATH_MICROBLAZE}:${PATH}
	;;
    mips)
	cmd=(${cmd_mips[*]});
	PREFIX="mips-poky-linux-"
	PATH=${PATH_MIPS}:${PATH}
	;;
    parisc)
	cmd=(${cmd_parisc[*]})
	PREFIX="hppa-linux-"
	PATH=${PATH_PARISC}:${PATH}
	;;
    parisc64)
	cmd=(${cmd_parisc64[*]})
	PREFIX="hppa64-linux-"
	PATH=${PATH_PARISC64}:${PATH}
	ARCH=parisc
	;;
    powerpc)
	cmd=(${cmd_powerpc[*]})
	PREFIX="powerpc64-poky-linux-"
	PATH=${PATH_PPC}:${PATH}
	;;
    sparc32)
	cmd=(${cmd_sparc32[*]})
	PREFIX="sparc64-linux-"
	PATH=${PATH_SPARC}:${PATH}
	;;
    sparc64)
	cmd=(${cmd_sparc64[*]})
	PREFIX="sparc64-linux-"
	PATH=${PATH_SPARC}:${PATH}
	;;
    s390)
	cmd=(${cmd_s390[*]})
	PREFIX="s390x-linux-"
	PATH=${PATH_S390}:${PATH}
	;;
    tile)
	cmd=(${cmd_tile[*]})
	PREFIX="tilegx-linux-"
	PATH=${PATH_TILE}:${PATH}
	;;
    sh)
	cmd=(${cmd_sh[*]})
	PREFIX="sh4-linux-"
	PATH=${PATH_SH4}:${PATH}
	;;
    unicore32)
	cmd=(${cmd_unicore32[*]})
	PREFIX="unicore32-linux-"
	PATH=${PATH_UC32}:${PATH}
	;;
    x86_64)
	cmd=(${cmd_x86_64[*]})
	PREFIX="x86_64-poky-linux-"
	PATH=${PATH_X86}:${PATH}
	;;
    xtensa)
	cmd=(${cmd_xtensa[*]})
	PREFIX="xtensa-linux-"
	PATH=${PATH_XTENSA}:${PATH}
	;;
    esac

    CROSS=""
    if [ "${PREFIX}" != "" ]; then
	CROSS="CROSS_COMPILE=${PREFIX}"
    fi

    maxcmd=$(expr ${#cmd[*]} - 1)
    for i in $(seq 0 ${maxcmd})
    do
    	echo -n "Building ${ARCH}:${cmd[$i]} ... "
	rm -f .config
	make ${CROSS} ARCH=${ARCH} ${cmd[$i]} >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
	        echo "failed (config) - skipping"
	 	i=$(expr $i + 1)
	 	continue
	fi
	make ${CROSS} ARCH=${ARCH} oldnoconfig >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
	        echo "failed (oldnoconfig) - skipping"
	 	i=$(expr $i + 1)
	 	continue
	fi
    	builds=$(expr ${builds} + 1)
	# can't have slashes in file names
	l=$(echo ${cmd[$i]} | sed -e 's/\//_/g')
	make ${CROSS} -j12 ARCH=${ARCH} >/dev/null 2>/tmp/buildlog.${ref}.${ARCH}.${l}
	if [ $? -ne 0 ]; then
	    echo "Build ${ARCH}:${cmd[$i]} failed" >> ${LOG}
	    echo "failed"
	    echo "--------------"
	    echo "Error log:"
	    cat /tmp/buildlog.${ref}.${ARCH}.${l}
	    echo "--------------"
    	    errors=$(expr ${errors} + 1)
	else
	    echo "Build ${ARCH}:${cmd[$i]} passed" >> ${LOG}
	    echo "passed"
	fi
	# rm -f error.log
    done
    return 0
}

ref=$(git describe)
echo
echo "Build reference: ${ref}"
echo
echo "Build reference: ${ref}" > ${LOG}
echo >> ${LOG}

maxbuild=$(expr ${#buildarch[*]} - 1)
for build in $(seq 0 ${maxbuild})
do
	doit ${buildarch[${build}]}
done

git clean -d -f -x -q

echo
echo "-----------------------"
echo "Total builds: ${builds} Total build errors: ${errors}"

echo >> ${LOG}
echo "-----------------------" >> ${LOG}
echo "Total builds: ${builds} Total build errors: ${errors}" >> ${LOG}

send_mail "stable build status for ${ref} [${builds}:${errors}]" ${LOG}

rm -f ${LOG}

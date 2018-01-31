# scripts/mkcmd.sh
#
# (c) Copyright 2013
# Allwinner Technology Co., Ltd. <www.allwinnertech.com>
# James Deng <csjamesdeng@allwinnertech.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# Notice:
#   1. This script muse source at the top directory of lichee.
BUILD_CONFIG=.buildconfig
cpu_cores=`cat /proc/cpuinfo | grep "processor" | wc -l`
if [ ${cpu_cores} -le 8 ] ; then
	LICHEE_JLEVEL=${cpu_cores}
else
	LICHEE_JLEVEL=`expr ${cpu_cores} / 2`
fi

export LICHEE_JLEVEL

function mk_error()
{
	echo -e "\033[47;31mERROR: $*\033[0m"
}

function mk_warn()
{
	echo -e "\033[47;34mWARN: $*\033[0m"
}

function mk_info()
{
	echo -e "\033[47;30mINFO: $*\033[0m"
}

# define importance variable
LICHEE_TOP_DIR=`pwd`
LICHEE_BR_DIR=${LICHEE_TOP_DIR}/buildroot
LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
LICHEE_ARCH_DIR=${LICHEE_KERN_DIR}/${LICHEE_ARCH}
LICHEE_TOOLS_DIR=${LICHEE_TOP_DIR}/tools
LICHEE_SATA_DIR=${LICHEE_TOP_DIR}/SATA
LICHEE_OUT_DIR=${LICHEE_TOP_DIR}/out
MKRULE_FILE=${LICHEE_TOOLS_DIR}/build/mkrule
MKBUSINESS_FILE=${LICHEE_TOOLS_DIR}/build/mkbusiness

if [ "x$(echo $PATH | grep ${LICHEE_TOOLS_DIR}/build/bin)x" == "xx" ]; then
        export PATH=$PATH:${LICHEE_TOOLS_DIR}/build/bin
fi


# make surce at the top directory of lichee
if [ ! -d ${LICHEE_KERN_DIR} -o \
	! -d ${LICHEE_TOOLS_DIR} ] ; then
	mk_error "You are not at the top directory of lichee."
	mk_error "Please changes to that directory."
	exit 1
fi

# export importance variable
export LICHEE_TOP_DIR
export LICHEE_BR_DIR
export LICHEE_KERN_DIR
export LICHEE_ARCH_DIR
export LICHEE_TOOLS_DIR
export LICHEE_OUT_DIR

platforms=(
"android"
"dragonboard"
"linux"
"camdroid"
)

#
# This function can get the realpath between $SRC and $DST
#
function get_realpath()
{
	local src=$(cd $1; pwd);
	local dst=$(cd $2; pwd);
	local res="./";
	local tmp="$dst"

	while [ "${src##*$tmp}" == "${src}" ]; do
		tmp=${tmp%/*};
		res=$res"../"
	done
	res="$res${src#*$tmp/}"

	printf "%s" $res
}

function check_env()
{
	if [ "x${LICHEE_PLATFORM}" = "xandroid" ] ; then
		if [ -z "${LICHEE_CHIP}" -o \
			-z "${LICHEE_PLATFORM}" -o \
			-z "${LICHEE_KERN_VER}" ] ; then
			mk_error "run './build.sh config' setup env"
			exit 1
		fi
	else
		if [ -z "${LICHEE_CHIP}" -o \
			-z "${LICHEE_PLATFORM}" -o \
			-z "${LICHEE_KERN_VER}" -o \
			-z "${LICHEE_ARCH}" -o \
			-z "${LICHEE_BOARD}" ] ; then
			mk_error "run './build.sh config' setup env"
			exit 1
		fi
	fi

	cd ${LICHEE_TOOLS_DIR}
	ln -sfT $(get_realpath pack/chips/ ./)/${LICHEE_CHIP} product
	cd - > /dev/null
}

function init_defconf()
{
	local pattern
	local defconf
	local out_dir="common"

	check_env

	pattern="${LICHEE_CHIP}_${LICHEE_PLATFORM}_${LICHEE_BOARD}"
	defconf=`awk '$1=="'$pattern'" {print $2,$3}' ${MKRULE_FILE}`
	if [ -n "${defconf}" ] ; then
		out_dir="${LICHEE_BOARD}"
	else
		pattern="${LICHEE_CHIP}_${LICHEE_PLATFORM}_${LICHEE_BUSINESS}"
		defconf=`awk '$1=="'$pattern'" {print $2,$3}' ${MKRULE_FILE}`
		if [ -z "${defconf}" ] ; then
			pattern="${LICHEE_CHIP}_${LICHEE_PLATFORM}_${LICHEE_ARCH}"
			defconf=`awk '$1=="'$pattern'" {print $2,$3}' ${MKRULE_FILE}`
			if [ -z "${defconf}" ] ; then
				pattern="${LICHEE_CHIP}_${LICHEE_PLATFORM}"
				defconf=`awk '$1=="'$pattern'" {print $2,$3}' ${MKRULE_FILE}`
			fi
		fi
	fi

	if [ -n "${defconf}" ] ; then
		export LICHEE_BR_DEFCONF=`echo ${defconf} | awk '{print $1}'`
		export LICHEE_KERN_DEFCONF=`echo ${defconf} | awk '{print $2}'`
	fi

	export LICHEE_PLAT_OUT="${LICHEE_OUT_DIR}/${LICHEE_CHIP}/${LICHEE_PLATFORM}/${out_dir}"
	export LICHEE_BR_OUT="${LICHEE_PLAT_OUT}/buildroot"
	mkdir -p ${LICHEE_BR_OUT}

	set_build_info
}

function set_build_info()
{
	if [ -d ${LICHEE_PLAT_OUT} ] ; then
		if [ -f ${LICHEE_PLAT_OUT}/.buildconfig ] ; then
			rm -f ${LICHEE_PLAT_OUT}/.buildconfig
		fi
		echo "export LICHEE_CHIP='${LICHEE_CHIP}'" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
		echo "export LICHEE_PLATFORM='${LICHEE_PLATFORM}'" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
		echo "export LICHEE_BUSINESS='${LICHEE_BUSINESS}'" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
		echo "export LICHEE_ARCH=${LICHEE_ARCH}" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
		echo "export LICHEE_KERN_VER='${LICHEE_KERN_VER}'" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
		echo "export LICHEE_BOARD='${LICHEE_BOARD}'" >> ${LICHEE_OUT_DIR}/${LICHEE_CHIP}/.buildconfig
	fi

	if [ -f ${BUILD_CONFIG} ] ; then
		rm ${BUILD_CONFIG}
	fi
	echo "export LICHEE_CHIP=${LICHEE_CHIP}" >> ${BUILD_CONFIG}
	echo "export LICHEE_PLATFORM=${LICHEE_PLATFORM}" >> ${BUILD_CONFIG}
	echo "export LICHEE_BUSINESS=${LICHEE_BUSINESS}" >> ${BUILD_CONFIG}
	echo "export LICHEE_ARCH=${LICHEE_ARCH}" >> ${BUILD_CONFIG}
	echo "export LICHEE_KERN_VER=${LICHEE_KERN_VER}" >> ${BUILD_CONFIG}
	echo "export LICHEE_BOARD=${LICHEE_BOARD}" >> ${BUILD_CONFIG}
}

function init_chips()
{
	local chip=$1
	local cnt=0
	local ret=1

	for chipdir in ${LICHEE_TOOLS_DIR}/pack/chips/* ; do
		chips[$cnt]=`basename $chipdir`
		if [ "x${chips[$cnt]}" = "x${chip}" ] ; then
			ret=0
			export LICHEE_CHIP=${chip}
		fi
		((cnt+=1))
	done

	return ${ret}
}

function init_platforms()
{
	local cnt=0
	local ret=1
	local platform=""

	for platform in ${platforms[@]} ; do
		if [ "x${platform}" = "x$1" ] ; then
			ret=0
			export LICHEE_PLATFORM=${platform}
		fi
		((cnt+=1))
	done

	return ${ret}
}

function init_kern_ver()
{
	local kern_ver=$1
	local cnt=0
	local ret=1

	if [ "x${LICHEE_CHIP}" = "xsun6i" -o "x${LICHEE_CHIP}" = "xsun8iw1p1" ] ; then
		if [ "x${kern_ver}" != "xlinux-3.3" ] ; then
			mk_error "${LICHEE_CHIP} must ust using linux-3.3!\n"
			return ${ret};
		fi
	elif [ "x${LICHEE_CHIP}" = "xsun8iw6p1" \
			-o "x${LICHEE_CHIP}" = "xsun8iw8p1" -o "x${LICHEE_CHIP}" = "xsun9iw1p1" ] ; then
		if [ "x${kern_ver}" != "xlinux-3.4" ] ; then
			mk_error "${LICHEE_CHIP} must using linux-3.4!\n"
			return ${ret};
		fi
	elif [ "x${LICHEE_CHIP}" = "xsun8iw12p1" ] ; then
		if [ "x${kern_ver}" != "xlinux-4.4" ] ; then
			mk_error "${LICHEE_CHIP} must using linux-4.4!\n"
			return ${ret};
		fi
	elif [ "x${LICHEE_CHIP}" = "xsun8iw7p1" ] ; then
		if [ "x${kern_ver}" != "xlinux-4.4" ] ; then
			if [ "x${kern_ver}" != "xlinux-3.4" ] ; then
				mk_error "${LICHEE_CHIP} must using linux-4.4 of linux-3.4!\n"
				return ${ret};
			fi
		fi
	else
		if [ "x${kern_ver}" != "xlinux-3.10" ] ; then
			mk_error "${LICHEE_CHIP} must using linux-3.10!\n"
			return ${ret};
		fi
	fi

	for kern_dir in ${LICHEE_TOP_DIR}/linux-* ; do
		kern_vers[$cnt]=`basename $kern_dir`
		if [ "x${kern_vers[$cnt]}" = "x${kern_ver}" ] ; then
			ret=0
			export LICHEE_KERN_VER=${kern_ver}
			export LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
		fi
		((cnt+=1))
	done

	return ${ret}
}

function init_business()
{
	local chip=$1
	local business=$2
	local ret=1

	pattern=${chip}
	defconf=`awk '$1=="'$pattern'" {for(i=2;i<=NF;i++) print($i)}'	${MKBUSINESS_FILE}`
	if [ -n "${defconf}" ] ; then
		printf "All available business:\n"
		for subbusness in $defconf ; do
			if [ "x${business}" = "x${subbusness}" ] ; then
				ret=0
				export LICHEE_BUSINESS=${subbusness}
			fi
		done
	else
		export LICHEE_BUSINESS=""
		ret=0
		printf "not set business, to use default!\n"
	fi

	return ${ret}
}

function init_arch()
{
	local arch=$1
	local cnt=0
	local ret=1

	if [ "x${arch}" = "x" ] ; then
		echo "not set arch, to use default by kernel version"
		if [ -n "`echo ${LICHEE_CHIP} || grep "sun5[0-9]i"`" ] && \
			[ "x${LICHEE_KERN_VER}" = "xlinux-3.10" ]; then
			export LICHEE_ARCH=arm64
		else
			export LICHEE_ARCH=arm
		fi

		ret=0;
		return ${ret}
	fi

	for arch_dir in ${LICHEE_KERN_DIR}/arch/ar* ; do
		archs[$cnt]=`basename $arch_dir`
		if [ "x${archs[$cnt]}" = "x${arch}" ] ; then
			ret=0
			export LICHEE_ARCH=${arch}
		fi
		((cnt+=1))
	done

	return ${ret}
}

function init_boards()
{
	local chip=$1
	local board=$2
	local cnt=0
	local ret=1

	if [ "x${LICHEE_PLATFORM}" == "xandroid" ] ; then
		export LICHEE_BOARD=""
		ret=0;
		return ${ret}
	fi

	for boarddir in ${LICHEE_TOOLS_DIR}/pack/chips/${chip}/configs/* ; do
		boards[$cnt]=`basename $boarddir`
		if [ "x${boards[$cnt]}" = "x${board}" ] ; then
			ret=0
			export LICHEE_BOARD=${board}
		fi
		((cnt+=1))
	done

	return ${ret}
}


function select_lunch()
{
	local chip_cnt=0
	local board_cnt=0
	local plat_cnt=0
	local platform=""

	declare -a mulboards
	declare -a mulchips
	declare -a mulplatforms

	printf "All available lichee lunch:\n"
	for chipdir in ${LICHEE_TOOLS_DIR}/pack/chips/* ; do
		chips[$chip_cnt]=`basename $chipdir`
		#printf "%4d. %s\n" ${chip_cnt} ${chips[$chip_cnt]}
		for platform in ${platforms[@]} ; do
			if [ "x${platform}" = "xandroid" ] ; then
				pattern=${chips[$chip_cnt]}
				defconf=`awk '$1=="'$pattern'" {for(i=2;i<=NF;i++) print($i)}' $MKBUSINESS_FILE`
				if [ -n "${defconf}" ] ; then
					for subbusness in $defconf ; do
						mulchips[$board_cnt]=${chips[$chip_cnt]}
						mulplatforms[$board_cnt]=${platform}
						mulbusiness[$board_cnt]=${subbusness}
						mulboards[$board_cnt]=""
						printf "%4d. %s-%s-%s\n" $board_cnt ${chips[$chip_cnt]} ${platform} ${subbusness}
						((board_cnt+=1))
					done
				else
					mulchips[$board_cnt]=${chips[$chip_cnt]}
					mulplatforms[$board_cnt]=${platform}
					mulbusiness[$board_cnt]=""
					mulboards[$board_cnt]=""
					printf "%4d. %s-%s\n" $board_cnt ${chips[$chip_cnt]} ${platform}
					((board_cnt+=1))
				fi
			fi
			((plat_cnt+=1))
		done
		((chip_cnt+=1))
	done

	while true ; do
        read -p "Choice: " choice
        if [ -z "${choice}" ] ; then
            continue
        fi

        if [ -z "${choice//[0-9]/}" ] ; then
            if [ $choice -ge 0 -a $choice -lt $board_cnt ] ; then
		#printf "%4d  %s %s %s\n" $choice  ${mulchips[$choice]} ${mulplatforms[$choice]} ${mulboards[$choice]}
		if [ -f .buildconfig ] ; then
			rm -f .buildconfig
		fi

		#export PLATFORM=${mulchips[$choice]}
		export LICHEE_CHIP="${mulchips[$choice]}"
		echo "export LICHEE_CHIP=${mulchips[$choice]}" >> ${BUILD_CONFIG}

		export LICHEE_PLATFORM="${mulplatforms[$choice]}"
		echo "export LICHEE_PLATFORM=${mulplatforms[$choice]}" >> ${BUILD_CONFIG}

		export LICHEE_BUSINESS="${mulbusiness[$choice]}"
		echo "export LICHEE_BUSINESS=${mulbusiness[$choice]}" >> ${BUILD_CONFIG}

		export LICHEE_BOARD="${mulboards[$choice]}"
		echo "export LICHEE_BOARD=${mulboards[$choice]}" >> ${BUILD_CONFIG}

		if [ "x${LICHEE_CHIP}" = "xsun8iw1p1" -o "x${LICHEE_CHIP}" = "xsun6i" ] ; then
			LICHEE_KERN_VER="linux-3.3"
		elif [ "x${LICHEE_CHIP}" = "xsun8iw6p1" -o "x${LICHEE_CHIP}" = "xsun8iw8p1" -o "x${LICHEE_CHIP}" = "xsun9iw1p1" ] ; then
			LICHEE_KERN_VER="linux-3.4"
		elif [ "x${LICHEE_CHIP}" = "xsun8iw12p1" ] ; then
			LICHEE_KERN_VER="linux-4.4"
		elif [ "x${LICHEE_CHIP}" = "xsun8iw7p1" ] ; then
			select_kern_only
		else
			LICHEE_KERN_VER="linux-3.10"
		fi

		printf "using kernel '${LICHEE_KERN_VER}':\n"
		export LICHEE_KERN_VER
		export LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
		echo "export LICHEE_KERN_VER=${LICHEE_KERN_VER}" >> ${BUILD_CONFIG}

		if [ -n "`echo ${LICHEE_CHIP} | grep "sun5[0-9]i"`" ] && \
			[ "x${LICHEE_KERN_VER}" = "xlinux-3.10" ]; then
			LICHEE_ARCH="arm64"
		else
			LICHEE_ARCH="arm"
		fi
		printf "using arch '${LICHEE_ARCH}':\n"
		export LICHEE_ARCH
		echo "export LICHEE_ARCH=${LICHEE_ARCH}" >> ${BUILD_CONFIG}

		echo "LICHEE_CHIP="${LICHEE_CHIP}
		echo "LICHEE_PLATFORM="${LICHEE_PLATFORM}
		echo "LICHEE_BUSINESS="${LICHEE_BUSINESS}
		echo "LICHEE_BOARD="${LICHEE_BOARD}
		echo "LICHEE_ARCH="${LICHEE_ARCH}
		echo "LICHEE_KERN_VER="${LICHEE_KERN_VER}
		break
            fi
        fi
        printf "Invalid input ...\n"
    done
}

function select_business()
{
	local cnt=0
	local pattern
	local defconf

	select_platform

	pattern=${LICHEE_CHIP}
	defconf=`awk '$1=="'$pattern'" {for(i=2;i<=NF;i++) print($i)}' ${MKBUSINESS_FILE}`
	if [ -n "${defconf}" ] ; then
		printf "All available business:\n"
		for subbusness in $defconf ; do
			business[$cnt]=$subbusness
			printf "%4d. %s\n" $cnt ${business[$cnt]}
			((cnt+=1))
		done

		while true ; do
			read -p "Choice: " choice
			if [ -z "${choice}" ] ; then
				continue
			fi

			if [ -z "${choice//[0-9]/}" ] ; then
				if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
					export LICHEE_BUSINESS="${business[$choice]}"
					echo "export LICHEE_BUSINESS=${business[$choice]}" >> ${BUILD_CONFIG}
					break;
				fi
			fi
			 printf "Invalid input ...\n"
		done
	else
		export LICHEE_BUSINESS=""
		echo "export LICHEE_BUSINESS=${LICHEE_BUSINESS}" >> ${BUILD_CONFIG}
		printf "not set business, to use default!\n"
	fi

	echo "LICHEE_BUSINESS="$LICHEE_BUSINESS
}

function select_chip()
{
	local cnt=0
	local choice
	local call=$1

	printf "All available chips:\n"
	for chipdir in ${LICHEE_TOOLS_DIR}/pack/chips/* ; do
		chips[$cnt]=`basename $chipdir`
		printf "%4d. %s\n" $cnt ${chips[$cnt]}
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				export LICHEE_CHIP="${chips[$choice]}"
				echo "export LICHEE_CHIP=${chips[$choice]}" >> ${BUILD_CONFIG}
				break
			fi
		fi
		printf "Invalid input ...\n"
	done
}

function select_platform()
{
	local cnt=0
	local choice
	local call=$1
	local platform=""

	select_chip

	printf "All available platforms:\n"
	for platform in ${platforms[@]} ; do
		printf "%4d. %s\n" $cnt $platform
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				export LICHEE_PLATFORM="${platforms[$choice]}"
				echo "export LICHEE_PLATFORM=${platforms[$choice]}" >> ${BUILD_CONFIG}
				break
			fi
		fi
		printf "Invalid input ...\n"
	done
}

function select_kern_only()
{
	local cnt=0
	local choice

	printf "All available kernel:\n"
	for kern_dir in ${LICHEE_TOP_DIR}/linux-* ; do
		kern_vers[$cnt]=`basename $kern_dir`
		printf "%4d. %s\n" $cnt ${kern_vers[$cnt]}
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				LICHEE_KERN_VER="${kern_vers[$choice]}"
				export LICHEE_KERN_VER="${kern_vers[$choice]}"
				export LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
				echo "export LICHEE_KERN_VER=${kern_vers[$choice]}" >> ${BUILD_CONFIG}
				break
			fi
		fi
		printf "Invalid input ...\n"
	done
}

function select_kern_ver()
{
	local cnt=0
	local choice

	select_business

	if [ "x${LICHEE_CHIP}" = "xsun8iw1p1" \
		-o "x${LICHEE_CHIP}" = "xsun6i" ] ; then
		LICHEE_KERN_VER="linux-3.3"
	elif [ "x${LICHEE_CHIP}" = "xsun8iw6p1" \
		-o "x${LICHEE_CHIP}" = "xsun8iw8p1" \
		-o "x${LICHEE_CHIP}" = "xsun9iw1p1" ] ; then
		LICHEE_KERN_VER="linux-3.4"
	elif [ "x${LICHEE_CHIP}" = "xsun8iw12p1" ] ; then
		LICHEE_KERN_VER="linux-4.4"
	else
		LICHEE_KERN_VER="linux-3.10"
	fi

	printf "using kernel '${LICHEE_KERN_VER}':\n"
	export LICHEE_KERN_VER
	export LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
	echo "export LICHEE_KERN_VER=${LICHEE_KERN_VER}" >> ${BUILD_CONFIG}

	if [ "x${LICHEE_CHIP}" = "xsun8iw7p1" ] ; then
		printf "All available kernel:\n"
		for kern_dir in ${LICHEE_TOP_DIR}/linux-* ; do
			kern_vers[$cnt]=`basename $kern_dir`
			printf "%4d. %s\n" $cnt ${kern_vers[$cnt]}
			((cnt+=1))
		done

		while true ; do
			read -p "Choice: " choice
			if [ -z "${choice}" ] ; then
				continue
			fi

			if [ -z "${choice//[0-9]/}" ] ; then
				if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
					LICHEE_KERN_VER="${kern_vers[$choice]}"
					export LICHEE_KERN_VER="${kern_vers[$choice]}"
					export LICHEE_KERN_DIR=${LICHEE_TOP_DIR}/${LICHEE_KERN_VER}
					echo "export LICHEE_KERN_VER=${kern_vers[$choice]}" >> ${BUILD_CONFIG}
					break
				fi
			fi
			printf "Invalid input ...\n"
		done
	fi
}

function select_arch()
{
	local cnt=0
	local choice

	select_kern_ver

	if [ x${CONFIG_ALL} == x${FLAGS_TRUE} ]; then
		printf "All available arch:\n"
		for arch_dir in ${LICHEE_KERN_DIR}/arch/arm* ; do
			archs[$cnt]=`basename $arch_dir`
			printf "%4d. %s\n" $cnt ${archs[$cnt]}
			((cnt+=1))
		done

		while true ; do
			read -p "Choice: " choice
			if [ -z "${choice}" ] ; then
				continue
			fi

			if [ -z "${choice//[0-9]/}" ] ; then
				if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
					export LICHEE_ARCH="${archs[$choice]}"
					echo "export LICHEE_ARCH=${archs[$choice]}" >> ${BUILD_CONFIG}
					break
				fi
			fi
			printf "Invalid input ...\n"
		done
	else
		if [ -n "`echo ${LICHEE_CHIP} | grep "sun5[0-9]i"`" ]; then
			export LICHEE_ARCH="arm64"
			echo "export LICHEE_ARCH=arm64" >> ${BUILD_CONFIG}
		else
			export LICHEE_ARCH="arm"
			echo "export LICHEE_ARCH=arm" >> ${BUILD_CONFIG}
		fi
	fi
}

function select_board()
{
	local cnt=0
	local choice

	select_arch

	if [ "x${LICHEE_PLATFORM}" = "xandroid" ] ; then
		export LICHEE_BOARD=""
		echo "export LICHEE_BOARD=" >> ${BUILD_CONFIG}
		return 0
	fi

	printf "All available boards:\n"
	for boarddir in ${LICHEE_TOOLS_DIR}/pack/chips/${LICHEE_CHIP}/configs/* ; do
		boards[$cnt]=`basename $boarddir`
		if [ "x${boards[$cnt]}" = "xdefault" ] ; then
			continue
		fi
		printf "%4d. %s\n" $cnt ${boards[$cnt]}
		((cnt+=1))
	done

	while true ; do
		read -p "Choice: " choice
		if [ -z "${choice}" ] ; then
			continue
		fi

		if [ -z "${choice//[0-9]/}" ] ; then
			if [ $choice -ge 0 -a $choice -lt $cnt ] ; then
				export LICHEE_BOARD="${boards[$choice]}"
				echo "export LICHEE_BOARD=${boards[$choice]}" >> ${BUILD_CONFIG}
				break
			fi
		fi
		printf "Invalid input ...\n"
	done
}

function mkbr()
{
	mk_info "build buildroot ..."

	local build_script="scripts/build.sh"

	prepare_toolchain

	(cd ${LICHEE_BR_DIR} && [ -x ${build_script} ] && ./${build_script})
	[ $? -ne 0 ] && mk_error "build buildroot Failed" && return 1

	mk_info "build buildroot OK."
}

function clbr()
{
	mk_info "build buildroot ..."

	local build_script="scripts/build.sh"
	(cd ${LICHEE_BR_DIR} && [ -x ${build_script} ] && ./${build_script} "clean")

	mk_info "clean buildroot OK."
}

function prepare_toolchain()
{
	local ARCH="";
	local GCC="";
	local GCC_PREFIX="";
	local toolchain_archive="";
	local tooldir="";
	local toolchain_32_archive="";
	local tooldir_32="";

	cat ${BUILD_CONFIG}
	mk_info "Prepare toolchain ..."

	if [ $(getconf LONG_BIT) = "64" ]; then
		if [ "x${LICHEE_ARCH}" = "xarm64" ]; then
			ARCH="aarch64"
			if [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.4"`" ]; then
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/x86_64/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz";
			else
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/x86_64/gcc-linaro-aarch64.tar.xz";
			fi

			if [ "x${LICHEE_PLATFORM}" = "xdragonboard" ] ; then
				toolchain_32_archive="${LICHEE_TOOLS_DIR}/build/toolchain/gcc-linaro-arm.tar.xz"
			fi
		elif [ "x${LICHEE_ARCH}" = "xarm" ]; then
			ARCH="arm"
			if [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.4"`" ] || [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.9"`" ]; then
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/x86_64/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabi.tar.xz";
			else
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/x86_64/gcc-linaro-arm.tar.xz";
			fi
		else
			echo "LICHEE_ARCH=${LICHEE_ARCH} is unkown"
			exit 1
		fi
    else
		if [ "x${LICHEE_ARCH}" = "xarm64" ]; then
			ARCH="aarch64"
			if [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.4"`" ]; then
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/i686/gcc-linaro-5.3.1-2016.05-i686_aarch64-linux-gnu.tar.xz";
			else
				mk_error "toolchain not support in 32bit system...."
			fi
		elif [ "x${LICHEE_ARCH}" = "xarm" ]; then
			ARCH="arm"
			if [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.4"`" ] || [ -n "`echo $LICHEE_KERN_VER | grep "linux-4.9"`" ]; then
				toolchain_archive="${LICHEE_TOOLS_DIR}/build/toolchain/i686/gcc-linaro-5.3.1-2016.05-i686_arm-linux-gnueabi.tar.xz";
			else
				mk_error "toolchain not support in 32bit system...."
			fi
		else
			echo "LICHEE_ARCH=${LICHEE_ARCH} is unkown"
			exit 1
		fi
	fi

	tooldir=${LICHEE_OUT_DIR}/external-toolchain/gcc-${ARCH}
	tooldir_32=${LICHEE_OUT_DIR}/external-toolchain/gcc-arm

	if [ ! -d "${tooldir}" ]; then
		mkdir -p ${tooldir} || exit 1
		tar --strip-components=1 -xf ${toolchain_archive} -C ${tooldir} || exit 1
		if [ "x${LICHEE_ARCH}" = "xarm64" -a "x${LICHEE_PLATFORM}" = "xdragonboard" ] ; then
			mkdir -p ${tooldir_32} || exit 1
			tar --strip-components=1 -xf ${toolchain_32_archive} -C ${tooldir_32} || exit 1
		fi
	fi

	export LICHEE_TOOLCHAIN_32_PATH=${tooldir_32}
	GCC=$(find ${tooldir} -perm /a+x -a -regex '.*-gcc');
	if [ -z "${GCC}" ]; then
		tar --strip-components=1 -xf ${toolchain_archive} -C ${tooldir} || exit 1
		GCC=$(find ${tooldir} -perm /a+x -a -regex '.*-gcc');
		if [ "x${LICHEE_ARCH}" = "xarm64" -a "x${LICHEE_PLATFORM}" = "xdragonboard" ] ; then
			tar --strip-components=1 -xf ${toolchain_32_archive} -C ${tooldir_32} || exit 1
		fi
	fi

	echo ""
	printf "\033[0;31;1mtoolchain path: ${tooldir} \033[0m\n"

	GCC_PREFIX=${GCC##*/};

	if ! echo $PATH | grep -q "${tooldir}" ; then
		export PATH=${PATH}:${tooldir}/bin
	fi

	LICHEE_CROSS_COMPILER="${GCC_PREFIX%-*}";

	if [ -n ${LICHEE_CROSS_COMPILER} ]; then
		if [ -f ${BUILD_CONFIG} ]; then
			sed -i '/LICHEE_CROSS_COMPILER.*/d' ${BUILD_CONFIG}
			sed -i '/LICHEE_TOOLCHAIN_PATH.*/d' ${BUILD_CONFIG}
		fi
		export LICHEE_CROSS_COMPILER=${LICHEE_CROSS_COMPILER}
		export LICHEE_TOOLCHAIN_PATH=${tooldir}
		echo "export LICHEE_CROSS_COMPILER=${LICHEE_CROSS_COMPILER}" >> ${BUILD_CONFIG}
		echo "export LICHEE_TOOLCHAIN_PATH=${tooldir}" >> ${BUILD_CONFIG}
	fi
	printf "\033[0;31;1mcross compiler: ${LICHEE_CROSS_COMPILER} \033[0m\n"
	echo ""
}

function mkkernel()
{
	mk_info "build kernel ..."

	local build_script="scripts/build.sh"
	local isclean=$1

	prepare_toolchain

	# mark kernel .config belong to which platform
	mk_info "will used config ${LICHEE_KERN_DEFCONF}"

	local config_mark="${LICHEE_KERN_DIR}/.config.mark"
	if [ -f ${config_mark} ] ; then
		if ! grep -q "${LICHEE_KERN_DEFCONF}" ${config_mark} ; then
			mk_info "clean last time build for different config used"
			echo "${LICHEE_KERN_DEFCONF}" > ${config_mark}
			(cd ${LICHEE_KERN_DIR} && [ -x ${build_script} ] && ./${build_script} "clean")
		elif [ "x${isclean}" = "xclean" ] ; then
			printf "\033[0;31;1mclean last time build for config cmd used\033[0m\n"
			echo "${LICHEE_KERN_DEFCONF}" > ${config_mark}
			(cd ${LICHEE_KERN_DIR} && [ -x ${build_script} ] && ./${build_script} "clean")
		else
			printf "\033[0;31;1muse last time build config\033[0m\n"
		fi
	else
		echo "${LICHEE_PLATFORM}" > ${config_mark}
	fi

	(cd ${LICHEE_KERN_DIR} && [ -x ${build_script} ] && ./${build_script})
	[ $? -ne 0 ] && mk_error "build kernel Failed" && return 1

	mk_info "build kernel OK."
}

function clkernel()
{
	mk_info "clean kernel ..."

	local build_script="scripts/build.sh"

	prepare_toolchain

	(cd ${LICHEE_KERN_DIR} && [ -x ${build_script} ] && ./${build_script} "clean")

	mk_info "clean kernel OK."
}

function mkboot()
{
	mk_info "build boot ..."
	mk_info "build boot OK."
}

function mksata()
{
	if [ "x$PACK_BSPTEST" = "xtrue" ];then
		clsata
		mk_info "build sata ..."

		local build_script="linux/bsptest/script/bsptest.sh"
		(cd ${LICHEE_SATA_DIR} && [ -x ${build_script} ] && ./${build_script} -b all)

		[ $? -ne 0 ] && mk_error "build kernel Failed" && return 1
		mk_info "build sata OK."

		(cd ${LICHEE_SATA_DIR} && [ -x ${build_script} ] && ./${build_script} -s all)
	fi
}

function clsata()
{
	mk_info "clear sata ..."

	local build_script="linux/bsptest/script/bsptest.sh"
	(cd ${LICHEE_SATA_DIR} && [ -x ${build_script} ] && ./${build_script} -b clean)

	mk_info "clean sata OK."
}

function mk_tinyandroid()
{
	local ROOTFS=${LICHEE_PLAT_OUT}/rootfs_tinyandroid

	mk_info "Build tinyandroid rootfs ..."
	if [ "$1" = "f" ]; then
		rm -fr ${ROOTFS}
	fi

	if [ ! -f ${ROOTFS} ]; then
		mkdir -p ${ROOTFS}
		tar -jxf ${LICHEE_TOOLS_DIR}/build/rootfs_tar/tinyandroid_${LICHEE_ARCH}.tar.bz2 -C ${ROOTFS}
	fi

	mkdir -p ${ROOTFS}/lib/modules
	cp -rf ${LICHEE_KERN_DIR}/output/lib/modules/* \
		${ROOTFS}/lib/modules/

	if [ "x$PACK_BSPTEST" = "xtrue" ];then
		if [ -d ${LICHEE_SATA_DIR}/linux/target ]; then
			mk_info "copy SATA rootfs_def"
			cp -a ${LICHEE_SATA_DIR}/linux/target  ${ROOTFS}/
		fi
	fi

	NR_SIZE=`du -sm ${ROOTFS} | awk '{print $1}'`
	NEW_NR_SIZE=$(((($NR_SIZE+32)/16)*16))

	echo "blocks: $NR_SIZE"M" -> $NEW_NR_SIZE"M""
	make_ext4fs -l \
		$NEW_NR_SIZE"M" ${LICHEE_PLAT_OUT}/rootfs.ext4 ${ROOTFS}
	fsck.ext4 -y ${LICHEE_PLAT_OUT}/rootfs.ext4 > /dev/null
}

function mk_defroot()
{
	local ROOTFS=${LICHEE_PLAT_OUT}/rootfs_def
	local INODES=""
	local BLOCKS=""

	mk_info "Build default rootfs ..."
	if [ "$1" = "f" ]; then
		rm -fr ${ROOTFS}
	fi

	if [ ! -f ${ROOTFS} ]; then
		mkdir -p ${ROOTFS}
		tar -jxf ${LICHEE_TOOLS_DIR}/build/rootfs_tar/target_${LICHEE_ARCH}.tar.bz2 -C ${ROOTFS}
	fi

	mkdir -p ${ROOTFS}/lib/modules
	cp -rf ${LICHEE_KERN_DIR}/output/lib/modules/* \
		${ROOTFS}/lib/modules/

	if [ "x$PACK_BSPTEST" = "xtrue" ];then
		if [ -d ${LICHEE_SATA_DIR}/linux/target ]; then
			mk_info "copy SATA rootfs_def"
			cp -a ${LICHEE_SATA_DIR}/linux/target  ${ROOTFS}/
		fi
	fi

	(cd ${ROOTFS}; ln -fs bin/busybox init)

	fakeroot chown	 -h -R 0:0	${ROOTFS}
	fakeroot mke2img -d ${ROOTFS} -G 4 -R 1 -B 0 -I 0 -o ${LICHEE_PLAT_OUT}/rootfs.ext4

cat  > ${LICHEE_PLAT_OUT}/.rootfs << EOF
chown -h -R 0:0 ${ROOTFS}
makedevs -d \
${LICHEE_TOOLS_DIR}/build/rootfs_tar/_device_table.txt ${ROOTFS}
mksquashfs \
${ROOTFS} ${LICHEE_PLAT_OUT}/rootfs.squashfs -root-owned -no-progress -comp xz -noappend 
EOF
	chmod a+x ${LICHEE_PLAT_OUT}/.rootfs
	fakeroot -- ${LICHEE_PLAT_OUT}/.rootfs 
}

function mkrootfs()
{
	mk_info "build rootfs ..."
	local GCC_32=""

	if [ ${LICHEE_PLATFORM} = "linux" ] ; then

		if [ "x$PACK_TINY_ANDROID" = "xtrue" ]; then
			mk_tinyandroid $1
		elif [ ${SKIP_BR} -ne 0 ]; then
			mk_defroot $1
		else
			if [ "x$PACK_BSPTEST" = "xtrue" ];then
				if [ -d ${LICHEE_SATA_DIR}/linux/target ];then
					mk_info "copy SATA rootfs"
					cp -a ${LICHEE_SATA_DIR}/linux/target ${LICHEE_BR_OUT}/target/
				fi
			fi

			make O=${LICHEE_BR_OUT} -C ${LICHEE_BR_DIR} \
				BR2_TOOLCHAIN_EXTERNAL_PATH=${LICHEE_TOOLCHAIN_PATH} \
				BR2_TOOLCHAIN_EXTERNAL_PREFIX=${LICHEE_CROSS_COMPILER} \
				BR2_JLEVEL=${LICHEE_JLEVEL} target-post-image

			[ $? -ne 0 ] && mk_error "build rootfs Failed" && return 1

			cp ${LICHEE_BR_OUT}/images/rootfs.ext4 ${LICHEE_PLAT_OUT}

			if [ -f "${LICHEE_BR_OUT}/images/rootfs.squashfs" ]; then
				cp ${LICHEE_BR_OUT}/images/rootfs.squashfs ${LICHEE_PLAT_OUT}
			fi
		fi
	elif [ ${LICHEE_PLATFORM} = "dragonboard" ] ; then
		echo "Regenerating dragonboard Rootfs..."
		(
			cd ${LICHEE_BR_DIR}/target/dragonboard; \
			if [ ! -d "./rootfs" ]; then \
				echo "extract dragonboard rootfs.tar.gz"; \
				tar zxf rootfs.tar.gz; \
			fi
		)
		mkdir -p ${LICHEE_BR_DIR}/target/dragonboard/rootfs/lib/modules
		rm -rf ${LICHEE_BR_DIR}/target/dragonboard/rootfs/lib/modules/*
		cp -rf ${LICHEE_KERN_DIR}/output/lib/modules/* \
			${LICHEE_BR_DIR}/target/dragonboard/rootfs/lib/modules/

		if [ "x${LICHEE_ARCH}" = "xarm64" ] ; then
			GCC_32=$(find ${LICHEE_TOOLCHAIN_32_PATH} -perm /a+x -a -regex '.*-gcc');

			if [ "x${GCC_32}" = "x" ] ; then
				mk_error "toolchain_32: LICHEE_TOOLCHAIN_32_PATH is NULL"
				exit 1
			else
				mk_info "toolchain_32="${LICHEE_TOOLCHAIN_32_PATH}
				export PATH=${PATH}:${LICHEE_TOOLCHAIN_32_PATH}/bin
			fi
		fi

		(cd ${LICHEE_BR_DIR}/target/dragonboard; ./build.sh)
		if [ $? -ne 0 ] ; then
			mk_info "build rootfs ERROT"
			exit 1
		fi
		cp ${LICHEE_BR_DIR}/target/dragonboard/rootfs.ext4 ${LICHEE_PLAT_OUT}
	else
		mk_info "skip make rootfs for ${LICHEE_PLATFORM}"
	fi

	mk_info "build rootfs OK."
}

#
# Arg:
#  -k clean, Clean linux default config
#  -r f,  Clean root directory
#
function mklichee()
{
	local kern_par="";
	local sata_par="";
	local root_par="";

	while [ $# -gt 0 ]; do
		case "$1" in
			-k*)
				kern_par=$2;
				break;
				;;
			-s*)
				sata_par=$2;
				break;
				;;
			-r*)
				root_par=$2;
				break;
				;;
			*)
				;;
		esac;
		shift;
	done

	mk_info "----------------------------------------"
	mk_info "build lichee ..."
	mk_info "chip: $LICHEE_CHIP"
	mk_info "platform: $LICHEE_PLATFORM"
	mk_info "business: $LICHEE_BUSINESS"
	mk_info "kernel: $LICHEE_KERN_VER"
	mk_info "arch: $LICHEE_ARCH"
	mk_info "board: $LICHEE_BOARD"
	mk_info "output: out/${LICHEE_CHIP}/${LICHEE_PLATFORM}/${LICHEE_BOARD}"
	mk_info "----------------------------------------"

	check_env

	if [ ${SKIP_BR} -eq 0 ]; then
		mkbr
	fi

	mkkernel ${kern_par} && mksata ${sata_par} && mkrootfs ${root_par}

	[ $? -ne 0 ] && return 1

	printf "\033[0;31;1m----------------------------------------\033[0m\n"
	printf "\033[0;31;1mbuild ${LICHEE_CHIP} ${LICHEE_PLATFORM} ${LICHEE_BUSINESS} lichee OK\033[0m\n"
	printf "\033[0;31;1m----------------------------------------\033[0m\n"
}

function mkclean()
{
	clkernel

	mk_info "clean product output in ${LICHEE_PLAT_OUT} ..."
	cd ${LICHEE_PLAT_OUT}
	ls | grep -v "buildroot" | xargs rm -rf
	cd - > /dev/null

}

function mkdistclean()
{
	clkernel
	if [ ${SKIP_BR} -eq 0 ]; then
		clbr
	fi

	mk_info "clean entires output dir ..."
	rm -rf ${LICHEE_OUT_DIR}
}

function mkpack()
{
	mk_info "packing firmware ..."

	check_env

	(cd ${LICHEE_TOOLS_DIR}/pack && \
		./pack -c ${LICHEE_CHIP} -p ${LICHEE_PLATFORM} -b ${LICHEE_BOARD} -k ${LICHEE_KERN_VER} $@)
}

function mkhelp()
{
	printf "
	mkscript - lichee build script

	<version>: 1.0.0
	<author >: james

	<command>:
	mkboot      build boot
	mkbr        build buildroot
	mkkernel    build kernel
	mkrootfs    build rootfs for linux, dragonboard
	mklichee    build total lichee

	mkclean     clean current board output
	mkdistclean clean entires output

	mkpack      pack firmware for lichee

	mkhelp      show this message

	"
}


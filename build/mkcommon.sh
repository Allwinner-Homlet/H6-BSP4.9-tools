#!/bin/bash
#
# scripts/mkcommon.sh
# (c) Copyright 2013
# Allwinner Technology Co., Ltd. <www.allwinnertech.com>
# James Deng <csjamesdeng@allwinnertech.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
export LC_ALL=C
BR_SCRIPTS_DIR=`dirname $0`
BUILD_CONFIG=.buildconfig
SKIP_BR=0

# source shflags
. ${BR_SCRIPTS_DIR}/shflags

[ -f ${BUILD_CONFIG} ] && . ${BUILD_CONFIG}

# define option, format:
#   'long option' 'default value' 'help message' 'short option'
# WARN: Don't modify default value, because we will check it later
DEFINE_string  'platform' ''          'Platform to build, e.g. sun9iw1p1'  'p'
DEFINE_string  'kernel'   ''          'Kernel to build, e.g. 3.3'          'k'
DEFINE_string  'arch'     ''          'arch to build, e.g. arm, arm64'     'a'
DEFINE_string  'board'    ''          'Board to build, e.g. evb'           'b'
DEFINE_string  'module'   'all'       'Module to build, e.g. buildroot, kernel, uboot, clean' 'm'
DEFINE_string 'business' ''           'business to kernel config, e.g. eagle, secure'     'c'
DEFINE_boolean 'config'   false       'Config compile platfom'             'C'
DEFINE_boolean 'force'    false       'Force to build, clean some old files. ex, rootfs/' 'f'
DEFINE_boolean 'lunch'    false       'Lunch all board configuration'      'l'

FLAGS_HELP="Top level build script for lichee

Examples:
  1. Build lichee, it maybe config platform options, if
     you first use it. And it will pack firmware use default
     argument.
      $ ./build.sh

  2. Configurate platform option
    Old way:
      $ ./build.sh config
        or
      $ ./build.sh --config
        or
      $ ./build.sh -C
    New way:
      $ ./build.sh lunch
	or
      $ ./build.sh --lunch
        or
      $ .nbuild.sh -l

  3. Pack linux, dragonboard image
      $ ./build.sh pack[_<option>] e.g. debug, dump, prvt

  4. Build lichee using command argument
      $ ./build.sh -p <chip_os> e.g. sun8iw1p1_linux, sun8iw1p1

  5. Build module using command argument
      $ ./build.sh -m <module>

  6. Build special kernel
      $ ./build.sh -k <kernel directly>

  7. Build forcely to clean rootfs dir
      $ ./build.sh -f
"

# Set default param for action
#
force=""
config_t="config"
ker_arg="-k clean"
rootfs_arg=""

if [ $# -eq 0 ]; then
	ker_arg=""
fi

# parse the command-line
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

chip=${FLAGS_platform%%_*}
platform=${FLAGS_platform##*_}
business=${FLAGS_business}
kernel=${FLAGS_kernel}
board=${FLAGS_board}
module=${FLAGS_module}
lunch=${FLAGS_lunch}

#
#set -ex
################ Preset an empty command #################
function nfunc(){
	echo "Begin Action"
}
ACTION=":;"

################ Parse other arguments ###################
while [ $# -gt 0 ]; do
	case "$1" in
	config*)
		opt=${1##*_};
		if [ "${opt}" == "all" ]; then
			export CONFIG_ALL=${FLAGS_TRUE};
		else
			export CONFIG_ALL=${FLAGS_FALSE};
		fi

		config_t="config_build";
		FLAGS_config=${FLAGS_TRUE};
		break;
		;;
	lunch*)
		FLAGS_lunch=${FLAGS_TRUE};
		break;
		;;
	pack*)
		opt=${1##*_};
		mode="";
		if [ "${opt}" == "debug" ]; then
			mode="-d card0";
		fi

		if [ "${opt}" == "dump" ]; then
			mode="-m dump";
		fi

		if [ "${opt}" == "prvt" ]; then
			mode="-f prvt";
		fi

		if [ "${opt}" == "secure" ]; then
			mode="-s secure";
		fi

		if [ "${opt}" == "prev" ]; then
			mode="-s prev_refurbish";
		fi

		######### Don't build other module, if pack firmware ########
		ACTION="mkpack ${mode};";
		module="";

		break;
		;;
	clean|distclean)
		ACTION="mkclean;";
		module="";
		break;
		;;
	*)
		;;
	esac;
	shift;
done

# Include base command!
source ${BR_SCRIPTS_DIR}/mkcmd.sh

# if not .buildconfig or FLAGS_config equal FLAGS_TRUE, then mksetup.sh & exit
if [ ${FLAGS_lunch} -eq ${FLAGS_TRUE} \
	-o  ${FLAGS_config} -eq ${FLAGS_TRUE} ]; then

	if [ ${FLAGS_lunch} -eq ${FLAGS_TRUE} ]; then
		config_t="lunch"
	fi

	. ${BR_SCRIPTS_DIR}/mksetup.sh "${config_t%%_*}"

	if [ ${FLAGS_config} -eq ${FLAGS_TRUE} \
		-a "x${config_t##*_}x" != "xbuildx" ]; then
		exit 0;
	fi
fi

if [ ${FLAGS_force} -eq ${FLAGS_TRUE} ]; then
	force="f"
	rootfs_arg="-r f";
fi

# To compatible old platform.
# sun8i & linux-3.x should using buildroot, as we done in top_build.sh
if [ ! -z "`echo ${chip} | grep "sun5[0-9]i"`" \
	-o ! -z "`echo ${LICHEE_CHIP} | grep "sun5[0-9]i"`" \
	-o ! -z "`echo ${LICHEE_CHIP} | grep "sun8iw12"`" \
	-o ! -z "`echo ${chip} | grep "sun8iw12"`" \
	-o ! -z "`echo ${kernel} | grep "linux-4.4"`" \
	-o ! -z "`echo ${LICHEE_KERN_VER} | grep "linux-4.4"`" ] ;  then
	SKIP_BR=1
else
	cd  ${LICHEE_TOP_DIR}
	buildroot/scripts/mkcommon.sh $@
	exit $?
fi

if [ -n "${platform}" -o -n "${chip}" \
	-o -n "${kernel}" -o -n "${board}" ]; then \

	if [ "${platform}" = "${chip}" ] ; then \
		platform="linux";
	fi

	if ! init_chips ${chip} || \
		! init_platforms ${platform} ; then \
		mk_error "Invalid platform '${FLAGS_platform}'";
		exit 1;
	fi

	if ! init_business ${chip} ${business} ; then
		mk_error "invalid business '${FLAGS_business}'  need to set business like -c [business]"
		exit 1
	fi

	if ! init_kern_ver ${kernel} ; then \
		mk_error "Invalid kernel '${FLAGS_kernel}'";
		exit 1;
	fi

	if ! init_arch ${arch} ; then
		mk_error "invalid arch '${FLAGS_arch}'  need to set arch like -a [arch]"
		exit 1
	fi

	if ! init_boards ${LICHEE_CHIP} ${board} ; then \
		mk_error "Invalid board '${FLAGS_board}' need to set board like -b [board]";
		exit 1;
	fi
fi

# init default config
init_defconf

############### Append ',' end character #################
module="${module},"
while [ -n "${module}" ]; do
	act=${module%%,*};
	case ${act} in
		all*)
			ACTION="mklichee ${ker_arg} ${rootfs_arg};";
			module="";
			break;
			;;
		uboot)
			ACTION="${ACTION}mkboot;";
			;;
		buildroot)
			SKIP_BR=0;
			ACTION="${ACTION}mkbr;";
			;;
		kernel)
			ACTION="${ACTION}mkkernel;";
			;;
		clean)
			ACTION="mkclean;";
			module="";
			;;
		distclean)
			ACTION="distclean;";
			module="";
			break;;
	esac
	module=${module#*,};
done


#
# Execute the action list.
#
echo "ACTION List: ${ACTION}========"
action_exit_status=$?
while [ -n "${ACTION}" ]; do
	act=${ACTION%%;*};
	echo "Execute command: ${act} ${force}"
	${act} ${force}
	action_exit_status=$?
	ACTION=${ACTION#*;};
done

exit ${action_exit_status}

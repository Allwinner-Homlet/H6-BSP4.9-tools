#!/bin/bash

if [ -x "tools/build/mkcommon.sh" ] ; then
	tools/build/mkcommon.sh $@
else
	buildroot/scripts/mkcommon.sh $@
fi

#if [ "x$@" = "xconfig" ]; then
#	tools/build/mkcommon.sh $@
#else
#	if [ ! -z "`cat .buildconfig | grep "sun50i"`" ]; then
#		tools/build/mkcommon.sh $@
#	else
#		buildroot/scripts/mkcommon.sh $@
#	fi
#fi

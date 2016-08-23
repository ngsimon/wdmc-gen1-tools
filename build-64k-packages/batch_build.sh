#!/bin/bash

# Save old logfile
if [ -e build.log ]; then
	mv build.log build.log.old
fi
touch build.log

export LC_ALL=C
export LANGUAGE=C
export LANG=C
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEB_CFLAGS_APPEND='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE'
export DEB_BUILD_OPTIONS=nocheck

# $i = $@ = All params.
for i; do
	echo -e "\033[0;32mINFO:\033[0m Installing build-dep for package $i..."
	apt-get -y build-dep $i >> build.log 2>&1
	if [ $? != 0 ]; then
		echo -e "\033[0;31mERROR\033[0m: Install dep. failed with code $?"
		continue
	fi
	echo -e "\033[0;32mINFO:\033[0m Building package $i..."
	apt-get -y source --compile $i >> build.log 2>&1
	if [ $? != 0 ]; then
		echo -e "\033[0;31mERROR\033[0m: Compile failed with code $?"
		continue
	fi
done

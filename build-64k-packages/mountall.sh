#!/bin/bash

show_error () {
	echo -e "\033[0;31mError! Code: $?\033[0m"
	exit 1
}

if [ "$1" = "done" ]; then
	umount /dev/pts || show_error
	umount /dev || show_error
	umount /sys || show_error
	umount /proc || show_error
else
	mount -t proc none /proc || show_error
	mount -t devtmpfs none /dev || show_error
	mount -t devpts none /dev/pts || show_error
	mount -t sysfs none /sys || show_error
fi

echo -e "\033[0;32mDone!\033[0m"
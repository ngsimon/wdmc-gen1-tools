#!/bin/bash

WORK_DIR=buildenv
REPO_URL="http://ftp.debian.org/debian"

apt-get update
apt-get install debootstrap qemu-user-static

mkdir -p $WORK_DIR/usr/bin
cp /usr/bin/qemu-arm-static $WORK_DIR/usr/bin

debootstrap --arch=armhf --no-check-gpg --no-check-certificate --variant=minbase --exclude=yaboot,udev,dbus --include=nano jessie $WORK_DIR $REPO_URL

# Add some cool stuff and build env vars
cat <<\EOF > $WORK_DIR/root/.bashrc
# ~/.bashrc: executed by bash(1) for non-login shells.

PS1='BuildEnv:\w\$ '
# umask 022
cd ~

export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'

export LC_ALL=C
export LANGUAGE=C
export LANG=C
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEB_CFLAGS_APPEND='-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE'
export DEB_BUILD_OPTIONS=nocheck

EOF

# Fix DNS
cp /etc/resolv.conf $WORK_DIR/etc

# Add some sources
cat <<\EOF > $WORK_DIR/etc/apt/sources.list
deb http://ftp.debian.org/debian/ jessie main contrib non-free
deb-src http://ftp.debian.org/debian/ jessie main contrib non-free

deb http://security.debian.org/ jessie/updates main contrib non-free
deb-src http://security.debian.org/ jessie/updates main contrib non-free

deb http://ftp.debian.org/debian/ jessie-updates main contrib non-free
deb-src http://ftp.debian.org/debian/ jessie-updates main contrib non-free
EOF
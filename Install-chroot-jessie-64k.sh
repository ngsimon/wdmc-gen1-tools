#!/bin/bash

# Allester Fox, anionix.ru

RepositoryURLs="http://ftp.anionix.ru/ http://wdnas.ml/debian/ http://wd.hides.su/debian/"

NORM="\033[0m"
INFO="\033[0;32mInfo:$NORM"
ERROR="\033[0;31mError:$NORM"
WARNING="\033[1;33mWarning:$NORM"
INPUT="\033[1;32m => $NORM"

if [ -z $1 ]; then
	chrootDir=debian
else
	chrootDir=$1
fi
chrootBaseDir=/DataVolume/$chrootDir

echo -e "$INFO Welcome to \"Chroot for WDMC-Gen1\" installer"
read -r -e -p $'\e[32mContinue (y/n)? \e[0m' -N1 userAnswer
if [ ! "$userAnswer" = "y" ]; then
	echo -e "$INFO Ok, quit..."
	exit 0
fi

if [ -e /etc/init.d/chroot_$chrootDir.sh ]
then
	echo -e "$ERROR Seems like chroot already installed."
	echo -e "$ERROR Please, delete it, or chose another folder to install"
	echo -e "$ERROR For example: ./chroot64k_install.sh chroot-new"
	exit 1
fi

if [ -d $chrootBaseDir ]
then
	echo -e "$WARNING Found previous chroot. Will moved to $chrootBaseDir.old"
	mv -f $chrootBaseDir $chrootBaseDir.old
else
	mkdir $chrootBaseDir
fi

echo -e "$INFO Replacing APT repository..."
mv /etc/apt/sources.list /etc/apt/sources.old
for url in $RepositoryURLs; do
	echo "deb ${url} jessie-64k main" >> /etc/apt/sources.list
done

echo -e "$INFO Installing debootstrap..."
apt-get update
apt-get --force-yes -y install debootstrap

echo -e "$INFO Installing debian jessie in chroot directory..."
echo -e "$INFO Please, be patient, may takes a long time..."
cp /usr/share/debootstrap/scripts/jessie /usr/share/debootstrap/scripts/jessie-64k
for url in $RepositoryURLs; do
	debootstrap --no-check-gpg --no-check-certificate --variant=minbase --exclude=yaboot,udev,dbus --include=locales jessie-64k $chrootBaseDir $url
	if [ $? = 1 ]; then
		echo -e "$WARNING Cant download files. Trying another mirror..."
	else
		break
	fi
done
if [ ! $? = 0 ]; then
	echo -e "$ERROR Debootstrap fail. Code: $?"
	exit 1
fi

echo "share:x:1000:root,www-data,daapd" >> $chrootBaseDir/etc/group
cp /etc/apt/sources.list $chrootBaseDir/etc/apt/sources.list

# You wanna "brick"? No? So, disable apt!
echo "# Do not use apt in original firmware!" > /etc/apt/sources.list
# Optional: Restore original list.
#mv /etc/apt/sources.old /etc/apt/sources.list

echo -e "$INFO Installing services control script..."
# ==================================== #
cat <<\EOF > $chrootBaseDir/chroot_$chrootDir.sh
#!/bin/bash

SCRIPT_NAME=$(basename $0)
SCRIPT_START='99'
SCRIPT_STOP='01'

MOUNT_DIR="/DataVolume/shares"
CHROOT_DIR="__CHROOT_DIR_PLACEHOLDER__"
ALL_SERVICES="find /etc/rc2.d/ -type l ! -name "*rmnologin" ! -name "*motd" ! -name "*bootlogs" ! -name "*rc.local" -exec"

### BEGIN INIT INFO
# Provides:		$SCRIPT_NAME
# Required-Start:	$local_fs $remote_fs $network
# Required-Stop:	$local_fs $remote_fs $network
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
### END INIT INFO

show_error() {
	echo -e "\e[31mError:\e[0m Code: $1"
	exit $1
}

script_install() {
  cp $0 /etc/init.d/$SCRIPT_NAME || show_error $?
  chmod a+x /etc/init.d/$SCRIPT_NAME || show_error $?
  update-rc.d $SCRIPT_NAME defaults $SCRIPT_START $SCRIPT_STOP > /dev/null || show_error $?
}

script_remove() {
  update-rc.d -f $SCRIPT_NAME remove > /dev/null || show_error $?
  rm -f /etc/init.d/$SCRIPT_NAME || show_error $?
}

###

shareDirMountCount="$(mount | grep "$CHROOT_DIR/" | wc -l)"

check_started() {
  if [[ $shareDirMountCount > 0 ]]; then
      echo "CHROOT servicess seems to be already started, exiting..."
      show_error 2
  fi
}

check_stopped() {
  if [[ $shareDirMountCount = 0 ]]; then
      echo "CHROOT services seems to be already stopped, exiting..."
      show_error 3
  fi
}

###

start() {
	echo -en "\e[32mStarting chroot... \e[0m"
	check_started
	
	for dir in dev proc sys dev/pts; do
		mount -o bind /$dir $CHROOT_DIR/$dir || show_error $?
	done
	mount --bind $MOUNT_DIR $CHROOT_DIR/mnt || show_error $?

	# Run all services in /etc/rc2.d
	chroot $CHROOT_DIR $ALL_SERVICES {} start \;

	echo -e "\e[32mDone!\e[0m"
}

stop() {
	echo -en "\e[32mStopping chroot... \e[0m"
	check_stopped
	
	# Stop all services in /etc/rc2.d
	chroot $CHROOT_DIR $ALL_SERVICES {} stop \;

	for dir in mnt dev/pts proc sys dev; do
		umount $CHROOT_DIR/$dir || show_error $?
	done

	echo -e "\e[32mDone!\e[0m"
}

#########

case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        stop
        sleep 1
        start
    ;;
    install)
        script_install
    ;;
    remove)
        stop
        sleep 1
        script_remove
        echo "Uninstall comleted."
    ;;
    *)
        echo "Usage: $0 {start|stop|restart|install|remove|rescan}"
        exit 1
esac

exit 0

EOF
#################################################################################
eval sed -i 's,__CHROOT_DIR_PLACEHOLDER__,$chrootBaseDir,g' $chrootBaseDir/chroot_$chrootDir.sh
chmod +x $chrootBaseDir/chroot_$chrootDir.sh
$chrootBaseDir/chroot_$chrootDir.sh install
cat <<\EOF > $chrootBaseDir/root/.bashrc
# ~/.bashrc: executed by bash(1) for non-login shells.

PS1='Chroot:\w\$ '
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

EOF
$chrootBaseDir/chroot_$chrootDir.sh start

echo -e "$INFO Chroot installation done."

read -r -e -p $'\e[32mInstall MiniDLNA server (y/n)? \e[0m' -N1 userAnswer
if [ "$userAnswer" = "y" ]; then
	chroot $chrootBaseDir apt-get --force-yes -y install minidlna > /dev/null 2>&1
	chroot $chrootBaseDir /etc/init.d/minidlna stop > /dev/null 2>&1
	chroot $chrootBaseDir /etc/init.d/minissdpd stop > /dev/null 2>&1
	killall minidlna > /dev/null 2>&1
	sed -i 's|media_dir=/var/lib/minidlna|media_dir=/mnt/Public|g' $chrootBaseDir/etc/minidlna.conf
	rm -f $chrootBaseDir/var/lib/minidlna/files.db
	isServicesInstalled="yes"
	echo -e "$INFO MiniDLNA is installed."
	echo -e "$INFO By default minidlna scan only Public folders."
	echo -e "$INFO You can change settings in $chrootBaseDir/etc/minidlna.conf"
fi

read -r -e -p $'\e[32mInstall Transmission BitTorrent client (y/n)? \e[0m' -N1 userAnswer
if [ "$userAnswer" = "y" ]; then
	T_SETTINGS=$chrootBaseDir/etc/transmission-daemon/settings.json
	[ -d /DataVolume/shares/Public/Torrents ] || mkdir /DataVolume/shares/Public/Torrents
	echo -e "$INFO By default download dir is \"Public/Torrents\"."
	echo -e "$INFO You can change this in $T_SETTINGS"
	chroot $chrootBaseDir apt-get --force-yes -y install transmission-daemon
	chroot $chrootBaseDir /etc/init.d/transmission-daemon stop > /dev/null 2>&1
	sed -i 's/USER=debian-transmission/USER=root:share/g' $T_SETTINGS
	sed -i 's/User=debian-transmission/User=root\nGroup=share/g' $chrootBaseDir/lib/systemd/system/transmission-daemon.service
	sed -i "s|\"rpc-whitelist-enabled\": true,|\"rpc-whitelist-enabled\": false,|g" $T_SETTINGS
	sed -i "s|\"cache-size-mb\": 4,|\"cache-size-mb\": 8,|g" $T_SETTINGS
	sed -i "s|\"port-forwarding-enabled\": false,|\"port-forwarding-enabled\": true,|g" $T_SETTINGS
	sed -i "s|\"ratio-limit-enabled\": false,|\"ratio-limit-enabled\": true,|g" $T_SETTINGS
	sed -i "s|\"scrape-paused-torrents-enabled\": true,|\"scrape-paused-torrents-enabled\": false,|g" $T_SETTINGS
	sed -i "s|\"trash-original-torrent-files\": false,|\"trash-original-torrent-files\": true,|g" $T_SETTINGS
	sed -i "s|\"umask\": 18,|\"umask\": 2,|g" $T_SETTINGS
	sed -i "s|\"download-dir\": \"/var/lib/transmission-daemon/downloads\",|\"download-dir\": \"/mnt/Public/Downloads\",|g" $T_SETTINGS	
	isServicesInstalled="yes"
	echo -e "$INFO Transmission is installed."
fi

if [ "$isServicesInstalled" == "yes" ]; then
	read -r -e -p $'\e[32mDo you wish to start chroot services right now (y/n)? \e[0m' -N1 userAnswer
	if [ "$userAnswer" = "y" ]; then
		/etc/init.d/chroot_$chrootDir.sh restart
	fi
fi

echo -e "$WARNING Chroot installation done."
echo -e "$INFO Use /etc/init.d/chroot_$chrootDir.sh for start/stop services in chroot"
echo -e "Or do it manual: chroot $chrootBaseDir /etc/init.d/{service_name} start"
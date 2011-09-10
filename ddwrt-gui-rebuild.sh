#!/bin/bash

WEBDIR="$1"
DIR="$2"

if [ "$DIR" == "" ]
then
	DIR="fmk/rootfs"
fi

if [ "$WEBDIR" == "" ]
then
	WEBDIR="www"
fi

# Web files were likely extracted as root, so we'll need root permissions to modify them
if [ $UID -ne 0 ]
then
	SUDO="sudo"
fi

eval $(cat shared-ng.inc)
HTTPD="$DIR/usr/sbin/httpd"
WWW="$DIR/etc/www"

echo -e "Firmware Mod Kit (ddwrt-gui-rebuild) $VERSION, (c)2011 Craig Heffner\n"

if [ ! -d "$DIR" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
	echo -e "Usage: $0 [input directory] [rootfs directory]\n"
	exit 1
fi

if [ ! -e "$HTTPD" ] || [ ! -e "$WWW" ]
then
	echo "Unable to locate httpd / www files in directory $DIR. Quitting..."
	exit 1
fi

# Restore!
$SUDO ./src/webcomp-tools/webdecomp --httpd="$HTTPD" --www="$WWW" --dir="$WEBDIR" --restore


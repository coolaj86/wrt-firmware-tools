#!/bin/sh
VERSION='0.40 beta'
#
# Title: ipkg_install_all.sh
# Author: Jeremy Collake <jeremy.collake@gmail.com>
# Site: http://www.bitsum.com
#
# Invoke ipkg_install for every package in the given
# folder.
#
# See documentation at:
#  http://www.bitsum.com/firmware_mod_kit.htm
#
# USAGE: ipkg_remove_all.sh PACKAGES_FOLDER WORKING_DIRECTORY/
#
# PACKAGE_SOURCE is the path to the .PKG file(s). 
#
# WORKING_DIRECTORY is the working directory supplied to
#  extract_firmware.sh.
#
# Example:
#
# ./ipkg_remove_all.sh ../packages ../working_dir/
#
echo "$0 v$VERSION, (c)2006 Jeremy Collake"
##################################################
if [ ! $# = "2" ]; then
	echo " Invalid usage"
	echo " USAGE: $0 PACKAGE_PATH WORKING_DIRECTORY"
	exit 1
fi
BASE_NAME=`basename $1`
echo " Installing $BASE_NAME"
##################################################
if [ ! -e "$1" ]; then
	echo " ERROR: $1 does not exist."
	exit 1
fi
##################################################
for i in $( ls "$1" ); do
	"./ipkg_remove.sh" "$1/$i" "$2"
done

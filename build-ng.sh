#!/bin/bash

DIR="$1"

if [ "$DIR" == "" ]
then
	DIR="fmk"
fi

# Order matters here!
eval $(cat shared-ng.inc)
eval $(cat $CONFLOG)
FSOUT="$DIR/new-filesystem.$FS_TYPE"

echo -e "Firmware Mod Kit (build-ng) $VERSION, (c)2011 Craig Heffner, Jeremy Collake\nhttp://www.bitsum.com\n"

if [ ! -d "$DIR" ]
then
	echo -e "Usage: $0 [build directory]\n"
	exit 1
fi

echo "Building new $FS_TYPE file system..."

# Build the appropriate file system
case $FS_TYPE in
	"squashfs")
		$MKFS "$ROOTFS" "$FSOUT" $ENDIANESS -all-root
		;;
	"cramfs")
		$MKFS "$ROOTFS" "$FSOUT"
		if [ "$ENDIANESS" == "-be" ]
		then
			mv "$FSOUT" "$FSOUT.le"
			./src/cramfsswap/cramfsswap "$FSOUT.le" "$FSOUT"
			rm -f "$FSOUT.le"
		fi
		;;
	*)
		echo "Unsupported file system '$FS_TYPE'!"
		;;
esac

if [ ! -e $FSOUT ]
then
	echo "Failed to create new file system! Quitting..."
	exit 1
fi

# Append the new file system to the first part of the original firmware file
cp $HEADER_IMAGE $FWOUT
cat $FSOUT >> $FWOUT

# Calculate and create any filler bytes required between the end of the file system and the footer / EOF.
CUR_SIZE=$(ls -l $FWOUT | awk '{print $5}')
((FILLER_SIZE=$FW_SIZE-$CUR_SIZE-$FOOTER_SIZE))

if [ "$FILLER_SIZE" -lt 0 ]
then
	echo "ERROR: New firmware image will be larger than original image! This is not supported."
	echo -e "\tOriginal file size: $FW_SIZE"
	echo -e "\tCurrent file size:  $CUR_SIZE"
	echo "Quitting..."
	exit 1
else
	echo "Remaining free bytes in firmware image: $FILLER_SIZE"
	perl -e "print \"\xFF\"x$FILLER_SIZE" >> "$FWOUT"
fi

# Append the footer to the new firmware image, if there is any footer
if [ "$FOOTER_SIZE" -gt "0" ]
then
	cat $FOOTER_IMAGE >> "$FWOUT"
fi

# Calculate new checksum values for the firmware header
./src/crcalc/crcalc "$FWOUT" "$BINLOG"

if [ $? -eq 0 ]
then
	echo -n "Finished! "
else
	echo -n "Firmware header not supported; firmware checksums may be incorrect. "
fi

echo "New firmware image has been saved to: $FWOUT"

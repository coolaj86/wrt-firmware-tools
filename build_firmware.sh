#!/bin/sh
. "./shared.inc"
VERSION='0.63'
#
# Title: build_firmware.sh
# Author: Jeremy Collake <jeremy.collake@gmail.com>
# Site: http://www.bitsum.com/firmware_mod_kit.htm
#
# See documentation at:
#  http://www.bitsum.com/firmware_mod_kit.htm
#
# USAGE: build_firmware.sh OUTPUT_DIRECTORY/ WORKING_DIRECOTRY/
#
# This scripts builds the firmware image from [WORKING_DIRECTORY],
# with the following subdirectories:
#
#    image_parts/   <- firmware seperated
#    rootfs/ 	    <- filesystem
#
# Example:
#
# ./build_firmware.sh new_firmwares/ std_generic/
#
#
FIRMARE_BASE_NAME=custom_image
EXIT_ON_FS_PROBLEM="0"

echo
echo " Firmware Mod Kit (build) v$VERSION, (c)2008 Jeremy Collake"
echo " http://www.bitsum.com"

#################################################################
# function: BuildLinuxRawFirmwareType
# puts together firmwares types like the TEW-632BRP
#################################################################
BuildLinuxRawFirmwareType() {	
	OUTPUT_PATH=$1
	PARTS_PATH=$2
	OUTPUT_FIRMWARE_FILENAME="tew-632brp-fmk-firmware.bin"
	echo " Building firmware from directory $2 ..."		
	if [ ! -e "$PARTS_PATH/rootfs/" ]; then
		echo " ERROR: rootfs must exist"
		exit 1
	fi
	mkdir -p "$OUTPUT_PATH"
	rm -f "$PARTS_PATH/image_parts/squashfs-3-lzma.img" "$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME" "$PARTS_PATH/image_parts/rootfs.img" "$PARTS_PATH/image_parts/*.new"
	if [ -f "$PARTS_PATH/.squashfs3_lzma_fs" ]; then			
		# make squashfs image if marker present
		echo " Building squashfs file system ..."
		./src/squashfs-3.0/mksquashfs-lzma "$PARTS_PATH/rootfs/" "$PARTS_PATH/image_parts/squashfs-3-lzma.img" -all-root -be -noappend 2>/dev/null >> build.log
		ln -s "squashfs-3-lzma.img" "$PARTS_PATH/image_parts/rootfs.img"
		filesize=$(du -b "$PARTS_PATH/image_parts/squashfs-3-lzma.img" | cut -f 1)
	else
		# make jffs2 image if marker not present
		echo " Building JFFS2 file system ..."
		./src/jffs2/mkfs.jffs2 -r "$PARTS_PATH/rootfs/" -o "$PARTS_PATH/image_parts/jffs2.img" --big-endian --squash # 2>/dev/null >> build.log
		ln -s "jffs2.img" "$PARTS_PATH/image_parts/rootfs.img"
		filesize=$(du -b "$PARTS_PATH/image_parts/jffs2.img" | cut -f 1)
	fi
	# verify rootfs isn't too big for the Trendnet TEW-632BRP with its default partition mapping	
	if [ $filesize -ge 2818049 ]; then
		echo " WARNING: rootfs image size appears too large ..."
	fi
	# build firmware image
	cp "$PARTS_PATH/image_parts/vmlinuz" "$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME"
	dd "if=$PARTS_PATH/image_parts/rootfs.img" "of=$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME" bs=1K seek=1024 2>/dev/null >> build.log
	if [ -f "$PARTS_PATH/image_parts/hwid.txt" ]; then
		# prepend four NULL bytes to the platform ID, causes image to be accepted on 
		#  either TEW-632BRP A1.0 or A1.1 by effectively nullifying the platform ID
		printf "\000\000\000\000" >> "$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME"
		# now write platform ID
		cat "$PARTS_PATH/image_parts/hwid.txt" >> "$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME"
	else
		echo " ERROR: hwid.txt not found. This image needs a TARGET."
		exit 1
	fi	
	filesize=$(du -b "$OUTPUT_PATH/$OUTPUT_FIRMWARE_FILENAME" | cut -f 1)
	if [ $filesize -ge 3866649 ]; then
		echo " WARNING: firmware image appears to be too large ..."
	fi

}

#################################################################
# InvokeTRX ( OutputDir, WorkingDir, filesystem image filename )
#################################################################
InvokeTRX ()
{
	echo " Building base firmware image (generic) ..."	
	SEGMENT_1="$2/image_parts/segment1"
	if [ -f "$2/image_parts/segment2" ]; then
		SEGMENT_2="$2/image_parts/segment2"
	else
		SEGMENT_2=""
	fi
	# I switched to asustrx due to bug in trx with big endian OS X.
	#  it works just like trx if you don't supply a version number (skips addver appendage)
	"src/asustrx" -o "$1/$FIRMARE_BASE_NAME.trx" \
		$SEGMENT_1 $SEGMENT_2 \
		"$2/image_parts/$3" \
			>> build.log 2>&1
	echo " Building base firmware image (asus) ..."	
	"src/asustrx" -p WL500gx -v 1.9.2.7 -o "$1/$FIRMARE_BASE_NAME-asus.trx" \
		$SEGMENT_1 $SEGMENT_2 \
		"$2/image_parts/$3" \
		 >> build.log 2>&1

}

#################################################################
# CreateTargetImages ( OutputDir, WorkingDir )
#
# addpattern (HDR0) images. Maybe other model specific stuff
# later.
#################################################################
CreateTargetImages ()
{
	echo " Making $1/$FIRMARE_BASE_NAME-wrtsl54gs.bin"
	if [ ! -f "$1/$FIRMARE_BASE_NAME.trx" ]; then
		echo " ERROR: Sanity check failed."
		exit 1
	fi
	"src/addpattern" -4 -p W54U -v v4.20.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		 -o "$1/$FIRMARE_BASE_NAME-wrtsl54gs.bin" -g >> build.log 2>&1
	echo " Making $1/$FIRMARE_BASE_NAME-wrt54g.bin"
	"src/addpattern" -4 -p W54G -v v4.20.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54g.bin" -g >> build.log 2>&1
	echo " Making $1/$FIRMARE_BASE_NAME-wrt54gs.bin"
	"src/addpattern" -4 -p W54S -v v4.70.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54gs.bin" -g >> build.log 2>&1
	echo " Making $1/$FIRMARE_BASE_NAME-wrt54gsv4.bin"
	"src/addpattern" -4 -p W54s -v v1.05.0 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54gsv4.bin" -g >> build.log 2>&1
	echo " Making $1/$FIRMARE_BASE_NAME-generic.bin"
	ln -s "$FIRMARE_BASE_NAME.trx" "$1/$FIRMARE_BASE_NAME-generic.bin" >> build.log 2>&1
}

#################################################################
# Build_WRT_Images( OutputDir, WorkingDir )
#################################################################
Build_WRT_Images ()
{
	echo " Building squashfs-lzma filesystem ..."
	if [ -e "$2/image_parts/squashfs-lzma-image-3_0" ]; then			
		if [ -f "$2/image_parts/.sq_lzma_damn_small_variant_marker" ]; then
		   echo " Utilizing lzma damn small variant ..."		   
		   echo " WARNING: Support for these recently added, not fully tested... be careful."
		   echo "          Please report to jeremy.collake@gmail.com success or failure."
		   echo " This may take a while ..."
		   "src/squashfs-3.0-lzma-damn-small-variant/mksquashfs-lzma" "$2/rootfs/" "$2/image_parts/squashfs-lzma-image-new" \
			-noappend -root-owned -le >> build.log		
		else
		   echo " Utilizing lzma standard variant ..."
		   "src/squashfs-3.0/mksquashfs-lzma" "$2/rootfs/" "$2/image_parts/squashfs-lzma-image-new" \
			-noappend -root-owned -le -magic "$2/image_parts/squashfs_magic" >> build.log		
		fi
		# -magic to fix brainslayer changing squashfs signature in 08/10/06+ firmware images
	 	if [ $? != 0 ]; then
			echo " ERROR - mksquashfs failed."
			exit 1	
		fi
	elif [ -f "$2/image_parts/squashfs-lzma-image-2_x" ]; then
		 echo " Utilizing squashfs lzma 2.1-r2 ..."
		   "src/squashfs-2.1-r2/mksquashfs-lzma" "$2/rootfs/" "$2/image_parts/squashfs-lzma-image-new" \
			-noappend -le >> build.log	
	else
		echo " ERROR - Working directory contains no sqfs filesystem?"
		exit 1
	fi	
	#################################################################
	InvokeTRX "$1" "$2" "squashfs-lzma-image-new"
	CreateTargetImages "$1" "$2" 	
}

#################################################################
# MakeCramfs (output file, root dir)
#
# invokes mkcramfs
#
#################################################################
MakeCramfs ()
{
	echo " Building cramfs file system ..."
	./src/cramfs-2.x/mkcramfs "$2" "$1" >> build.log 2>&1
	if [ $? != 0 ]; then
		echo " ERROR: creating cramfs file system failed.".
		exit "$?"
	else
		echo " Successfully created cramfs image."
	fi
}

#################################################################
# Build_WL530G_Image (OutputDir, WorkingDir, fs image filename [only] )
#
# Builds an ASUS WL530/520/550G image.
#
#################################################################
Build_WL530G_Image ()
{
	echo " Building wl-530/520/550g style image (static TRX offsets)."
	./src/asustrx -p WL530g -v 1.9.4.6 -o "$1/$FIRMARE_BASE_NAME-wl530g.trx" -b 32 "$2/image_parts/segment1" -b 655360 "$2/image_parts/$3"  >> build.log 2>&1	
}


#################################################################
#################################################################
#################################################################

if [ $# = 2 ]; then
	sh ./check_for_upgrade.sh
	#################################################################
	PlatformIdentify 
	#################################################################
	TestFileSystemExit "$1" "$2"
	#################################################################
	TestIsRoot
	#################################################################
	if [ ! -f "./build_firmware.sh" ]; then
		echo " ERROR - You must run this script from the same directory as it is in!"
		exit 1
	fi
	#################################################################
	# remove deprecated stuff
	if [ -f "./src/mksquashfs.c" ] || [ -f "mksquashfs.c" ]; then
		DeprecateOldVersion
	fi
	#################################################################
	# Invoke BuildTools, which tries to build everything and then
	# sets up appropriate symlinks.
	#
	BuildTools "build.log"
	#################################################################
	echo " Preparing output directory $1 ..."
	mkdir -p $1 >> build.log 2>&1
	rm "$1/$FIRMWARE_BASE_NAME*.*" "$1" >> build.log 2>&1
	
	if [ -f "$2/image_parts/.trx-sqfs" ]; then
		echo " Detected WRT squashfs-lzma style."
		Build_WRT_Images "$1" "$2"
	elif [ -f "$2/.linux_raw_type" ]; then
		echo " Detected linux raw type firmware."
		BuildLinuxRawFirmwareType "$1" "$2"		
	elif [ -f "$2/image_parts/cramfs-image-x_x" ]; then
		echo " Detected cramfs file system."
		TestIsRoot
		# remove old filename of new image..
		rm -f "$2/image_parts/cramfs-image-1.1"
		MakeCramfs "$2/image_parts/cramfs-image-new" "$2/rootfs"
		# todo: rewrite this terrible test
		grep "530g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1				
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		grep "550g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1			
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		grep "520g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1		
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		if [ "$IS_530G_STYLE" = "1" ]; then		
			Build_WL530G_Image "$1" "$2" "cramfs-image-new"
		else
			echo " No specific firmware type known, so am making standard images."
			InvokeTRX "$1" "$2" "cramfs-image-new"
			CreateTargetImages "$1" "$2"			
		fi 
	else		
		echo " ERROR: Unknown or unsupported firmware image."
		exit 1
	fi

	echo " Firmware images built."
	ls -l "$1"
	echo " All done!"
else
	#################################################################
	echo " Incorrect usage."
	echo " USAGE: $0 OUTPUT_DIR WORKING_DIR"
	exit 1
fi
exit 0

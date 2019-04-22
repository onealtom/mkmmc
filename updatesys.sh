#!/bin/sh

# the purpose of this script is to flash u-boot, Linux, 
# and the Linux ramdisk to QSPI flash

path=$1
BOOT_FILE="boot.bin"
BOOT_PART="/dev/mtd0"
BOOT_ENV_PART="/dev/mtd1"
BIT_PART="/dev/mtd2"
KERNEL_FILE="uImage"
KERNEL_PART="/dev/mtd3"
DT_FILE="devicetree.dtb"
DT_PART="/dev/mtd4"
RD_FILE="rootfs.tar"
RD_PART="/dev/mtd5"


if [ $# -ne 1 ] ; then
        echo "usage: update_qspi.sh <path to images>"
        exit
fi

check_cmd()
{
        $1

        if [ $? -ne 0 ];then
            echo "FAILED!!!"
            echo
            exit 1
        fi
}

# (c) Copyright 2009 Graeme Gregory <dp@xora.org.uk>
# Licensed under terms of GPLv2
#
# Parts of the procudure base on the work of Denys Dmytriyenko
# http://wiki.omap.com/index.php/MMC_Boot_Format

mkemmc()
{	
	echo "format emmc"
	
	LC_ALL=C

	if [ $# -ne 1 ]; then
		echo "Usage: $0 <drive>"
		exit 1;
	fi

	DRIVE=$1

	dd if=/dev/zero of=$DRIVE bs=1024 count=1024

	SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`

	echo DISK SIZE - $SIZE bytes

	CYLINDERS=`echo $SIZE/255/63/512 | bc`

	echo CYLINDERS - $CYLINDERS

	{
	#echo ,25,0x0C,*
	echo ,,,-
	} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE

	#if [ -b ${DRIVE}1 ]; then
	#	mkfs.vfat -F 32 -n "boot" ${DRIVE}1
	#else
	#	if [ -b ${DRIVE}p1 ]; then
	#		mkfs.vfat -F 32 -n "boot" ${DRIVE}p1
	#	else
	#		echo "Cant find boot partition in /dev"
	#	fi
	#fi

	if [ -b ${DRIVE}1 ]; then
		mkfs.ext4 -L "rootfs" ${DRIVE}1
	else
		if [ -b ${DRIVE}p1 ]; then
			mkfs.ext4 -L "rootfs" ${DRIVE}p1
		else
			echo "Cant find rootfs partition in /dev"
		fi
	fi
}


printf "\nWriting ${BOOT_FILE} Image To QSPI Flash @${BOOT_PART}\n"
check_cmd "flashcp -v $path/${BOOT_FILE} ${BOOT_PART}"

printf "\nerase bootenv @${BOOT_ENV_PART}\n"
flash_erase ${BOOT_ENV_PART} 0 0

if dmesg | grep "7z010" > /dev/null; then
	printf "\nWriting 7z010.bit to QSPI Flash ${BIT_PART}\n"
	printf "0: %.8x" `stat -c %s $path/7z010.bit` | sed -e 's/0\: \(..\)\(..\)\(..\)\(..\)/0\: \4\3\2\1/' | xxd -r -g0 > /tmp/bitstream
	cat $path/7z010.bit >> /tmp/bitstream	
	check_cmd "flashcp -v /tmp/bitstream ${BIT_PART}"
else
	printf "\nWriting 7z020.bit to QSPI Flash ${BIT_PART}\n"
	printf "0: %.8x" `stat -c %s $path/7z020.bit` | sed -e 's/0\: \(..\)\(..\)\(..\)\(..\)/0\: \4\3\2\1/' | xxd -r -g0 > /tmp/bitstream
	cat $path/7z020.bit >> /tmp/bitstream
	check_cmd "flashcp -v /tmp/bitstream ${BIT_PART}"
fi
	
printf "\nWriting ${KERNEL_FILE} To QSPI Flash @${KERNEL_PART}\n"
check_cmd "flashcp -v $path/${KERNEL_FILE} ${KERNEL_PART}"

printf "\nWriting ${DT_FILE} To QSPI Flash @${DT_PART}\n"
check_cmd "flashcp -v $path/${DT_FILE} ${DT_PART}"

#printf "\nWriting ${RD_FILE} To QSPI Flash @${RD_PART}\n"
#check_cmd "flashcp -v $path/${RD_FILE} ${RD_PART}"

printf "\nWriteing rootfs to emmc\n"
mkemmc /dev/mmcblk0 && mount /dev/mmcblk0p1 /media && rm -rf /media/lost+found && tar -xvf $path/${RD_FILE} -C /media
sync && umount /media

echo "QSPI flash update successfully!"
echo


#!/bin/bash



# 卸载所有$1分区挂载

echo "[Unmounting all existing partitions on the device ]"

#umount $1*

echo "[Partitioning $1...]"

# 擦除分区表

DRIVE=$1
dd if=/dev/zero of=$DRIVE bs=1024 count=1024

#SIZE=`sfdisk -l $DRIVE | grep Disk | awk '{print $5}'`

SIZE=`sfdisk -l /dev/mmcblk1 | grep Disk | awk '{print $5}'`
echo DISK SIZE - $SIZE bytes



sfdisk /dev/*mmcblk1 << EOF
,256M,0x0C,*
,256M,83
,512M,83
,-,5
,1024M,83
,-,83
EOF


echo "[Making filesystems...]"

if [[ ${DRIVE} == /dev/*mmcblk* ]]
then
    DRIVE=${DRIVE}p
fi

# 格式化分区

mkfs.vfat -F 32 -n "boot" /dev/mmcblk1p1
mkfs.ext4 -L "bak" -F /dev/mmcblk1p2
mkfs.ext4 -L "sysroot" -F /dev/mmcblk1p3
mkfs.ext4 -L "opt" -F /dev/mmcblk1p5
mkfs.ext4 -L "data" -F /dev/mmcblk1p6

sync
sync


sync

echo "[Done]"


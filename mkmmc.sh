#!/bin/bash

# 如果参数只有一个，这里就会使用默认文件夹下的程序，mkmmc-android.sh会重新调用，执行完再退出
EXPECTED_ARGS=1
if [ $# == $EXPECTED_ARGS ]
then
    echo "Assuming Default Locations for Prebuilt Images"
    $0 $1 Boot_Images/MLO Boot_Images/u-boot.img Boot_Images/zImage Boot_Images/uEnv.txt Boot_Images/dtbs/am335x-boneblack.dtb Filesystem/rootfs* Media_Clips START_HERE
    exit
fi



# 提示信息
echo "All data on "$1" now will be destroyed! Continue? [y/n]"
read ans
if ! [ $ans == 'y' ]
then
    exit
fi

# 卸载所有$1分区挂载
echo "[Unmounting all existing partitions on the device ]"

umount $1*

echo "[Partitioning $1...]"

# 擦除分区表
DRIVE=$1
dd if=/dev/zero of=$DRIVE bs=1024 count=1024

SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`

echo DISK SIZE - $SIZE bytes

CYLINDERS=`echo $SIZE/255/63/512 | bc`

sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE << EOF
,31,0x0C,*
32,,,-
EOF


echo "[Making filesystems...]"

if [[ ${DRIVE} == /dev/*mmcblk* ]]
then
    DRIVE=${DRIVE}p
fi

# 格式化分区
mkfs.vfat -F 32 -n "boot" ${DRIVE}1
mkfs.ext3 -L "rootfs" ${DRIVE}2
sync
sync

echo "[Copying files...]"

# 挂载并拷贝文件到分区1
mount ${DRIVE}1 /mnt
cp ./images/* /mnt/
cp ./rootfs/rootfs.cpio.uboot /mnt/uramdisk.image.gz
# 卸载分区
umount ${DRIVE}1

# 拷贝文件系统内容到分区2
mount ${DRIVE}2 /mnt
#tar jxvf $7 -C /mnt &> /dev/null
tar xvf rootfs/rootfs.tar -C /mnt --strip-components 1
chmod 755 /mnt
umount ${DRIVE}2

sync

echo "[Done]"
# 1. Set the Project's 'Top' directory - this is the folder that contains the GSRD, Software, Tools, etc.
export U_BOOT_BUILD_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) # The script must be placed at the top/overhead place
export PROJ_TOP_FOLDER=$U_BOOT_BUILD_SCRIPT_DIR

export GHRD_TOP_FOLDER=/home/monklp/workspace/GITHUB/@monkstein88/qmtech_c5soc_kfb_dual_sdram_ghrd
export UBOOT_TOP_FOLDER=/home/monklp/workspace/GITHUB/@monkstein88/u-boot-socfpga
echo $GHRD_TOP_FOLDER

# 2. Set the ARM linux build toolchaing for U-Boot compilation
#export PATH=$PROJ_TOP_FOLDER/toolchain/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-linux-gnueabihf/bin:$PATH
export PATH=/home/monklp/workspace/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-linux-gnueabihf/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-

# 3. Build U-Boot
cd $PROJ_TOP_FOLDER/software/u-boot-socfpga
make mrproper
sync
make clean
sync
cd $PROJ_TOP_FOLDER/software/u-boot-socfpga/arch/arm/mach-socfpga/cv_bsp_generator
python2.7 cv_bsp_generator.py -i $PROJ_TOP_FOLDER/qmtech_c5soc_kfb_ghrd/quartus/hps_isw_handoff/soc_system_hps_0 -o ../../../../board/qmtech/c5soc-kfb-dual-sdram/qts
cd $PROJ_TOP_FOLDER/software/u-boot-socfpga
make socfpga_c5soc_kfb_dual_sdram_defconfig
sync
make -j 
sync

# For U-Boot 2024.7
# 4. Insert a SD-Card in your PC, prepare, partition and flash it with the U-Boot image
cd $PROJ_TOP_FOLDER
lsblk # Check which device is the SD-Card top partition - in the below case its 'sdb'
#NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
#sda      8:0    0 476,9G  0 disk 
#├─sda1   8:1    0   123M  0 part /boot/efi
#├─sda2   8:2    0   123M  0 part 
#└─sda3   8:3    0   473G  0 part /
#sdb      8:16   1  29,7G  0 disk 
#├─sdb1   8:17   1     1M  0 part 
#├─sdb2   8:18   1   511M  0 part 
#└─sdb3   8:19   1  29,2G  0 part 
export SDCARD_DEV=/dev/sdb
sudo umount $SDCARD_DEV*
sync
sudo wipefs -a $SDCARD_DEV
sync
sudo dd if=/dev/zero of=$SDCARD_DEV bs=1M count=10 conv=sync  # zeros the first 10MB
sync
# Here is a code snippet of commands you can run to create the partitions, set the partition type, and format the partitions.
sudo parted --script $SDCARD_DEV mklabel msdos
sync
sudo parted --script $SDCARD_DEV mkpart primary 2048s 4095s # This is the 1st partition
sync
sudo parted --script $SDCARD_DEV mkpart primary fat32 4096s 1050623s # This is the 2nd partition
sync
sudo parted --script $SDCARD_DEV mkpart primary ext4 1050624s 100%  # This is the 3rd partition
sync
sudo sfdisk --part-type $SDCARD_DEV 1 a2 # The first partition of must be of type A2 and will be filled with the u-boot pre-loader
sync
sudo mkfs.vfat -F 32 ${SDCARD_DEV}2
sync
sudo mkfs.ext4 -F ${SDCARD_DEV}3 
sync
# Now, in order to boot to the U-Boot prompt, complete this commands.
cd $PROJ_TOP_FOLDER/software/u-boot-socfpga
sudo dd if=u-boot-with-spl.sfp of=${SDCARD_DEV}1 bs=512 conv=sync
sudo sync
sudo umount $SDCARD_DEV*
sync



# For U-Boot v2026.1
# Here is a code snippet of commands you can run to create the partitions, set the partition type, and format the partitions.
export SDCARD_DEV=/dev/sdb
sudo umount $SDCARD_DEV*
sync
sudo wipefs -a $SDCARD_DEV        # wipes partition table and filesystem signatures
sync
sudo dd if=/dev/zero of=$SDCARD_DEV bs=1M count=10 conv=sync  # zeros the first 10MB
sync
sudo fdisk -l /dev/sdb
sync
sudo umount $SDCARD_DEV*
sync
sudo parted --script $SDCARD_DEV mklabel msdos
sync
sudo parted --script $SDCARD_DEV mkpart primary fat32 1MiB 15MiB # This is the 1st partition
sync
sudo parted --script $SDCARD_DEV set 1 boot on
sync
sudo parted --script $SDCARD_DEV mkpart primary       16MiB 32MiB # This is the 2nd partition
sync
sudo sfdisk --part-type $SDCARD_DEV 2 a2 # The second partition of must be of type A2 and will be filled with the u-boot pre-loader
sync
sudo mkfs.vfat -F 32 ${SDCARD_DEV}1 #  The first partition of must be of type fat and will be used to place the u-boot.img
sync
sudo mount ${SDCARD_DEV}1 /mnt/boot
sync
sudo dd if=u-boot.img of=${SDCARD_DEV}1 bs=512 conv=sync
sync
sudo cp u-boot.img /mnt/boot
sync
sudo umount /mnt/boot
sync
sudo dd if=u-boot-with-spl.sfp of=${SDCARD_DEV}2 bs=512 conv=sync
sync
sudo umount $SDCARD_DEV*
sync



export SDCARD_DEV=/dev/sdb
sudo umount $SDCARD_DEV*
sync
sudo wipefs -a $SDCARD_DEV        # wipes partition table and filesystem signatures
sudo dd if=/dev/zero of=$SDCARD_DEV bs=1M count=10 conv=sync  # zeros the first 10MB
sync
sudo fdisk -l $SDCARD_DEV  # should show no valid partition table
sync
# Wipe and partition
sudo parted $SDCARD_DEV -- mklabel msdos
sudo parted $SDCARD_DEV -- mkpart primary fat32  2048s      32767s      # part1 FAT32 0 - 16MB
sudo parted $SDCARD_DEV -- mkpart primary ext4   32768s     1048575s    # part2 ext4  16MB - 512MB
sudo parted $SDCARD_DEV -- mkpart primary        1048576s   1049599s    # part3 RAW    512 - 513MB
sudo parted $SDCARD_DEV -- set 1 boot on
# Format partitions 1 and 2 (NOT 3)
sudo mkfs.vfat -F 32 -n BOOT  ${SDCARD_DEV}1
sudo mkfs.ext4 -L rootfs      ${SDCARD_DEV}2
sudo parted $SDCARD_DEV -- type 3 0xa2
# partition 3 — NO mkfs, written raw
sudo dd if=u-boot-with-spl.sfp of=${SDCARD_DEV}3 bs=512 conv=sync
sync


cd $PROJ_TOP_FOLDER
rm -rf sdcard && mkdir sdcard -p 
export SDCARD_MNT=$PROJ_TOP_FOLDER/sdcard/ # This directory will be used as mounting point for the SD Card
sudo mount ${SDCARD_DEV}2 $SDCARD_MNT
sudo cp u-boot.img $SDCARD_MNT
sudo sync
sudo umount $SDCARD_MNT
sudo sync


# ================================

export GHRD_TOP_FOLDER='/home/monklp/workspace/GITHUB/_monkstein88_/qmtech_c5soc_kfb_dual_sdram_ghrd'  # 'main' branch (take the latest commit)
export UBOOT_TOP_FOLDER='/home/monklp/workspace/GITHUB/_monkstein88_/u-boot-socfpga'                   # 'qmtech_c5soc_kfb_dual_sdram_v2024.07' branch (take the latest commit)
export LINUX_TOP_FOLDER='/home/monklp/workspace/GITHUB/_monkstein88_/linux-socfpga.a9'                 # 'socfpga-6.6.22-lts' branch  (take the latest commit)
export ROOTFS_TOP_FOLDER='/home/monklp/workspace/GITHUB/_monkstein88_/rootfs-socfpga'                  # 'main' branch (take the latest commit)
export BUILD_ENV_FOLDER='/home/monklp/workspace/GITHUB/_monkstein88_/qmtech_linux_build_env'           # 'main' branch (take the latest commit)

export SDCARD_DEVICE=/dev/sdb

echo $GHRD_TOP_FOLDER
echo $UBOOT_TOP_FOLDER
echo $LINUX_TOP_FOLDER
echo $ROOTFS_TOP_FOLDER
echo $BUILD_ENV_FOLDER

cd $GHRD_TOP_FOLDER # directory could be reached. Ok.
cd $UBOOT_TOP_FOLDER # directory could be reached. Ok.
cd $LINUX_TOP_FOLDER # directory could be reached. Ok.
cd $ROOTFS_TOP_FOLDER # directory could be reached. Ok.
cd $BUILD_ENV_FOLDER # directory could be reached. Ok.


# 
cd $UBOOT_TOP_FOLDER/arch/arm/mach-socfpga/cv_bsp_generator
python2.7 cv_bsp_generator.py -i $GHRD_TOP_FOLDER/quartus/hps_isw_handoff/soc_system_hps_0 -o ../../../../board/qmtech/c5soc-kfb-dual-sdram/qts
git clean -f # remove the extra generated .pyc files from the run of the 'cv_bsp_generator'

# Compile/Build Preloaded + Uboot
export PATH=/home/monklp/workspace/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-linux-gnueabihf/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-
cd $UBOOT_TOP_FOLDER
make mrproper
sync
make clean
sync
make socfpga_c5soc_kfb_dual_sdram_defconfig
sync
make -j 8 
sync
# The following ()important) files were generated sucesfully:
#  ...
#  DTC     arch/arm/dts/socfpga_cyclone5_kfb_dual_sdram.dtb 
#  ...
#  OBJCOPY spl/u-boot-spl-nodtb.bin
#  SYM     spl/u-boot-spl.sym
#  CAT     spl/u-boot-spl-dtb.bin
#  COPY    spl/u-boot-spl.bin
#  MKIMAGE spl/u-boot-spl.sfp
#  SOCBOOT u-boot-with-spl.sfp
#  OFCHK   .config


cd $LINUX_TOP_FOLDER
# Note that most Cyclone V SoC DevKits have a 512MB QSPI flash device, while the Linux kernel DTS assumes a 1Gb (128MB) one. 
# If you have the standard 512MB one, change the file linux-socfpga/arch/arm/boot/dts/socfpga_cyclone5_socdk.dts accordingly before building dtbs:
export PATH=/home/monklp/workspace/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-linux-gnueabihf/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-
# Configure and build the Linux binaries - zImage , .dtb and kernel modules
rm -rf modules_install/
sync
make mrproper
sync
make clean
sync
make socfpga_defconfig
sync
make -j 8 zImage Image dtbs modules
sync
make -j 8 modules_install INSTALL_MOD_PATH=modules_install
sync
rm -rf modules_install/lib/modules/*/build
sync
rm -rf modules_install/lib/modules/*/source
sync

# Start preparing/linking the produced binaries
cd $BUILD_ENV_FOLDER
rm -rf linux-bin && mkdir linux-bin
sync
export set LINUX_BIN_DIR=`pwd`/linux-bin
mkdir -p $LINUX_BIN_DIR/a9
cd $LINUX_TOP_FOLDER
ln -s $LINUX_TOP_FOLDER/arch/arm/boot/zImage $LINUX_BIN_DIR/a9/
ln -s $LINUX_TOP_FOLDER/arch/arm/boot/Image $LINUX_BIN_DIR/a9/
ln -s $LINUX_TOP_FOLDER/arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_kfb_dual_sdram.dtb $LINUX_BIN_DIR/a9/
ln -s $LINUX_TOP_FOLDER/modules_install/lib/modules $LINUX_BIN_DIR/a9/
sync

# Prepare the configuration and start building the rootfs (using Yoctoy/poky)
cd $ROOTFS_TOP_FOLDER/cyclone5
source poky/oe-init-build-env ./build
echo 'MACHINE = "cyclone5"' >> conf/local.conf
echo 'BBLAYERS += " ${TOPDIR}/../meta-intel-fpga "' >> conf/bblayers.conf
# Uncomment next line to add more packages to the image
echo 'CORE_IMAGE_EXTRA_INSTALL += "openssh gdbserver"' >> conf/local.conf
bitbake core-image-minimal
ln -s $ROOTFS_TOP_FOLDER/cyclone5/build/tmp/deploy/images/cyclone5/core-image-minimal-cyclone5.tar.gz $LINUX_BIN_DIR/a9/
sync

# Go to the script folder and prepare SD Card image writer script 
cd $BUILD_ENV_FOLDER/scripts 
# wget https://releases.rocketboards.org/2021.04/gsrd/tools/make_sdimage_p3.py
chmod +x make_sdimage_p3.py

# Create sd card top folder:
cd $BUILD_ENV_FOLDER #
sudo rm -rf sd_card && mkdir sd_card && cd sd_card
# Prepare the FAT partition:
mkdir sdfs &&  cd sdfs
cp $LINUX_BIN_DIR/a9/zImage .
sync
cp $LINUX_BIN_DIR/a9/socfpga_cyclone5_kfb_dual_sdram.dtb .
sync
mkdir extlinux
echo "LABEL Linux Default" > extlinux/extlinux.conf
echo "    KERNEL ../zImage" >> extlinux/extlinux.conf
echo "    FDT ../socfpga_cyclone5_kfb_dual_sdram.dtb" >> extlinux/extlinux.conf
echo "    APPEND root=/dev/mmcblk0p2 rw rootwait earlyprintk console=ttyS0,115200n8" >> extlinux/extlinux.conf
# Prepare Rootfs partition:
cd $BUILD_ENV_FOLDER/sd_card
sudo rm -rf rootfs
mkdir rootfs && cd rootfs
sudo tar xf $LINUX_BIN_DIR/a9/core-image-minimal-cyclone5.tar.gz
sync
sudo rm -rf lib/modules/*  # 'lib/modules/*' directory does not exist under rootfs (core-image-minimal-cyclone5.tar.gz)
sudo cp -r $LINUX_BIN_DIR/a9/modules lib/  
# Copy over the U-boot bootable binary file:
cd $BUILD_ENV_FOLDER/sd_card
rm -rf uboot && mkdir uboot  && cd uboot
cp $UBOOT_TOP_FOLDER/u-boot-with-spl.sfp .
sync

# Prepare and create the SD card image (.img) file:
cd $BUILD_ENV_FOLDER/sd_card
sudo python3 $BUILD_ENV_FOLDER/scripts/make_sdimage_p3.py -f \
-P uboot/u-boot-with-spl.sfp,num=3,format=raw,size=10M,type=A2  \
-P sdfs/*,num=1,format=fat32,size=100M \
-P rootfs/*,num=2,format=ext3,size=300M \
-s 512M \
-n sdcard_cv.img

# Write the image file directly to the SD Card:
cd $BUILD_ENV_FOLDER/sd_card
sudo dd if=sdcard_cv.img of=$SDCARD_DEVICE bs=512 conv=sync
sync
sudo umount $SDCARD_DEVICE*
sync
sudo eject $SDCARD_DEVICE
sync



# Put the SD Card in the QMTECH Cyclone V SoC KFB Dual SDRAM board, SD card slot, and power it up. The board will to U-Boot shell:

#U-Boot SPL 2024.07-36775-g7dae1a309ad (Apr 24 2026 - 23:18:52 +0300)
#Trying to boot from MMC1
#
#
#U-Boot 2024.07-36775-g7dae1a309ad (Apr 24 2026 - 23:18:52 +0300)
#
#CPU:   Altera SoCFPGA Platform
#FPGA:  Altera Cyclone V, SE/A6 or SX/C6 or ST/D6, version 0x0
#BOOT:  SD/MMC Internal Transceiver (3.0V)
#DRAM:  1 GiB
#Core:  29 devices, 15 uclasses, devicetree: separate
#MMC:   dwmmc0@ff704000: 0
#Loading Environment from MMC... Reading from MMC(0)... *** Warning - bad CRC, using default environment
#
#In:    serial
#Out:   serial
#Err:   serial
#Model: QMTECH C5SOC KFB Dual SDRAM
#Net:
#Error: ethernet@ff702000 No valid MAC address found.
#No ethernet found.
#
# =>

=> run mmc_boot   # Run/Enter this command mannually to boot to Linux fully (Uboot at this moment, does not automatically boot to Linux, it waits for the user to run the 'mmc_boot' command)

# => run mmc_boot
# switch to partitions #0, OK
# mmc0 is current device
# ** Bad device specification mmc -bootable **
# Scanning mmc :1...
# Found /extlinux/extlinux.conf
# Retrieving file: /extlinux/extlinux.conf
# 1:      Linux Default
# Retrieving file: /extlinux/../zImage
# append: root=/dev/mmcblk0p2 rw rootwait earlyprintk console=ttyS0,115200n8
# Retrieving file: /extlinux/../socfpga_cyclone5_kfb_dual_sdram.dtb
# Kernel image @ 0x1000000 [ 0x000000 - 0x5fc258 ]
# ## Flattened Device Tree blob at 02000000
#    Booting using the fdt blob at 0x2000000
# Working FDT set to 2000000
#    Loading Device Tree to 09ff6000, end 09fff4f3 ... OK
# Working FDT set to 9ff6000
#
# Starting kernel ...
#
# Deasserting all peripheral resets
# [    0.000000] Booting Linux on physical CPU 0x0
# [    0.000000] Linux version 6.6.22-g73daf6f844a2 (monklp@precision) (arm-none-linux-gnueabihf-gcc (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 15.2.1 20251203, GNU ld (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 2.45.1.20251203) #1 SMP Thu Apr 30 00:45:13 EEST 2026
# [    0.000000] CPU: ARMv7 Processor [413fc090] revision 0 (ARMv7), cr=10c5387d
# [    0.000000] CPU: PIPT / VIPT nonaliasing data cache, VIPT aliasing instruction cache
# [    0.000000] OF: fdt: Machine model: QMTECH C5SOC KFB Dual SDRAM
# [    0.000000] Memory policy: Data cache writealloc
# [    0.000000] Zone ranges:
# [    0.000000]   Normal   [mem 0x0000000000000000-0x000000002fffffff]
# [    0.000000]   HighMem  [mem 0x0000000030000000-0x000000003fffffff]
# [    0.000000] Movable zone start for each node
# [    0.000000] Early memory node ranges
# [    0.000000]   node   0: [mem 0x0000000000000000-0x000000003fffffff]
# [    0.000000] Initmem setup node 0 [mem 0x0000000000000000-0x000000003fffffff]
# [    0.000000] percpu: Embedded 15 pages/cpu s31636 r8192 d21612 u61440
# [    0.000000] Kernel command line: root=/dev/mmcblk0p2 rw rootwait earlyprintk console=ttyS0,115200n8
# [    0.000000] Unknown kernel command line parameters "earlyprintk", will be passed to user space.
# [    0.000000] Dentry cache hash table entries: 131072 (order: 7, 524288 bytes, linear)
# [    0.000000] Inode-cache hash table entries: 65536 (order: 6, 262144 bytes, linear)
# [    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 260608
# [    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
# [    0.000000] Memory: 1025020K/1048576K available (9216K kernel code, 848K rwdata, 2180K rodata, 1024K init, 168K bss, 23556K reserved, 0K cma-reserved, 262144K highmem)
# [    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=2, Nodes=1
# [    0.000000] ftrace: allocating 32791 entries in 97 pages
# [    0.000000] ftrace: allocated 97 pages with 3 groups
# [    0.000000] trace event string verifier disabled
# [    0.000000] rcu: Hierarchical RCU implementation.
# [    0.000000] rcu:     RCU event tracing is enabled.
# [    0.000000]  Rude variant of Tasks RCU enabled.
# [    0.000000] rcu: RCU calculated value of scheduler-enlistment delay is 10 jiffies.
# [    0.000000] NR_IRQS: 16, nr_irqs: 16, preallocated irqs: 16
# [    0.000000] L2C-310 erratum 769419 enabled
# [    0.000000] L2C-310 enabling early BRESP for Cortex-A9
# [    0.000000] L2C-310 full line of zeros enabled for Cortex-A9
# [    0.000000] L2C-310 ID prefetch enabled, offset 8 lines
# [    0.000000] L2C-310 dynamic clock gating enabled, standby mode enabled
# [    0.000000] L2C-310 cache controller enabled, 8 ways, 512 kB
# [    0.000000] L2C-310: CACHE_ID 0x410030c9, AUX_CTRL 0x76460001
# [    0.000000] rcu: srcu_init: Setting srcu_struct sizes based on contention.
# [    0.000000] clocksource: timer1: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604467 ns
# [    0.000000] sched_clock: 32 bits at 100MHz, resolution 10ns, wraps every 21474836475ns
# [    0.000014] Switching to timer-based delay loop, resolution 10ns
# [    0.000435] Console: colour dummy device 80x30
# [    0.000478] Calibrating delay loop (skipped), value calculated using timer frequency.. 200.00 BogoMIPS (lpj=1000000)
# [    0.000493] CPU: Testing write buffer coherency: ok
# [    0.000529] CPU0: Spectre v2: using BPIALL workaround
# [    0.000536] pid_max: default: 32768 minimum: 301
# [    0.000686] Mount-cache hash table entries: 2048 (order: 1, 8192 bytes, linear)
# [    0.000703] Mountpoint-cache hash table entries: 2048 (order: 1, 8192 bytes, linear)
# [    0.001473] CPU0: thread -1, cpu 0, socket 0, mpidr 80000000
# [    0.002706] RCU Tasks Rude: Setting shift to 1 and lim to 1 rcu_task_cb_adjust=1.
# [    0.002862] Setting up static identity map for 0x100000 - 0x100060
# [    0.003049] rcu: Hierarchical SRCU implementation.
# [    0.003056] rcu:     Max phase no-delay instances is 1000.
# [    0.003529] smp: Bringing up secondary CPUs ...
# [    0.004349] CPU1: thread -1, cpu 1, socket 0, mpidr 80000001
# [    0.004371] CPU1: Spectre v2: using BPIALL workaround
# [    0.004514] smp: Brought up 1 node, 2 CPUs
# [    0.004526] SMP: Total of 2 processors activated (400.00 BogoMIPS).
# [    0.004535] CPU: All CPU(s) started in SVC mode.
# [    0.005451] devtmpfs: initialized
# [    0.010405] VFP support v0.3: implementor 41 architecture 3 part 30 variant 9 rev 4
# [    0.010631] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
# [    0.010651] futex hash table entries: 512 (order: 3, 32768 bytes, linear)
# [    0.011742] NET: Registered PF_NETLINK/PF_ROUTE protocol family
# [    0.012576] DMA: preallocated 256 KiB pool for atomic coherent allocations
# [    0.014051] hw-breakpoint: found 5 (+1 reserved) breakpoint and 1 watchpoint registers.
# [    0.014064] hw-breakpoint: maximum watchpoint size is 4 bytes.
# [    0.031573] SCSI subsystem initialized
# [    0.031764] usbcore: registered new interface driver usbfs
# [    0.031807] usbcore: registered new interface driver hub
# [    0.031851] usbcore: registered new device driver usb
# [    0.032019] usb_phy_generic soc:usbphy: dummy supplies not allowed for exclusive requests
# [    0.032336] pps_core: LinuxPPS API ver. 1 registered
# [    0.032344] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
# [    0.032370] PTP clock support registered
# [    0.032540] FPGA manager framework
# [    0.033512] vgaarb: loaded
# [    0.033964] clocksource: Switched to clocksource timer1
# [    0.043923] NET: Registered PF_INET protocol family
# [    0.044216] IP idents hash table entries: 16384 (order: 5, 131072 bytes, linear)
# [    0.046080] tcp_listen_portaddr_hash hash table entries: 512 (order: 0, 4096 bytes, linear)
# [    0.046110] Table-perturb hash table entries: 65536 (order: 6, 262144 bytes, linear)
# [    0.046129] TCP established hash table entries: 8192 (order: 3, 32768 bytes, linear)
# [    0.046205] TCP bind hash table entries: 8192 (order: 5, 131072 bytes, linear)
# [    0.046436] TCP: Hash tables configured (established 8192 bind 8192)
# [    0.046555] UDP hash table entries: 512 (order: 2, 16384 bytes, linear)
# [    0.046602] UDP-Lite hash table entries: 512 (order: 2, 16384 bytes, linear)
# [    0.046777] NET: Registered PF_UNIX/PF_LOCAL protocol family
# [    0.047690] RPC: Registered named UNIX socket transport module.
# [    0.047703] RPC: Registered udp transport module.
# [    0.047707] RPC: Registered tcp transport module.
# [    0.047712] RPC: Registered tcp-with-tls transport module.
# [    0.047716] RPC: Registered tcp NFSv4.1 backchannel transport module.
# [    0.047732] PCI: CLS 0 bytes, default 64
# [    0.048627] hw perfevents: enabled with armv7_cortex_a9 PMU driver, 7 counters available
# [    0.049956] workingset: timestamp_bits=30 max_order=18 bucket_order=0
# [    0.050627] NFS: Registering the id_resolver key type
# [    0.050665] Key type id_resolver registered
# [    0.050671] Key type id_legacy registered
# [    0.051049] ntfs: driver 2.1.32 [Flags: R/W].
# [    0.051087] jffs2: version 2.2. (NAND) © 2001-2006 Red Hat, Inc.
# [    0.051569] bounce: pool size: 64 pages
# [    0.051598] io scheduler mq-deadline registered
# [    0.051606] io scheduler kyber registered
# [    0.051631] io scheduler bfq registered
# [    0.057310] Serial: 8250/16550 driver, 2 ports, IRQ sharing disabled
# [    0.058813] printk: console [ttyS0] disabled
# [    0.059174] ffc02000.serial: ttyS0 at MMIO 0xffc02000 (irq = 30, base_baud = 6250000) is a 16550A
# [    0.059223] printk: console [ttyS0] enabled
# [    0.725421] ffc03000.serial: ttyS1 at MMIO 0xffc03000 (irq = 31, base_baud = 6250000) is a 16550A
# [    0.736087] brd: module loaded
# [    0.745101] loop: module loaded
# [    0.750313] CAN device driver interface
# [    0.754535] socfpga-dwmac ff702000.ethernet: IRQ eth_wake_irq not found
# [    0.761137] socfpga-dwmac ff702000.ethernet: IRQ eth_lpi not found
# [    0.767470] socfpga-dwmac ff702000.ethernet: PTP uses main clock
# [    0.773744] socfpga-dwmac ff702000.ethernet: User ID: 0x10, Synopsys ID: 0x37
# [    0.780890] socfpga-dwmac ff702000.ethernet:         DWMAC1000
# [    0.786124] socfpga-dwmac ff702000.ethernet: DMA HW capability register supported
# [    0.793579] socfpga-dwmac ff702000.ethernet: RX Checksum Offload Engine supported
# [    0.801043] socfpga-dwmac ff702000.ethernet: COE Type 2
# [    0.806260] socfpga-dwmac ff702000.ethernet: TX Checksum insertion supported
# [    0.813281] socfpga-dwmac ff702000.ethernet: Enhanced/Alternate descriptors
# [    0.820234] socfpga-dwmac ff702000.ethernet: Enabled extended descriptors
# [    0.827007] socfpga-dwmac ff702000.ethernet: Ring mode enabled
# [    0.832819] socfpga-dwmac ff702000.ethernet: Enable RX Mitigation via HW Watchdog Timer
# [    0.840820] socfpga-dwmac ff702000.ethernet: device MAC address b2:10:a3:c4:39:17
# [    0.857653] Micrel KSZ9031 Gigabit PHY stmmac-0:01: attached PHY driver (mii_bus:phy_addr=stmmac-0:01, irq=POLL)
# [    0.869509] dwc2 ffb40000.usb: supply vusb_d not found, using dummy regulator
# [    0.876803] dwc2 ffb40000.usb: supply vusb_a not found, using dummy regulator
# [    0.884259] dwc2 ffb40000.usb: EPs: 16, dedicated fifos, 8064 entries in SPRAM
# [    0.891678] dwc2 ffb40000.usb: DWC OTG Controller
# [    0.896428] dwc2 ffb40000.usb: new USB bus registered, assigned bus number 1
# [    0.903480] dwc2 ffb40000.usb: irq 33, io mem 0xffb40000
# [    0.909626] hub 1-0:1.0: USB hub found
# [    0.913409] hub 1-0:1.0: 1 port detected
# [    0.918233] usbcore: registered new interface driver usb-storage
# [    0.924470] i2c_dev: i2c /dev entries driver
# [    0.929149] Synopsys Designware Multimedia Card Interface Driver
# [    0.935494] ledtrig-cpu: registered to indicate activity on CPUs
# [    0.935607] dw_mmc ff704000.mmc: IDMAC supports 32-bit address mode.
# [    0.941603] usbcore: registered new interface driver usbhid
# [    0.947885] dw_mmc ff704000.mmc: Using internal DMA controller.
# [    0.953405] usbhid: USB HID core driver
# [    0.953754] fpga_manager fpga0: Altera SOCFPGA FPGA Manager registered
# [    0.959329] dw_mmc ff704000.mmc: Version ID is 240a
# [    0.963830] NET: Registered PF_INET6 protocol family
# [    0.969720] dw_mmc ff704000.mmc: DW MMC controller at irq 34,32 bit host data width,1024 deep fifo
# [    0.975800] Segment Routing with IPv6
# [    0.979673] mmc_host mmc0: card is polling.
# [    0.988504] In-situ OAM (IOAM) with IPv6
# [    1.000253] sit: IPv6, IPv4 and MPLS over IPv4 tunneling driver
# [    1.003992] mmc_host mmc0: Bus speed (slot 0) = 50000000Hz (slot req 400000Hz, actual 396825HZ div = 63)
# [    1.006812] NET: Registered PF_PACKET protocol family
# [    1.020654] NET: Registered PF_KEY protocol family
# [    1.025442] can: controller area network core
# [    1.029828] NET: Registered PF_CAN protocol family
# [    1.034617] can: raw protocol
# [    1.037582] can: broadcast manager protocol
# [    1.041756] can: netlink gateway - max_hops=1
# [    1.046198] 8021q: 802.1Q VLAN Support v1.8
# [    1.050431] Key type dns_resolver registered
# [    1.054849] ThumbEE CPU extension supported.
# [    1.059115] Registering SWP/SWPB emulation handler
# [    1.080600] of-fpga-region soc:base-fpga-region: FPGA Region probed
# [    1.091968] dma-pl330 ffe01000.pdma: Loaded driver for PL330 DMAC-341330
# [    1.098711] dma-pl330 ffe01000.pdma:         DBUFF-512x8bytes Num_Chans-8 Num_Peri-32 Num_Events-8
# [    1.107233] of_cfs_init
# [    1.109760] of_cfs_init: OK
# [    1.112822] clk: Disabling unused clocks
# [    1.116903] mmc_host mmc0: Bus speed (slot 0) = 50000000Hz (slot req 50000000Hz, actual 50000000HZ div = 0)
# [    1.126736] dw-apb-uart ffc02000.serial: forbid DMA for kernel console
# [    1.127187] mmc0: new high speed SDHC card at address aaaa
# [    1.138930] Waiting for root device /dev/mmcblk0p2...
# [    1.139503] mmcblk0: mmc0:aaaa SH32G 29.7 GiB
# [    1.150880]  mmcblk0: p1 p2 p3
# [    1.175090] EXT4-fs (mmcblk0p2): mounting ext3 file system using the ext4 subsystem
# [    1.199088] EXT4-fs (mmcblk0p2): mounted filesystem ba67ed0b-d6d9-4979-8685-10d363a8d4fc r/w with ordered data mode. Quota mode: disabled.
# [    1.211568] VFS: Mounted root (ext3 filesystem) on device 179:2.
# [    1.224864] devtmpfs: mounted
# [    1.232010] Freeing unused kernel image (initmem) memory: 1024K
# [    1.238297] Run /sbin/init as init process
# [    1.293996] usb 1-1: new high-speed USB device number 2 using dwc2
# INIT: version 3.01 booting
# Starting udev
# [    1.574963] hub 1-1:1.0: USB hub found
# [    1.579551] hub 1-1:1.0: 4 ports detected
# [    1.664545] udevd[80]: starting version 3.2.10
# [    4.223967] random: crng init done
# [    4.256225] udevd[81]: starting eudev-3.2.10
# [    4.674072] EXT4-fs (mmcblk0p2): re-mounted ba67ed0b-d6d9-4979-8685-10d363a8d4fc r/w. Quota mode: disabled.
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# Fri Mar  9 12:51:30 UTC 2018
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# INIT: Entering runlevel: 5
# Configuring network interfaces... [    5.199082] socfpga-dwmac ff702000.ethernet eth0: Register MEM_TYPE_PAGE_POOL RxQ-0
# [    5.291687] socfpga-dwmac ff702000.ethernet eth0: PHY [stmmac-0:01] driver [Micrel KSZ9031 Gigabit PHY] (irq=POLL)
# [    5.312051] dwmac1000: Master AXI performs any burst length
# [    5.317629] socfpga-dwmac ff702000.ethernet eth0: No Safety Features support found
# [    5.325196] socfpga-dwmac ff702000.ethernet eth0: IEEE 1588-2008 Advanced Timestamp supported
# [    5.333954] socfpga-dwmac ff702000.ethernet eth0: registered PTP clock
# [    5.342881] socfpga-dwmac ff702000.ethernet eth0: configuring for phy/rgmii link mode
# udhcpc: started, v1.35.0
# udhcpc: broadcasting discover
# udhcpc: broadcasting discover
# udhcpc: broadcasting discover
# udhcpc: no lease, forking to background
# done.
# Starting OpenBSD Secure Shell server: sshd
# done.
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# Starting syslogd/klogd: done
#
# Poky (Yocto Project Reference Distro) 4.0.35 cyclone5 /dev/ttyS0
#
# cyclone5 login:             #

cyclone5 login: root  # Just enter 'root' that is the username, there is no password, and you will be logged in to the Linux shell prompt as $root user.
 
# cyclone5 login: root
# root@cyclone5:~# ls -alh
# drwx------    2 root     root        4.0K Mar  9 12:35 .
# drwxr-xr-x    3 root     root        4.0K Mar  9 12:34 ..
# -rw-------    1 root     root         106 Mar  9 12:55 .ash_history
# root@cyclone5:~# uname -a
# Linux cyclone5 6.6.22-g73daf6f844a2 #1 SMP Thu Apr 30 00:45:13 EEST 2026 armv7l GNU/Linux
# root@cyclone5:~#



# Here is a code snippet of commands you can run to create the partitions, set the partition type, and format the partitions.
export SDCARD_DEVICE=/dev/sdb
sudo umount $SDCARD_DEV*
sync
sudo wipefs -a $SDCARD_DEV        # wipes partition table and filesystem signatures
sync
sudo dd if=/dev/zero of=$SDCARD_DEV bs=1M count=10 conv=sync  # zeros the first 10MB
sync

# ...
# ...
# ...

# Unmount (all) partitions and eject the SD Card 
sudo umount $SDCARD_DEV*
sync
sudo eject $SDCARD_DEV
sync


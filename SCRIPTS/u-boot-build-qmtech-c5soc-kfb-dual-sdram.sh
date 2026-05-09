# ==========================================================
# Note: If you decide to copy and paste commands from this script to the terminal directly, then open a terminale in the "/qmtech-c5soc-kfb-linux-build-env/SCRIPTS" folder and then copy and paste the entire section of statements of 0. and 1.

# 0. Prepare build toolchain:
export PATH=/home/monklp/workspace/arm-gnu-toolchain-15.2.rel1-x86_64-arm-none-linux-gnueabihf/bin:$PATH
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-

# 1. Set the Project's 'Top' directory - this is the folder that contains the GSRD, Software, Tools, etc.
export BUILD_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) # The script must be placed at the top/overhead place
cd $BUILD_SCRIPT_DIR/..
export BUILD_TOP_FOLDER=`pwd`

export GHRD_SRC_DIR="$BUILD_TOP_FOLDER/SOURCES/qmtech-c5soc-kfb-dual-sdram-ghrd"  # 'main' branch (take the latest commit)
export UBOOT_SRC_DIR="$BUILD_TOP_FOLDER/SOURCES/u-boot-socfpga"                   # 'qmtech_c5soc_kfb_dual_sdram_v2024.07' branch (take the latest commit)
export LINUX_SRC_DIR="$BUILD_TOP_FOLDER/SOURCES/linux-socfpga"                    # 'socfpga-6.6.22-lts' branch  (take the latest commit)
export ROOTFS_SRC_DIR="$BUILD_TOP_FOLDER/SOURCES/rootfs-socfpga"                  # 'main' branch (take the latest commit)

export UBOOT_BUILD_DIR="$BUILD_TOP_FOLDER/BUILD/u-boot-socfpga"
export LINUX_BUILD_DIR="$BUILD_TOP_FOLDER/BUILD/linux-socfpga"
export ROOTFS_BUILD_DIR="$BUILD_TOP_FOLDER/BUILD/rootfs-socfpga"

export SDCARD_TOP_FOLDER="$BUILD_TOP_FOLDER/SD_CARD"

# This must be adjusted/configured to reference the actual SD Card Device:
export SDCARD_DEV=/dev/sdb



# 2. Get the sources from the handoff folder, format them appropriately, and copy them into the U-Boot source code:
cd $UBOOT_SRC_DIR/arch/arm/mach-socfpga/cv_bsp_generator
python2.7 cv_bsp_generator.py -i $GHRD_SRC_DIR/quartus/hps_isw_handoff/soc_system_hps_0 -o ../../../../board/qmtech/c5soc-kfb-dual-sdram/qts
git clean -f # remove the extra generated .pyc files from the run of the 'cv_bsp_generator'

# Compile/Build Preloaded + Uboot
cd $UBOOT_SRC_DIR
rm -rf $UBOOT_BUILD_DIR
mkdir $UBOOT_BUILD_DIR -p
make mrproper
sync
make clean
sync
make O=$UBOOT_BUILD_DIR socfpga_c5soc_kfb_dual_sdram_defconfig
sync
make O=$UBOOT_BUILD_DIR -j 8 
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


cd $LINUX_SRC_DIR
# Note that most Cyclone V SoC DevKits have a 512MB QSPI flash device, while the Linux kernel DTS assumes a 1Gb (128MB) one. 
# If you have the standard 512MB one, change the file linux-socfpga/arch/arm/boot/dts/socfpga_cyclone5_socdk.dts accordingly before building dtbs:
# Configure and build the Linux binaries - zImage , .dtb and kernel modules
rm -rf $LINUX_SRC_DIR/modules_install/
rm -rf $LINUX_BUILD_DIR
sync
make mrproper
sync
make clean
sync
make O=$LINUX_BUILD_DIR socfpga_defconfig
sync
make O=$LINUX_BUILD_DIR -j 8 zImage Image dtbs modules
sync
make O=$LINUX_BUILD_DIR -j 8 modules_install INSTALL_MOD_PATH=modules_install
sync
rm -rf $LINUX_BUILD_DIR/modules_install/lib/modules/*/build
sync
rm -rf $LINUX_BUILD_DIR/modules_install/lib/modules/*/source
sync

# Prepare the configuration and start building the rootfs (using Yoctoy/poky)
cd $ROOTFS_SRC_DIR/qmtech-c5soc-kfb
source poky/oe-init-build-env ./build
cd $ROOTFS_SRC_DIR/qmtech-c5soc-kfb/build
echo 'MACHINE = "cyclone5"' >> conf/local.conf
echo 'hostname:pn-base-files = "qmtech-c5soc-kfb"' >> conf/local.conf  # Yocto 3.4+ (kirkstone and above) syntax
echo 'BBLAYERS += " ${TOPDIR}/../meta-intel-fpga "' >> conf/bblayers.conf
# Uncomment next line to add more packages to the image
echo 'CORE_IMAGE_EXTRA_INSTALL += "openssh gdbserver"' >> conf/local.conf
# Redirect ALL build output to a separate directory
echo 'TMPDIR = "${ROOTFS_BUILD_DIR}"' >> conf/local.conf
cd ${ROOTFS_BUILD_DIR}/..
rm -rf ${ROOTFS_BUILD_DIR}
sync
bitbake base-files
sync
bitbake core-image-base
sync

# Start preparing/linking the produced binaries
cd $SDCARD_TOP_FOLDER
rm -rf linux-bin && mkdir linux-bin
sync
export set LINUX_BIN_DIR=`pwd`/linux-bin
mkdir -p $LINUX_BIN_DIR/a9
cd $LINUX_BUILD_DIR
ln -s $LINUX_BUILD_DIR/arch/arm/boot/zImage $LINUX_BIN_DIR/a9/
ln -s $LINUX_BUILD_DIR/arch/arm/boot/Image $LINUX_BIN_DIR/a9/
ln -s $LINUX_BUILD_DIR/arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_kfb_dual_sdram.dtb $LINUX_BIN_DIR/a9/
ln -s $LINUX_BUILD_DIR/modules_install/lib/modules $LINUX_BIN_DIR/a9/
ln -s $ROOTFS_BUILD_DIR/qmtech-c5soc-kfb/build/tmp/deploy/images/cyclone5/core-image-base-cyclone5.tar.gz $LINUX_BIN_DIR/a9/
sync

# Go to the script folder and prepare SD Card image writer script 
cd $BUILD_SCRIPT_DIR
# wget https://releases.rocketboards.org/2021.04/gsrd/tools/make_sdimage_p3.py
chmod +x make_sdimage_p3.py

# Create sd card top folder:
cd $SDCARD_TOP_FOLDER #
# Prepare the FAT partition:
sudo rm -rf sdfs && mkdir sdfs && cd sdfs
cp $LINUX_BIN_DIR/a9/zImage .
sync
cp $LINUX_BIN_DIR/a9/socfpga_cyclone5_kfb_dual_sdram.dtb .
sync
mkdir extlinux
echo "LABEL Linux Default" > extlinux/extlinux.conf
echo "    KERNEL ../zImage" >> extlinux/extlinux.conf
echo "    FDT ../socfpga_cyclone5_kfb_dual_sdram.dtb" >> extlinux/extlinux.conf
echo "    APPEND root=/dev/mmcblk0p2 rw rootwait earlycon console=ttyS0,115200n8" >> extlinux/extlinux.conf
# Copy the generated FPGA configuration (.rbf) file from Quartus, to the sdfs dir for SD Card. Then rename it to common used name (standard) - 'soc_system.rbf'
cp $GHRD_SRC_DIR/quartus/output_files/qmtech_c5soc_kfb_dual_sdram_ghrd.rbf .
mv qmtech_c5soc_kfb_dual_sdram_ghrd.rbf soc_system.rbf

# Prepare Rootfs partition:
cd $SDCARD_TOP_FOLDER #
sudo rm -rf rootfs
mkdir rootfs && cd rootfs
sudo tar xf $LINUX_BIN_DIR/a9/core-image-base-cyclone5.tar.gz
sync
sudo rm -rf lib/modules/* 
sync
sudo cp -r $LINUX_BIN_DIR/a9/modules lib/modules  
sync
# Copy over the U-boot bootable binary file:
cd $SDCARD_TOP_FOLDER #
rm -rf uboot && mkdir uboot && cd uboot
cp $UBOOT_BUILD_DIR/u-boot-with-spl.sfp .
sync

# Prepare and create the SD card image (.img) file:
cd $SDCARD_TOP_FOLDER #
sudo python3 $BUILD_SCRIPT_DIR/make_sdimage_p3.py -f \
-P uboot/u-boot-with-spl.sfp,num=3,format=raw,size=10M,type=A2  \
-P sdfs/*,num=1,format=fat32,size=100M \
-P rootfs/*,num=2,format=ext3,size=300M \
-s 512M \
-n sdcard_qmtech_c5soc_kfb.img
sync

# Write the image file directly to the SD Card:
cd $SDCARD_TOP_FOLDER #
sudo dd if=sdcard_qmtech_c5soc_kfb.img of=$SDCARD_DEV bs=512 conv=sync status=progress
sync
sudo umount $SDCARD_DEV*
sync
sudo eject $SDCARD_DEV
sync

# Break the SD Card image file into 100MB chunks and zip it for easier sharing:
rm -rf sdcard_qmtech_c5soc_kfb.img.zip
zip -s 100m sdcard_qmtech_c5soc_kfb.img.zip sdcard_qmtech_c5soc_kfb.img


# ====== Put the SD Card in the QMTECH Cyclone V SoC KFB Dual SDRAM board, SD card slot, and power it up. The board will to Linux login shell: ===

# U-Boot SPL 2024.07-36777-gac012d089de-dirty (May 03 2026 - 01:28:09 +0300)
# Trying to boot from MMC1
#
# U-Boot 2024.07-36777-gac012d089de-dirty (May 03 2026 - 01:28:09 +0300)
#
# CPU:   Altera SoCFPGA Platform
# FPGA:  Altera Cyclone V, SE/A6 or SX/C6 or ST/D6, version 0x0
# BOOT:  SD/MMC Internal Transceiver (3.0V)
# DRAM:  1 GiB
# Core:  29 devices, 15 uclasses, devicetree: separate
# MMC:   dwmmc0@ff704000: 0
# Loading Environment from MMC... Reading from MMC(0)... *** Warning - bad CRC, using default environment
#
# In:    serial
# Out:   serial
# Err:   serial
# Model: QMTECH C5SOC KFB Dual SDRAM
# Net:
# Error: ethernet@ff702000 No valid MAC address found.
# No ethernet found.
#
# Hit any key to stop autoboot:  0
# Retrieving file: /extlinux/extlinux.conf
# 1:      Linux Default
# Retrieving file: /extlinux/../zImage
# append: root=/dev/mmcblk0p2 rw rootwait earlycon console=ttyS0,115200n8
# Retrieving file: /extlinux/../socfpga_cyclone5_kfb_dual_sdram.dtb
# Kernel image @ 0x1000000 [ 0x000000 - 0x5fc250 ]
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
# [    0.000000] Linux version 6.6.22-g73daf6f844a2 (monklp@precision) (arm-none-linux-gnueabihf-gcc (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 15.2.1 20251203, GNU ld (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 2.45.1.20251203) #1 SMP Mon May  4 23:40:25 EEST 2026
# [    0.000000] CPU: ARMv7 Processor [413fc090] revision 0 (ARMv7), cr=10c5387d
# [    0.000000] CPU: PIPT / VIPT nonaliasing data cache, VIPT aliasing instruction cache
# [    0.000000] OF: fdt: Machine model: QMTECH C5SOC KFB Dual SDRAM
# [    0.000000] earlycon: uart0 at MMIO32 0xffc02000 (options '115200n8')
# [    0.000000] printk: bootconsole [uart0] enabled
# [    0.000000] Memory policy: Data cache writealloc
# [    0.000000] Zone ranges:
# [    0.000000]   Normal   [mem 0x0000000000000000-0x000000002fffffff]
# [    0.000000]   HighMem  [mem 0x0000000030000000-0x000000003fffffff]
# [    0.000000] Movable zone start for each node
# [    0.000000] Early memory node ranges
# [    0.000000]   node   0: [mem 0x0000000000000000-0x000000003fffffff]
# [    0.000000] Initmem setup node 0 [mem 0x0000000000000000-0x000000003fffffff]
# [    0.000000] percpu: Embedded 15 pages/cpu s31636 r8192 d21612 u61440
# [    0.000000] Kernel command line: root=/dev/mmcblk0p2 rw rootwait earlycon console=ttyS0,115200n8
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
# [    0.007891] Switching to timer-based delay loop, resolution 10ns
# [    0.014317] Console: colour dummy device 80x30
# [    0.018783] Calibrating delay loop (skipped), value calculated using timer frequency.. 200.00 BogoMIPS (lpj=1000000)
# [    0.029280] CPU: Testing write buffer coherency: ok
# [    0.034197] CPU0: Spectre v2: using BPIALL workaround
# [    0.039239] pid_max: default: 32768 minimum: 301
# [    0.043997] Mount-cache hash table entries: 2048 (order: 1, 8192 bytes, linear)
# [    0.051300] Mountpoint-cache hash table entries: 2048 (order: 1, 8192 bytes, linear)
# [    0.059791] CPU0: thread -1, cpu 0, socket 0, mpidr 80000000
# [    0.066682] RCU Tasks Rude: Setting shift to 1 and lim to 1 rcu_task_cb_adjust=1.
# [    0.074341] Setting up static identity map for 0x100000 - 0x100060
# [    0.080712] rcu: Hierarchical SRCU implementation.
# [    0.085487] rcu:     Max phase no-delay instances is 1000.
# [    0.091210] smp: Bringing up secondary CPUs ...
# [    0.096540] CPU1: thread -1, cpu 1, socket 0, mpidr 80000001
# [    0.096561] CPU1: Spectre v2: using BPIALL workaround
# [    0.107366] smp: Brought up 1 node, 2 CPUs
# [    0.111489] SMP: Total of 2 processors activated (400.00 BogoMIPS).
# [    0.117734] CPU: All CPU(s) started in SVC mode.
# [    0.123277] devtmpfs: initialized
# [    0.131475] VFP support v0.3: implementor 41 architecture 3 part 30 variant 9 rev 4
# [    0.139329] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 19112604462750000 ns
# [    0.149199] futex hash table entries: 512 (order: 3, 32768 bytes, linear)
# [    0.157147] NET: Registered PF_NETLINK/PF_ROUTE protocol family
# [    0.163903] DMA: preallocated 256 KiB pool for atomic coherent allocations
# [    0.171864] hw-breakpoint: found 5 (+1 reserved) breakpoint and 1 watchpoint registers.
# [    0.179842] hw-breakpoint: maximum watchpoint size is 4 bytes.
# [    0.202701] SCSI subsystem initialized
# [    0.206658] usbcore: registered new interface driver usbfs
# [    0.212208] usbcore: registered new interface driver hub
# [    0.217541] usbcore: registered new device driver usb
# [    0.222777] usb_phy_generic soc:usbphy: dummy supplies not allowed for exclusive requests
# [    0.231267] pps_core: LinuxPPS API ver. 1 registered
# [    0.236223] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti <giometti@linux.it>
# [    0.245350] PTP clock support registered
# [    0.249425] FPGA manager framework
# [    0.253843] vgaarb: loaded
# [    0.259418] clocksource: Switched to clocksource timer1
# [    0.274628] NET: Registered PF_INET protocol family
# [    0.279754] IP idents hash table entries: 16384 (order: 5, 131072 bytes, linear)
# [    0.288956] tcp_listen_portaddr_hash hash table entries: 512 (order: 0, 4096 bytes, linear)
# [    0.297358] Table-perturb hash table entries: 65536 (order: 6, 262144 bytes, linear)
# [    0.305112] TCP established hash table entries: 8192 (order: 3, 32768 bytes, linear)
# [    0.312953] TCP bind hash table entries: 8192 (order: 5, 131072 bytes, linear)
# [    0.320384] TCP: Hash tables configured (established 8192 bind 8192)
# [    0.326866] UDP hash table entries: 512 (order: 2, 16384 bytes, linear)
# [    0.333537] UDP-Lite hash table entries: 512 (order: 2, 16384 bytes, linear)
# [    0.340758] NET: Registered PF_UNIX/PF_LOCAL protocol family
# [    0.353335] RPC: Registered named UNIX socket transport module.
# [    0.359240] RPC: Registered udp transport module.
# [    0.363950] RPC: Registered tcp transport module.
# [    0.368636] RPC: Registered tcp-with-tls transport module.
# [    0.374114] RPC: Registered tcp NFSv4.1 backchannel transport module.
# [    0.380556] PCI: CLS 0 bytes, default 64
# [    0.393186] hw perfevents: enabled with armv7_cortex_a9 PMU driver, 7 counters available
# [    0.402573] workingset: timestamp_bits=30 max_order=18 bucket_order=0
# [    0.409707] NFS: Registering the id_resolver key type
# [    0.414802] Key type id_resolver registered
# [    0.418971] Key type id_legacy registered
# [    0.423408] ntfs: driver 2.1.32 [Flags: R/W].
# [    0.427795] jffs2: version 2.2. (NAND) © 2001-2006 Red Hat, Inc.
# [    0.434391] bounce: pool size: 64 pages
# [    0.438241] io scheduler mq-deadline registered
# [    0.442797] io scheduler kyber registered
# [    0.446816] io scheduler bfq registered
# [    0.466936] Serial: 8250/16550 driver, 2 ports, IRQ sharing disabled
# [    0.474830] printk: console [ttyS0] disabled
# [    0.479509] ffc02000.serial: ttyS0 at MMIO 0xffc02000 (irq = 30, base_baud = 6250000) is a 16550A
# [    0.488390] printk: console [ttyS0] enabled
# [    0.488390] printk: console [ttyS0] enabled
# [    0.496762] printk: bootconsole [uart0] disabled
# [    0.496762] printk: bootconsole [uart0] disabled
# [    0.507217] ffc03000.serial: ttyS1 at MMIO 0xffc03000 (irq = 31, base_baud = 6250000) is a 16550A
# [    0.517810] brd: module loaded
# [    0.526766] loop: module loaded
# [    0.532066] CAN device driver interface
# [    0.536226] socfpga-dwmac ff702000.ethernet: IRQ eth_wake_irq not found
# [    0.542882] socfpga-dwmac ff702000.ethernet: IRQ eth_lpi not found
# [    0.549179] socfpga-dwmac ff702000.ethernet: PTP uses main clock
# [    0.555481] socfpga-dwmac ff702000.ethernet: User ID: 0x10, Synopsys ID: 0x37
# [    0.562640] socfpga-dwmac ff702000.ethernet:         DWMAC1000
# [    0.567850] socfpga-dwmac ff702000.ethernet: DMA HW capability register supported
# [    0.575324] socfpga-dwmac ff702000.ethernet: RX Checksum Offload Engine supported
# [    0.582801] socfpga-dwmac ff702000.ethernet: COE Type 2
# [    0.588009] socfpga-dwmac ff702000.ethernet: TX Checksum insertion supported
# [    0.595044] socfpga-dwmac ff702000.ethernet: Enhanced/Alternate descriptors
# [    0.601991] socfpga-dwmac ff702000.ethernet: Enabled extended descriptors
# [    0.608754] socfpga-dwmac ff702000.ethernet: Ring mode enabled
# [    0.614581] socfpga-dwmac ff702000.ethernet: Enable RX Mitigation via HW Watchdog Timer
# [    0.622588] socfpga-dwmac ff702000.ethernet: device MAC address 2a:eb:cd:cc:ef:e0
# [    0.639464] Micrel KSZ9031 Gigabit PHY stmmac-0:01: attached PHY driver (mii_bus:phy_addr=stmmac-0:01, irq=POLL)
# [    0.651318] dwc2 ffb40000.usb: supply vusb_d not found, using dummy regulator
# [    0.658584] dwc2 ffb40000.usb: supply vusb_a not found, using dummy regulator
# [    0.666211] dwc2 ffb40000.usb: EPs: 16, dedicated fifos, 8064 entries in SPRAM
# [    0.673664] dwc2 ffb40000.usb: DWC OTG Controller
# [    0.678402] dwc2 ffb40000.usb: new USB bus registered, assigned bus number 1
# [    0.685485] dwc2 ffb40000.usb: irq 33, io mem 0xffb40000
# [    0.691679] hub 1-0:1.0: USB hub found
# [    0.695465] hub 1-0:1.0: 1 port detected
# [    0.700330] usbcore: registered new interface driver usb-storage
# [    0.706552] i2c_dev: i2c /dev entries driver
# [    0.711286] Synopsys Designware Multimedia Card Interface Driver
# [    0.717742] dw_mmc ff704000.mmc: IDMAC supports 32-bit address mode.
# [    0.724156] dw_mmc ff704000.mmc: Using internal DMA controller.
# [    0.730090] dw_mmc ff704000.mmc: Version ID is 240a
# [    0.734995] dw_mmc ff704000.mmc: DW MMC controller at irq 34,32 bit host data width,1024 deep fifo
# [    0.744132] mmc_host mmc0: card is polling.
# [    0.748826] ledtrig-cpu: registered to indicate activity on CPUs
# [    0.754976] usbcore: registered new interface driver usbhid
# [    0.760560] usbhid: USB HID core driver
# [    0.764751] fpga_manager fpga0: Altera SOCFPGA FPGA Manager registered
# [    0.771969] NET: Registered PF_INET6 protocol family
# [    0.777327] mmc_host mmc0: Bus speed (slot 0) = 50000000Hz (slot req 400000Hz, actual 396825HZ div = 63)
# [    0.787643] Segment Routing with IPv6
# [    0.791396] In-situ OAM (IOAM) with IPv6
# [    0.795398] sit: IPv6, IPv4 and MPLS over IPv4 tunneling driver
# [    0.801979] NET: Registered PF_PACKET protocol family
# [    0.807031] NET: Registered PF_KEY protocol family
# [    0.811842] can: controller area network core
# [    0.816223] NET: Registered PF_CAN protocol family
# [    0.821019] can: raw protocol
# [    0.823983] can: broadcast manager protocol
# [    0.828158] can: netlink gateway - max_hops=1
# [    0.832600] 8021q: 802.1Q VLAN Support v1.8
# [    0.836841] Key type dns_resolver registered
# [    0.841271] ThumbEE CPU extension supported.
# [    0.845536] Registering SWP/SWPB emulation handler
# [    0.866875] of-fpga-region soc:base-fpga-region: FPGA Region probed
# [    0.878387] dma-pl330 ffe01000.pdma: Loaded driver for PL330 DMAC-341330
# [    0.885135] dma-pl330 ffe01000.pdma:         DBUFF-512x8bytes Num_Chans-8 Num_Peri-32 Num_Events-8
# [    0.893852] of_cfs_init
# [    0.896404] of_cfs_init: OK
# [    0.901504] clk: Disabling unused clocks
# [    0.905710] dw-apb-uart ffc02000.serial: forbid DMA for kernel console
# [    0.912572] Waiting for root device /dev/mmcblk0p2...
# [    0.976082] mmc_host mmc0: Bus speed (slot 0) = 50000000Hz (slot req 50000000Hz, actual 50000000HZ div = 0)
# [    0.986301] mmc0: new high speed SDHC card at address aaaa
# [    0.992476] mmcblk0: mmc0:aaaa SH32G 29.7 GiB
# [    0.999118]  mmcblk0: p1 p2 p3
# [    1.030521] EXT4-fs (mmcblk0p2): mounting ext3 file system using the ext4 subsystem
# [    1.119459] usb 1-1: new high-speed USB device number 2 using dwc2
# [    1.149817] EXT4-fs (mmcblk0p2): recovery complete
# [    1.157695] EXT4-fs (mmcblk0p2): mounted filesystem fb14d850-047c-4bc6-8ed3-4ca37b98f1a9 r/w with ordered data mode. Quota mode: disabled.
# [    1.170167] VFS: Mounted root (ext3 filesystem) on device 179:2.
# [    1.176825] devtmpfs: mounted
# [    1.184009] Freeing unused kernel image (initmem) memory: 1024K
# [    1.190351] Run /sbin/init as init process
# INIT: version 3.01 booting
# [    1.370244] hub 1-1:1.0: USB hub found
# [    1.375142] hub 1-1:1.0: 4 ports detected
# Starting udev
# [    1.625989] udevd[81]: starting version 3.2.10
# [    5.849427] random: crng init done
# [    5.882091] udevd[82]: starting eudev-3.2.10
# [    6.329647] EXT4-fs (mmcblk0p2): re-mounted fb14d850-047c-4bc6-8ed3-4ca37b98f1a9 r/w. Quota mode: disabled.
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# Fri Mar  9 12:37:29 UTC 2018
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# INIT: Entering runlevel: 5
# Configuring network interfaces... [    6.876882] socfpga-dwmac ff702000.ethernet eth0: Register MEM_TYPE_PAGE_POOL RxQ-0
# [    6.967168] socfpga-dwmac ff702000.ethernet eth0: PHY [stmmac-0:01] driver [Micrel KSZ9031 Gigabit PHY] (irq=POLL)
# [    6.987538] dwmac1000: Master AXI performs any burst length
# [    6.993119] socfpga-dwmac ff702000.ethernet eth0: No Safety Features support found
# [    7.000701] socfpga-dwmac ff702000.ethernet eth0: IEEE 1588-2008 Advanced Timestamp supported
# [    7.009479] socfpga-dwmac ff702000.ethernet eth0: registered PTP clock
# [    7.019068] socfpga-dwmac ff702000.ethernet eth0: configuring for phy/rgmii link mode
# udhcpc: started, v1.35.0
# udhcpc: broadcasting discover
# udhcpc: broadcasting discover
# udhcpc: broadcasting discover
# udhcpc: no lease, forking to background
# done.
# Starting system message bus: dbus.
# Starting OpenBSD Secure Shell server: sshd
# done.
# Starting rpcbind daemon...done.
# hwclock: can't open '/dev/misc/rtc': No such file or directory
# Starting syslogd/klogd: done
#  * Starting Avahi mDNS/DNS-SD Daemon: avahi-daemon
#    ...done.
#
# Poky (Yocto Project Reference Distro) 4.0.35 qmtech-c5soc-kfb /dev/ttyS0
#
# qmtech-c5soc-kfb login: root
# root@qmtech-c5soc-kfb:~# ls -alh
# drwx------    2 root     root        4.0K Mar  9 12:35 .
# drwxr-xr-x    3 root     root        4.0K Mar  9 12:34 ..
# -rw-------    1 root     root          61 Mar  9 12:37 .ash_history
# root@qmtech-c5soc-kfb:~# uname -a
# Linux qmtech-c5soc-kfb 6.6.22-g73daf6f844a2 #1 SMP Mon May  4 23:40:25 EEST 2026 armv7l GNU/Linux
# root@qmtech-c5soc-kfb:~# pwd
# /home/root
# root@qmtech-c5soc-kfb:~#


# Uboot stuff: 
# u-boot.txt
fatls mmc 0:1
load mmc 0:1 ${loadaddr} soc_system.rbf;
fpga load 0 ${loadaddr} $filesize;

#
CONFIG_BOOTCOMMAND="load mmc 0:1 ${loadaddr} soc_system.rbf && fpga load 0 ${loadaddr} $filesize; sysboot mmc 0:1 any ${scriptaddr} /extlinux/extlinux.conf"





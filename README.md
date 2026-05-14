# qmtech-c5soc-kfb-linux-build-env

This is just an environment comprising of scripts, recipes, directories, source files, etc., to build the entire Linux image (U-Boot + Linux binaries + SD Card image) for the QMTECH Cyclone V SoC KFB with Dual SDRAM. The steps on how to build the whole set of files/folders/etc. and finally, the .img file to write to an SD Card containing the whole Linux image + FPGA configuration, is described in the 'u-boot-build-qmtech-c5soc-kfb-dual-sdram.sh' file in the 'SCRIPTS' folder. 

Note: the .sh (bash script) file is not a script to be run directly/fully; It is to be read and copied (use portions of it) manually, and is just to provide general information and instructions on how to achieve the result (.img file) by following a step process. 

Note: The Quartus project (in 'SOURCES/qmtech-c5soc-kfb-dual-sdram-ghrd') is set to produce/generate uncompressed bit stream .sof and .rbf files, with Configuration Mode Fast Passive Parallel x 16. Thus, MSEL DIP SW [4:0] must be set to '00000' (All must be ON).

## UART Shell Console

To access the UART shell console on the QMTECH Cyclone V SoC KFB board:

### Hardware Setup
- Connect a USB-to-UART adapter to the UART pins on the board
- Common pins: TX, RX, and GND
- Ensure proper voltage levels (typically 3.3V for this board)
- Note that MSEL DIP SW [4:0] = '00000' (All must be set to 'ON').

### Software Configuration
```bash
# On Linux/Mac, use minicom, screen, or picocom
minicom -D /dev/ttyUSBx -b 115200

# Or with screen
screen /dev/ttyUSBx 115200

# Or with picocom
picocom -b 115200 /dev/ttyUSBx
```
Where 'x' is the port number of your serial connection

### Baud Rate
- **115200 bps** (8 data bits, 1 stop bit, no parity)

### Example Boot Output

```
U-Boot SPL 2024.07-36777-gac012d089de-dirty (May 03 2026 - 01:28:09 +0300)
Trying to boot from MMC1


U-Boot 2024.07-36777-gac012d089de-dirty (May 03 2026 - 01:28:09 +0300)

CPU:   Altera SoCFPGA Platform
FPGA:  Altera Cyclone V, SE/A6 or SX/C6 or ST/D6, version 0x0
BOOT:  SD/MMC Internal Transceiver (3.0V)
DRAM:  1 GiB
Core:  29 devices, 15 uclasses, devicetree: separate
MMC:   dwmmc0@ff704000: 0
Loading Environment from MMC... Reading from MMC(0)... *** Warning - bad CRC, using default environment

In:    serial
Out:   serial
Err:   serial
Model: QMTECH C5SOC KFB Dual SDRAM
Net:
Error: ethernet@ff702000 No valid MAC address found.
No ethernet found.

Hit any key to stop autoboot:  0
Retrieving file: /extlinux/extlinux.conf
1:      Linux Default
Retrieving file: /extlinux/../zImage
append: root=/dev/mmcblk0p2 rw rootwait earlycon console=ttyS0,115200n8
Retrieving file: /extlinux/../socfpga_cyclone5_kfb_dual_sdram.dtb
Kernel image @ 0x1000000 [ 0x000000 - 0x5fc250 ]
## Flattened Device Tree blob at 02000000
   Booting using the fdt blob at 0x2000000
Working FDT set to 2000000
   Loading Device Tree to 09ff6000, end 09fff4f3 ... OK
Working FDT set to 9ff6000

Starting kernel ...

Deasserting all peripheral resets
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 6.6.22-g73daf6f844a2 (monklp@precision) (arm-none-linux-gnueabihf-gcc (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 15.2.1 20251203, GNU ld (Arm GNU Toolchain 15.2.Rel1 (Build arm-15.86)) 2.45.1.20251203) #1 SMP Mon May  4 23:40:25 EEST 2026
...
Poky (Yocto Project Reference Distro) 4.0.35 qmtech-c5soc-kfb /dev/ttyS0

qmtech-c5soc-kfb login: root
root@qmtech-c5soc-kfb:~# ls -alh
drwx------    2 root     root        4.0K Mar  9 12:35 .
drwxr-xr-x    3 root     root        4.0K Mar  9 12:34 ..
-rw-------    1 root     root          61 Mar  9 12:37 .ash_history
root@qmtech-c5soc-kfb:~# uname -a
Linux qmtech-c5soc-kfb 6.6.22-g73daf6f844a2 #1 SMP Mon May  4 23:40:25 EEST 2026 armv7l GNU/Linux
root@qmtech-c5soc-kfb:~# pwd
/home/root
root@qmtech-c5soc-kfb:~#
```

### Key Information from Boot Log
- **Kernel Version**: Linux 6.6.22-g73daf6f844a2
- **U-Boot Version**: 2024.07-36777-gac012d089de-dirty
- **CPU**: ARMv7 (dual-core Cortex-A9)
- **RAM**: 1 GiB
- **Boot Device**: SD/MMC (MMC1)
- **Default Console**: ttyS0 at 115200 bps
- **Root Filesystem**: ext3/ext4 on /dev/mmcblk0p2
- **Distro**: Poky (Yocto Project Reference Distro) 4.0.35

# build tools for wdmcex2u
## WD My Cloud EX 2 Ultra based on Marvell ARMADA 385
(forked and modified from the original Heisath/wdmc2-kernel)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate?hosted_button_id=HXWRU82YBV7HC&source=url)

* mainline kernel support tested with 5.18 / 6.0 / 6.1
	- device tree source ./dts/armada-385-wdmc-Ex2-Ultra.dts
	- kernel config for various kernels included check ./config/
	- some tweaks and pointers in txt files ./docs/
	- supports caching of kernel and rootfs so not everything needs to be rebuilt everytime
	- built rootfs has zram support and uses it for swap and logging
	
* prerequisites for building will be installed by build.sh automatically.
	- buildscript has been developed and tested on Ubuntu Hirsute (21.04) with gcc-arm-none-eabi (https://packages.ubuntu.com/hirsute/gcc-arm-none-eabi) hosted in a VirtualBox, there are known problems when using older debian/ubuntu releases or wsl(2)
	- `apt-get install build-essential bc libncurses5 dialog u-boot-tools git libncurses-dev lib32z1 lib32ncurses5-dev libmpc-dev libmpfr-dev libgmp3-dev flex bison debootstrap debian-archive-keyring qemu-user-static`
	- gcc for arm eabi `apt-get install gcc-arm-none-eabi`

* build.sh
	- provides a way of building a kernel, rootfs and uRamdisk
	- run build.sh as root (or with sudo)
	- script will use dialog to ask for features and configuration
	- possible parameters to skip dialogs are:
		- `--kernel` to select kernel building:
   		    - `--kernelbranch {branch}` to select kernel branch from kernel.org
	   		- `--clean` to reset and fetch git before compiling kernel (to remove possible changes)
    		- `--config` to use menuconfig to allow user to customize kernel
		- `--rootfs` to select rootfs creation:
    		- `--release {debianrelease}` to select the debian release to use as rootfs
			- `--changes` to pause and wait for changes in the rootfs before unmounting and packaging (this allows you to do customization)
        	- `--initramfs` to create new initramfs in rootfs
    		- `--root-pw {rootpw}` to select root pw for new rootfs
	    	- `--hostname {host}` to select hostname for new rootfs
            - `--zram` to enable logging and swap via ZRAM
            - `--boot {usb/hdd}` to select fstab to use (either for booting from usb or hdd)
	- if a parameters is not given, the default value is used or the user is prompted
	- if building a rootfs build.sh will include the tweaks from ./tweaks/  You can adjust fstab and various other stuff there, files will be copied straight to rootfs
	- Depending on the selected actions the script will:
		- for the kernel: 
			- git clone and checkout the kernel 
			- insert kernel-config and device tree into kernel
			- try making it with menuconfig 
			- attach dtb to zImage then mkimage
			- place the results in ./output/boot and ./output/modules
		- for the rootfs:
			- use debootstrap to generate a debian rootfs in ./output/rootfs/
			- apply the tweaks and setup some useful programs via apt
			- copy the results from kernel making into the right folders (boot and lib)
			- if building initramfs is enabled it will also:
				- run build_initramfs.sh in the chroot and generate a new uRamdisk 
			- pack the rootfs into a tar.gz so you can easily extract it on your usb/hdd
			
* build_initramfs.sh
		
	builds a minimal initramfs.  Can boot from kernel commandline,
	usb-stick 2nd partition, hdd 3rd partition.
	needs to be placed in /boot/uRamdisk.

       	This needs to be run on the wdmycloud. So to get your first boot use the uRamdisk provided!
	Or use the build.sh and also create a rootfs on your host to chroot and run this in.
		

* general install instructions

	To use the prebuilt releases on your wdmc you'll have to decide wether to use a USB drive or the internal drive. 
	
	##### USB (usb 2.0 stick is recommended, usb 3.0 does have troubles rebooting):
	- create a FAT32 partition (this will be used to boot, will be called sdb1)
	- create a ext4 partition (this will be used as root, will be called sdb2)
	- extract boot-5.x.x.tar.gz on sdb1 (FAT32) partition
	- extract the bullseye-rootfs.tar.gz on the sdb2 (ext4) partition
	- adjust sdb2/etc/fstab to fit your needs (will probably be ok)
	- boot wdmc with usb stick, root password is '1234'
	- adjust time and date, use `hwclock --systohc` to update RTC
	- configure/add packages as needed
	
	##### Internal:
	- make sure drive is using gpt
	- create root ext4 partition as sda3 
		- in original wd firmare this needed to be /dev/sda3 (as sda1 was swap and sda2 data) 
		- new uRamdisk also supports booting from /dev/sda1 (though this is untested and might not work)
	- extract bullseye-rootfs.tar.gz on the root
	- adjust sda3/etc/fstab to fit your needs (check it at least!)
	- boot wdmc, root password is '1234' configure/add packages as needed
	- adjust time and date, use `hwclock --systohc` to update RTC
	- configure/add packages as needed
	- I suggest starting with USB stick, because this requires no changes on the internal harddisk.

	If you need custom initramfs or different kernel settings, check the code and build neccessary files yourself.
		
* how to debug

	If you get stuck at any point it is really helpful to access the boot log and watch uboot and the uRamdisk do its stuff. You can connect a 3.3V usb-serial converter (also often referred to as FTDI Breakout or USB2UART) to the UART pins on the wdmc. The wdmc is using 115200b8n1 with 3.3V pullups on the data lines. Use the image below for reference (also check the docs folder!) 
	WDMCEX2Ultra image will go here :)
		
Thanks to: \
AllesterFox (http://anionix.ddns.net/WDMyCloud/WDMyCloud-Gen2/) \
Johns Q https://github.com/Johns-Q/wdmc-gen2 for their original work on the wdmc-gen2 \
ARMBIAN (https://github.com/armbian/build) for their awesome build script which gave lots of inspiration and the zram config :)

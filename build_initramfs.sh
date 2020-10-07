#!/bin/bash

# https://wiki.gentoo.org/wiki/Custom_Initramfs

# needed to make parsing outputs more reliable
export LC_ALL=C
# we can never know what aliases may be set, so remove them all
unalias -a

# destination
OUTPUT=./../output
INITRAMFS=./initramfs/root

# remove old cruft
rm -rf ${INITRAMFS}/

mkdir -p ${INITRAMFS}/${OUTPUT}/

mkdir -p ${INITRAMFS}/{bin,dev,etc,lib,lib64,newroot,proc,sbin,sys,usr} ${INITRAMFS}/usr/{bin,sbin}
cp -a /dev/{null,console,tty} ${INITRAMFS}/dev
cp -a /bin/busybox ${INITRAMFS}/bin/busybox
cp $(ldd "/bin/busybox" | egrep -o '/.* ') ${INITRAMFS}/lib/

cat << EOF > ${INITRAMFS}/init
#!/bin/busybox sh
/bin/busybox --install

rescue_shell() {
	printf '\e[1;31m' # bold red foreground
	printf "\$1 Dropping you to a shell."
	printf "\e[00m\n" # normal colour foreground
	#exec setsid cttyhack /bin/busybox sh
	exec /bin/busybox sh
}

ask_for_stop() {
        key='boot'
        read -r -p "### Press any key to stop and run shell... (2)" -n1 -t5 key
        if [ \$key != 'boot' ]; then
                rescue_shell
        fi
}


# initialise
mount -t devtmpfs none /dev || rescue_shell "mount /dev failed."
mount -t proc none /proc || rescue_shell "mount /proc failed."
mount -t sysfs none /sys || rescue_shell "mount /sys failed."

ask_for_stop
sleep 5

# get cmdline parameters
init="/sbin/init"
root=\$1
rootflags=
rootfstype=auto
ro="ro"

for param in \$(cat /proc/cmdline); do
	case \$param in
		init=*		) init=\${param#init=}			;;
		root=*		) root=\${param#root=}			;;
		rootfstype=*	) rootfstype=\${param#rootfstype=}	;;
		rootflags=*	) rootflags=\${param#rootflags=}	;;
		ro		) ro="ro"				;;
		rw		) ro="rw"				;;
	esac
done

# try to mount the root filesystem.
if [ "\${root}"x != "/dev/ram"x ]; then

	mount -t \${rootfstype} -o \${ro},\${rootflags} \${root} /newroot || rescue_shell "mount \${root} failed."
fi

# try 2nd partition on usb
if [ ! -x /newroot/\${init} ] && [ ! -h /newroot/\${init} ] && [ -b /dev/sdb1 ] && [ -b /dev/sdb2 ]; then
	mount -t \${rootfstype} -o \${ro},\${rootflags} /dev/sdb2 /newroot || rescue_shell "mount \${root} failed."
	if [ ! -x /newroot/\${init} ] && [ ! -h /newroot/\${init} ]; then
		umount /dev/sdb2
	fi
fi

# try 3rd partition on hdd
if [ ! -x /newroot/\${init} ] && [ ! -h /newroot/\${init} ] && [ -b /dev/sda1 ] && [ -b /dev/sda3 ]; then
	mount -t \${rootfstype} -o \${ro},\${rootflags} /dev/sda3 /newroot || rescue_shell "mount \${root} failed."
	if [ ! -x /newroot/\${init} ] && [ ! -h /newroot/\${init} ]; then
		umount /dev/sda3
		rescue_shell "nothing bootable"
	fi
fi

# WD My Cloud: turn led solid blue
echo none > /sys/class/leds/system-blue/trigger
echo default-on > /sys/class/leds/system-green/trigger
echo ide-disk > /sys/class/leds/system-red/trigger

# WD My Cloud: get mac from nand
ip link set dev eth0 address \$(dd if=/dev/mtd0 bs=1 skip=1046528 count=17 2>/dev/null)

# clean up.
umount /sys /proc /dev

# boot the real thing.
exec switch_root /newroot \${init} || rescue_shell

rescue_shell "end reached"
EOF
chmod +x ${INITRAMFS}/init


cd ${INITRAMFS}
find . -print | cpio -ov --format=newc | gzip -9 > ${OUTPUT}/custom-initramfs.cpio.gz
mkimage -A arm -O linux -T ramdisk -a 0x00e00000 -e 0x0 -n "Custom initramfs" -d ${OUTPUT}/custom-initramfs.cpio.gz ${OUTPUT}/uRamdisk


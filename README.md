# PC Engines APU2

This bash script strips and modifies a apu2 firmware with a current seabios version and grub2 payload.
With the support of grub2 it is possible to build a secureboot for the apu2 platform.

## APU2 SecureBoot

<p align="center">
  <img src="https://raw.githubusercontent.com/9elements/apu2-grub2-support/master/doc/overview.png" />
</p>

The whole Seabios and GRUB2 configuration and modules are embedded into the coreboot flash itself. This feature can protect against software attacks by using setting the write protect bits via flashrom and shorting jumper2 pins (1 and 2). Take a look at the [PC Engines APU2 manual](http://pcengines.ch/pdf/apu2.pdf)

## Seabios

The Seabios is replaced by the up-to-date version (1.9.1) and configured so that no input and loading mechanism are used. In short keyboard, mouse input is disabled. All drive detection features are stripped out of seabios which are not necessary. The bootorder is fused to the grub2 floppyimg itself. The menu is completly disabled so that no input and modification can be done. For further information take a look at the [Seabios configuration](https://github.com/9elements/apu2-grub2-support/blob/master/config/seabios.cfg)

## Customization

First of all the [GRUB2 Configuration](https://github.com/9elements/apu2-grub2-support/blob/master/config/grub.cfg) needs to be adapted for your project, that has to be done at this part:

```bash
set default="0"
set timeout="0"

menuentry "OpenWrt" --unrestricted {
	set root='(hd1,msdos1)'

	linux /boot/vmlinuz block2mtd.block2mtd=/dev/mmcblk0p2,65536,rootfs,5 root=/dev/mtdblock0 rootfstype=squashfs rootwait console=tty0 console=ttyS0,115200n8 noinitrd
}
menuentry "OpenWrt (failsafe)" --unrestricted {
	set root='(hd1,msdos1)'

	linux /boot/vmlinuz failsafe=true block2mtd.block2mtd=/dev/mmcblk0p2,65536,rootfs,5 root=/dev/mtdblock0 rootfstype=squashfs rootwait console=tty0 console=ttyS0,115200n8 noinitrd
}
```

Also change the password "__password_pbkdf2 root grub.pbkdf2.sha512.10000.c2yXVNGZAF81KGUvY9wS36wGG__" which protects the grub2 configuration from modification with the following command:

```bash
./tmp/bin/grub2-mkpasswd-pbkdf2
```

In order to add your SecureBoot publickey please generate a new gpg key for signing only:

```bash
gpg --full-gen-key

gpg (GnuPG) 2.1.11; Copyright (C) 2016 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
Your selection? 4
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (2048) 4096
Requested keysize is 4096 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0)
Key does not expire at all
Is this correct? (y/N) y

GnuPG needs to construct a user ID to identify your key.

Real name: Max Mustermann
Email address:
Comment:
You selected this USER-ID:
    "Max Mustermann"
```

After you generated your key, export the [GRUB2 SecureBoot Public Key](https://github.com/9elements/apu2-grub2-support/blob/master/config/boot.pub) and save it under config:

```bash
gpg --export gpg_key_id  > config/boot.pub
```

Now you are ready to sign your files which should be verified and included by your grub2 configuration via:

```
for file in /boot/* ; do if [ ! -d "${file}" ] ; then gpg -u gpg_key_id --detach-sign "${file}" ; fi ; done
```

### Adding GRUB2 modules

If you want to change the grub2 module list for pxe boot, lvm and so on. Take a look at the mksecboot.sh script env variable GRUB_MODULES and just add them there. The maximum size of the grub2 payload can be 2.5MB !

## Dependencies

The build script needs some dependencies to proceed with compilation:

```bash
sudo apt-get install xorriso git build-essential autoconf automake libdevmapper-dev liblzma-dev
```

## Usage

Finally let's build the coreboot image based on a specific apu2 firmware:

```bash
./mksecboot.sh firmware/*.rom
```

The final image can be found under tmp/firmware.bin .

# PC Engines APU2

This bash script strips and modifies a apu2 firmware with a current seabios version and grub2 payload.
With the support of grub2 it is possible to build a secureboot for the apu2 platform.
As long as the coreboot community and vendor doesn't provide a running and functional OpenSource version of
the Firmware this is the way to go if you want to build  a secureboot or to use grub2 specific features.

## SecureBoot

<p align="center">
  <img src="" />
</p>

## Customization

First of all the [GRUB2 Configuration](https://github.com/9elements/apu2-grub2-support/blob/master/config/grub.cfg) needs to be adapted for your project, that has to be done at this part:

```bash
set default="0"
set timeout="5"

menuentry "OpenWrt" {
	insmod part_msdos
	insmod squash4
	insmod ext2
	insmod gcry_sha512
	insmod gcry_rsa
	set root='(hd1,msdos1)'
	verify_detached -s /boot/vmlinuz /boot/vmlinuz.sig

	linux /boot/vmlinuz root=/dev/mmcblk0p2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd
}
menuentry "OpenWrt (failsafe)" {
	insmod part_msdos
	insmod squash4
	insmod ext2
	insmod gcry_sha512
	insmod gcry_rsa
	set root='(hd1,msdos1)'
	verify_detached -s /boot/vmlinuz /boot/vmlinuz.sig

	linux /boot/vmlinuz failsafe=true root=/dev/mmcblk0p2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd
}
```

Also change the password "__c2yXVNGZAF81KGUvY9wS36wGG__" which protects the grub2 configuration from modification

```bash
password_pbkdf2 root grub.pbkdf2.sha512.10000.c2yXVNGZAF81KGUvY9wS36wGG
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

If you want to change the grub2 module list for pxe boot, lvm and so on. Take a look at the mksecboot.sh script env variable
GRUB_MODULES and just add them there.

## Usage

Finally let's build the coreboot image based on a specific apu2 firmware:

```bash
./mksecboot.sh firmware/*.rom
```

#!/bin/bash

FIRMWARE_PATH=${1}
ROOT=$(pwd)
TMP_DIR="${ROOT}/tmp"
CONFIG_DIR="${ROOT}/config"
DOWNLOAD_DIR="${ROOT}/dl"
GRUB2_REPO_URL="https://github.com/dweeezil/grub.git"
GRUB2_REPO_BRANCH="master"
COREBOOT_REPO_URL="https://review.coreboot.org/p/coreboot.git"
COREBOOT_REPO_BRANCH="master"
GRUB2_APU2_MODULES_BASE="
part_msdos
squash4
ext2
normal
linux
boot
"
GRUB2_MODULES="${GRUB2_APU2_MODULES_BASE}"
SEABIOS_REPO_URL="git://git.seabios.org/seabios.git"
SEABIOS_REPO_BRANCH="rel-1.9.1"
MAKE_ARGS="-j8"

##
# Isoburn package is needed to do this job.
##

mkdir "${TMP_DIR}"
mkdir "${DOWNLOAD_DIR}"

cp "${FIRMWARE_PATH}" "${TMP_DIR}/firmware.bin"

if [ ! -d "${DOWNLOAD_DIR}/grub" ] ; then
  cd "${DOWNLOAD_DIR}"
  git clone "${GRUB2_REPO_URL}" -b "${GRUB2_REPO_BRANCH}"
  git clone --recursive "${COREBOOT_REPO_URL}" -b "${COREBOOT_REPO_BRANCH}"
  git clone "${SEABIOS_REPO_URL}" -b "${SEABIOS_REPO_BRANCH}"
else
  cd "${DOWNLOAD_DIR}"
  cd grub && git clean -d -x -f && git stash

  cd "${DOWNLOAD_DIR}"
  cd coreboot && git clean -d -x -f && git stash

  cd "${DOWNLOAD_DIR}"
  cd seabios && git clean -d -x -f && git stash
fi

cp "${CONFIG_DIR}/seabios.cfg" "${DOWNLOAD_DIR}/seabios/.config"

# build seabios with custom configuration
cd "${DOWNLOAD_DIR}"

cd seabios && make "${MAKE_ARGS}"
cp out/bios.bin.elf "${TMP_DIR}/seabios.bin"

# build grub2 with device-mapper and lzma for module compression
cd "${DOWNLOAD_DIR}"

cd grub && ./autogen.sh
./configure --enable-device-mapper --enable-liblzma --prefix="${TMP_DIR}" \
    --with-platform=pc
make "${MAKE_ARGS}"
make install

# Build coreboot cbfsutil in order to edit firmware image
cd "${DOWNLOAD_DIR}"

cd coreboot/util/cbfstool
make "${MAKE_ARGS}"
cp -a cbfstool fmaptool rmodtool "${TMP_DIR}/bin/"

# Add grub2.elf as payload for the firmware image and generate standalone grub for coreboot as payload
cd "${ROOT}"

"${TMP_DIR}/bin/grub-mkrescue" --compress=xz \
    --modules="${GRUB2_MODULES}" \
    --output "${TMP_DIR}/grub2.dsk.tmp" \
    --fonts= --themes= --locales= \
    --pubkey="${CONFIG_DIR}/boot.pub" \
    /boot/grub/grub.cfg="${CONFIG_DIR}/grub.cfg"

dd if=/dev/zero of="${TMP_DIR}/grub2.dsk" bs=512 count=5760
dd if="${TMP_DIR}/grub2.dsk.tmp" of="${TMP_DIR}/grub2.dsk" conv=notrunc

echo "--------------------------OLD--------------------------"
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" print
echo "-------------------------------------------------------"

"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n fallback/payload
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" add-payload -f "${TMP_DIR}/seabios.bin" -n fallback/payload

"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n bootorder
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" add -f "${CONFIG_DIR}/bootorder" -n bootorder -t raw
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n bootorder_def
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n bootorder_map

"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n etc/boot-menu-message
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n etc/boot-menu-key
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n etc/boot-menu-wait

"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n img/setup
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n img/memtest
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" remove -n genroms/pxe.rom

"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" add -f "${TMP_DIR}/grub2.dsk" -n floppyimg/grub2.lzma -t raw -c lzma

echo "--------------------------NEW--------------------------"
"${TMP_DIR}/bin/cbfstool" "${TMP_DIR}/firmware.bin" print
echo "-------------------------------------------------------"

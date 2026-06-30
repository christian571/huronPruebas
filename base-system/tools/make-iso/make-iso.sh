#!/bin/bash

#	make-iso.sh
#	Script to generate the ISO file for huronOS
#
#	Copyright (C) 2024, huronOS Project:
#		<http://huronos.org>
#
#	Licensed under the GNU GPL Version 2
#		<http://www.gnu.org/licenses/gpl-2.0.html>
#
#	Authors:
#		Enya Quetzalli <equetzal@huronos.org>

ISO_DATA=""
ISO_TOOL=""
ISO_OUTPUT=""
CHECKSUMS="./checksums"
EFI_DIR=""
BOOT_DIR=""
HURONOS_DIR=""
readonly ISO_DATA
readonly ISO_TOOL
readonly ISO_OUTPUT
readonly CHECKSUMS
readonly EFI_DIR
readonly BOOT_DIR
readonly HURONOS_DIR

## Move to ISO directory
CURRENT_PATH="$(pwd)"
echo "Moving to $ISO_DATA"
cd "$ISO_DATA" || exit 1 # error

## Calculate checksums
rm -rf "$CHECKSUMS"
FILES_TO_CHECK="$(find "$EFI_DIR" -type f -print) $(find "$BOOT_DIR" -type f -print) $(find "$HURONOS_DIR" -type f -print)"
for FILE in $FILES_TO_CHECK; do
	echo "Calculating checksum: $FILE"
	sha256sum -b "$FILE" >>"$CHECKSUMS"
done
## Delete isolinux.boot and isolinux.bin due to mkisofs recalc
## this binaries acording to ISO 9660 standard. This will make
## checksum to always be different.
sed '/.*isolinux.boot.*/d' -i "$CHECKSUMS"
sed '/.*isolinux.bin.*/d' -i "$CHECKSUMS"

## Create ISO
echo "Generating $ISO_OUTPUT"

# PARCHE
# Emparejar las versiones de Syslinux usando los binarios nativos del sistema
sudo cp /usr/lib/ISOLINUX/isolinux.bin boot/isolinux.bin
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 boot/ldlinux.c32

# creacion de imagen EFI para soporte UEFI 
echo "Generando imagen FAT para arranque UEFI..."
sudo dd if=/dev/zero of=boot/efiboot.img bs=1M count=10
sudo mkfs.vfat boot/efiboot.img
sudo mkdir -p /tmp/efimnt
sudo mount -o loop boot/efiboot.img /tmp/efimnt
sudo mkdir -p /tmp/efimnt/EFI/Boot
sudo cp -r EFI/Boot/* /tmp/efimnt/EFI/Boot/
sudo mkdir -p /tmp/efimnt/boot
sudo cp bootloader/legacy/huronos.cfg /tmp/efimnt/boot/
sudo cp bootloader/legacy/syslinux.cfg /tmp/efimnt/boot/
sudo cp bootloader/EFI/Boot/*.c32 /tmp/efimnt/boot/
sudo umount /tmp/efimnt
sudo rm -rf /tmp/efimnt

# Sudo para sortear la restricción de permisos de los módulos .hsm
sudo "$ISO_TOOL" -o "$ISO_OUTPUT" -v -J -R -D -A "huronOS" -V "huronOS" -no-emul-boot -boot-info-table -boot-load-size 4 -b boot/isolinux.bin -c boot/isolinux.boot -eltorito-alt-boot -e boot/efiboot.img -no-emul-boot .

# Hibridar la ISO resultante para poder arranquar en USB
echo "Aplicando parche isohybrid..."
sudo isohybrid --uefi "$ISO_OUTPUT"

## Gen ISO Hash
sha256sum "$ISO_OUTPUT" | sed 's, .*/, ,' > "$ISO_OUTPUT.sha256"
md5sum "$ISO_OUTPUT" | sed 's, .*/, ,' > "$ISO_OUTPUT.md5"

## Return to original directory
cd "$CURRENT_PATH" || exit 1 # error
echo "Finished! :) -> $ISO_OUTPUT"
exit 0 # sucess

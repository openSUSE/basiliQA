#! /bin/bash
#
# do-i2q-B.sh
# Prepare an operating system for running in basiliQA
# Phase B: run on real host

# Copyright (C) 2015,2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Input files: $temp/autoinst.xml
# Output files: $temp/installation.raw
#               $temp/cdrom.iso -> /var/cache/xxxxx.iso
#               $temp/wget-log.txt

scripts=$(dirname "$0")
source $scripts/../../../lib/basiliqa-basic-functions.sh

get-default "WORKSPACE_ROOT" "directories/@workspace-root"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"

cache=/var/cache/basiliqa
temp=$WORKSPACE_ROOT/iso2qcow2

# Download ISO image (only if it has changed since last time)
echo "Retrieving $ISO_URL..."
LANG=C wget -N $ISO_URL -P $cache -o $temp/wget-log.txt
if [ $? -ne 0 ]; then
  echo "Failure while downloading ISO image" >&2
  exit 2
fi
grep -q "not retrieving" $temp/wget-log.txt
if [ $? -ne 0 ]; then
  echo "ISO image downloaded"
else
  echo "ISO image is already in cache"
  if [ "$FORCE_CONVERSION" != "yes" ]; then
    echo "Stopping here. To force conversion, please export FORCE_CONVERSION='yes'."
    touch $temp/aborted.txt
    echo
    exit 0
  fi
fi
ln -sf $cache/$(basename $ISO_URL) $temp/cdrom.iso

# The s390x images can't boot: prepare an external kernel and an external initrd
if [ "$ARCH" = "s390x" ]; then
  echo "Extracting the kernel and the initrd from non-bootable s390x image"
  mkdir $temp/mnt
  sudo mount -o loop,ro -t iso9660 $temp/cdrom.iso $temp/mnt/
  cp $temp/mnt/boot/s390x/initrd $temp/initrd.bin
  cp $temp/mnt/boot/s390x/vmrdr.ikr $temp/kernel.bin
  sudo umount $temp/mnt
  rmdir $temp/mnt
  ls -lh $temp/*.bin
fi

# Prepare "floppy disk" image
dd if=/dev/zero of=$temp/installation.raw bs=1024 count=1440
/sbin/mkfs.fat $temp/installation.raw
mkdir $temp/mount
mount $temp/mount
cp $temp/autoinst.xml $temp/mount/
sync
umount $temp/mount
rmdir $temp/mount

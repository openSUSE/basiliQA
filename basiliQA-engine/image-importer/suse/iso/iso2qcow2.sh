#! /bin/bash
#
# iso2qcow2.sh
# Prepare an operating system for running in basiliQA

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

# Input: an installation ISO image
# Output: a ready to use QCow2 hard disk
#
# This script uses the following environment variables:
#   ISO_URL             where to download the ISO image from
#   FORCE_CONVERSION    'yes' if ISO image already in cache must be converted
#   SYSTEM              full system name, with details like build number
#   FAMILY              generic system name
#   ARCH                architecture
#   VARIANT             different way of installing
#   UPDATES             'yes' for installing updates within installation
#
#   IMAGE_SOURCE        location of images and images list
#   JAIL_ROOT           location of confinement jail, or "none" if no jail
#   LIBVIRT_DEFAULT_URI way to run virsh
#   WORKSPACE_ROOT      location of work space
#
# The IMAGE_SOURCE, JAIL_ROOT, WORKSPACE_ROOT and LIBVIRT_DEFAULT_URI
# variables, if omitted, will be taken from defaults
# in /etc/basiliqa/basiliqa.conf.
#
# Requirements:
#   A cache directory /var/cache/basiliqa owned by jenkins:jenkins
#   A line in /etc/fstab that says:
#     /var/tmp/basiliqa/workspace/iso2qcow2/installation.raw  /var/tmp/basiliqa/workspace/iso2qcow2/mount  vfat  noauto,loop,user  0 0
#   Following utilities installed:
#     wget (in wget)
#     mkfs.fat (in dosfstools)
#     saxon9 (in saxon9) *** TODO: get rid of it ***
#     xsltproc (in libxslt-tools)
#     virsh (in libvirt-client)
#     expect (in expect)
#     qemu-img (in qemu-tools)

scripts=$(dirname "$0")
source $scripts/../../../lib/basiliqa-basic-functions.sh

check-value "ISO_URL" "$ISO_URL"
check-value "FORCE_CONVERSION" "$FORCE_CONVERSION"
check-value "SYSTEM" "$SYSTEM"
check-value "FAMILY" "$FAMILY"
check-value "ARCH" "$ARCH"
check-value "VARIANT" "$VARIANT"
check-value "UPDATES" "$UPDATES"

echo "ISO_URL=$ISO_URL"
echo "FORCE_CONVERSION=$FORCE_CONVERSION"
echo
echo "SYSTEM=$SYSTEM"
echo "FAMILY=$FAMILY"
echo "ARCH=$ARCH"
echo "VARIANT=$VARIANT"
echo "UPDATES=$UPDATES"
echo

get-default "JAIL_ROOT" "directories/@jail-root"
check-value "JAIL_ROOT" "$JAIL_ROOT"
get-default "WORKSPACE_ROOT" "directories/@workspace-root"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"

temp=$WORKSPACE_ROOT/iso2qcow2

if [ "$JAIL_ROOT" = "none" ]; then
  "$scripts/do-i2q-A.sh"
  rc=$?; [ $rc -ne 0 ] && exit $rc

  "$scripts/do-i2q-B.sh"
  rc=$?; [ $rc -ne 0 ] && exit $rc
  [ -f $temp/aborted.txt ] && exit 0

  "$scripts/do-i2q-C.sh"
  rc=$?; [ $rc -ne 0 ] && exit $rc
else
  vars='ISO_URL FORCE_CONVERSION
        SYSTEM FAMILY ARCH VARIANT UPDATES
        JAVA_.* JRE_.*'

  run-in-jail "/usr/lib/basiliqa/image-importer/suse/iso/do-i2q-A.sh" "$vars"
  rc=$?; [ $rc -ne 0 ] && exit $rc

  "$scripts/do-i2q-B.sh"
  rc=$?; [ $rc -ne 0 ] && exit $rc
  [ -f $temp/aborted.txt ] && exit 0

  run-in-jail "/usr/lib/basiliqa/image-importer/suse/iso/do-i2q-C.sh" "$vars"
  rc=$?; [ $rc -ne 0 ] && exit $rc
fi

exit 0

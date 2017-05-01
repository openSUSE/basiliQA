#! /bin/bash
#
# do-i2q-C.sh
# Prepare an operating system for running in basiliQA
# Phase C: run in jail

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

# Input files: $temp/installation.raw
#              $temp/cdrom.iso -> $cache/xxxxx.iso

function send-result
{
  src="$1"
  dst="$2"

  if [[ "$IMAGE_SOURCE" =~ http://([^/]*)/(.*) ]]; then
    host=${BASH_REMATCH[1]}
    path=/srv/www/htdocs/${BASH_REMATCH[2]}
    echo "Sending $src to ${host}:$path/$dst..."
    scp -o StrictHostKeyChecking=no -P 23 $temp/$src wwwrun@${host}:$path/$dst
  else
    path=$IMAGE_SOURCE
    echo "Saving $src as $path/$dst..."
    cp $temp/$src $path/$dst
  fi
}

scripts=$(dirname "$0")
source $scripts/../../../lib/basiliqa-basic-functions.sh

get-default "WORKSPACE_ROOT" "directories/@workspace-root"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
get-default "LIBVIRT_DEFAULT_URI" "vms/@virsh-uri"
check-value "LIBVIRT_DEFAULT_URI" "$LIBVIRT_DEFAULT_URI"
get-default "IMAGE_SOURCE" "images/@source"
check-value "IMAGE_SOURCE" "$IMAGE_SOURCE"

temp=$WORKSPACE_ROOT/iso2qcow2

# Prepare virtual machine's disk
freespace=$(df --output=avail $temp -BG | tail -n 1 | tr -d ' G')
if [ "$freespace" -lt 4 ]; then
  echo "Not enough free space, we have ${freespace}G, but we need at least 4G" >&2
  exit 5
fi
qemu-img create -f qcow2 $temp/hard-disk.qcow2 18G
if [ $? -ne 0 ]; then
  echo "Error while preparing VM disk" >&2
  exit 5
fi

# Test whether host's arch is the same as SUT's arch (qemu or kvm?)
if [ "$(uname -m)" = "$ARCH" ]; then
  emulation="no"
else
  emulation="yes"
fi

# Use "ppc64be" instead of "ppc64" to avoid confusion with "ppc64le"
arch="$ARCH"
[ "$arch" = "ppc64" ] && arch="ppc64be"

# Prepare virtual machine
xsltproc \
       --stringparam "arch" "$arch" \
       --stringparam "emulation" "$emulation" \
       --stringparam "cdrom" "$temp/cdrom.iso" \
       --stringparam "disk" "$temp/hard-disk.qcow2" \
       --stringparam "floppy" "$temp/installation.raw" \
       --stringparam "nvram" "$temp/nvram.bin" \
       --stringparam "kernel" "$temp/kernel.bin" \
       --stringparam "initrd" "$temp/initrd.bin" \
       "$scripts/basebox.xslt" "$scripts/basebox.xml" > "$temp/basebox.xml"
if [ $? -ne 0 ]; then
  echo "Error while preparing VM control file" >&2
  exit 6
fi
virsh define $temp/basebox.xml

# Start virtual machine
virsh start basebox-iso2qcow2
if [ $? -ne 0 ]; then
  echo "Error while starting VM" >&2
  exit 7
fi

# Proceed with installation
expect $scripts/keypresses-${ARCH}.exp | tee $temp/autoinst.log
if [ $? -ne 0 ]; then
  echo "Error while installing VM" >&2
  exit 8
fi

# Flush input buffer (polluted by console emulation)
read -t 0.1 -n 80

# On s390x, the VM is halted instead of rebooted (bug?)
# So we need to restart it
if [ "$ARCH" = "s390x" ]; then
  virsh undefine basebox-iso2qcow2
  sed '/<cmdline>/d; /<disk type="file" device="cdrom">/,/<\/disk>/d' "$temp/basebox.xml" > "$temp/basebox2.xml"
  virsh define "$temp/basebox2.xml"
  virsh start basebox-iso2qcow2
  if [ $? -ne 0 ]; then
    echo "Error while starting VM" >&2
    exit 7
  fi
  expect $scripts/keypresses-s390x-stage2.exp | tee $temp/autoinst2.log
  if [ $? -ne 0 ]; then
    echo "Error while installing VM" >&2
    exit 8
  fi
  read -t 0.1 -n 80
fi

# We don't need the VM anymore
virsh destroy basebox-iso2qcow2
virsh undefine --nvram basebox-iso2qcow2

# Check size of result > 10 MB
size=$(stat -c %s $temp/hard-disk.qcow2)
if [ "$size" -lt "10485760" ]; then
  echo "Results seems too small ($size bytes), giving up" >&2
  exit 9
fi

# Use different name if image contains updates
if [ "${UPDATES}" = "yes" ]; then
  today=$(date +%y%m%d)
  updated="_up${today}"
else
  updated=""
fi

# Copy the result to the desired place
image="${SYSTEM}${updated}-${ARCH}-${VARIANT}.qcow2"
ls -lh $temp/hard-disk.qcow2
send-result hard-disk.qcow2 $image
if [ $? -ne 0 ]; then
  echo "Failure while sending" >&2
  exit 10
fi

# Get the list of images and add new image to it
if [[ "$IMAGE_SOURCE" =~ http:// ]]; then
  wget -q -O $temp/images-list.txt $IMAGE_SOURCE/images.list
else
  cp $IMAGE_SOURCE/images.list $temp/images-list.txt
fi
grep -q " $image" $temp/images-list.txt
if [ $? -ne 0 ]; then
  echo "-  $FAMILY    $image" >> $temp/images-list.txt
fi

# Give a chance to edit it, for example to change order of images
vi $temp/images-list.txt

# Store new list of images
send-result images-list.txt images.list
if [ $? -ne 0 ]; then
  echo "Failure while sending" >&2
  exit 10
fi

# Store new dropdown list
awk 'BEGIN   {printf "%s", "IMAGE_NAME="}
     /^[-A]/ {sub(".qcow2$", "")
              printf "%s,", $3}
    ' $temp/images-list.txt > $temp/properties.list
sed -i "s/,\$/\\n/" $temp/properties.list
send-result properties.list ../properties.list
if [ $? -ne 0 ]; then
  echo "Failure while sending" >&2
  exit 10
fi

rm -rf $temp

#! /bin/bash
#
# do-i2q-A.sh
# Prepare an operating system for running in basiliQA
# Phase A: run in jail

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

# Output files: $temp/autoinst.xml

scripts=$(dirname "$0")
source $scripts/../../../lib/basiliqa-basic-functions.sh

get-default "WORKSPACE_ROOT" "directories/@workspace-root"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
get-default "LIBVIRT_DEFAULT_URI" "vms/@virsh-uri"
check-value "LIBVIRT_DEFAULT_URI" "$LIBVIRT_DEFAULT_URI"

temp=$WORKSPACE_ROOT/iso2qcow2

# Cleanup
rm -rf $temp
mkdir -p $temp
virsh destroy basebox-iso2qcow2 2> /dev/null
virsh undefine --nvram basebox-iso2qcow2 2> /dev/null

# Prepare autoYaST file
case "$FAMILY" in
  openSUSE_13.1)
      template=autoinst-opensuse-13.1.xml
      ;;
  openSUSE_13.2)
      template=autoinst-opensuse-13.2.xml
      ;;
  openSUSE_42.1)
      template=autoinst-opensuse-42.1.xml
      ;;
  openSUSE_42.2)
      template=autoinst-opensuse-42.2.xml
      ;;
  openSUSE_TW)
      template=autoinst-opensuse-tw.xml
      ;;
  *)  echo "Unknown operating system, currently know only about openSUSE_13, openSUSE_42, and openSUSE_TW" >&2
      exit 3
esac
hostname=$(echo ${SYSTEM}-${ARCH}-${VARIANT} | tr '.' '_')
case "${VARIANT}" in
  "default")
      fips="no"
      graphical="no"
      ;;
  "fips")
      fips="yes"
      graphical="no"
      ;;
  "gnome")
      fips="no"
      graphical="yes"
      ;;
  "gnome_fips"|"fips_gnome")
      fips="yes"
      graphical="yes"
      ;;
  *)  echo "Unknown variant, currently know only about default, fips, and gnome" >&2
      exit 3
esac

# Get update repo for autoYAST from channels.conf
if [ "${UPDATES}" = "yes" ]; then
  updaterepo=$(channel-info "channel[@name=\"Updates\"]/repo[@family=\"${FAMILY}\"]/@url" "${ARCH}")
  if [ -z "$updaterepo" ]; then
    echo "Updates are not available for ${FAMILY}" >&2
    exit 3
  fi
else
  export updaterepo=""
fi

case "${FAMILY}" in
  openSUSE_13.1)
     case "${ARCH}" in
       x86_64)
          onlinerepo="openSUSE_13.1-x86_64.repo"
          ;;
       i586)
          onlinerepo="openSUSE_13.1-i386.repo"
          ;;
       *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
          exit 3
     esac
     ;;
  openSUSE_13.2)
     case "${ARCH}" in
       x86_64)
          onlinerepo="openSUSE_13.2-x86_64.repo"
          ;;
       i586)
          onlinerepo="openSUSE_13.2-i386.repo"
          ;;
       *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
          exit 3
     esac
     ;;
  openSUSE_42.1)
     case "${ARCH}" in
       x86_64)
          onlinerepo="openSUSE_42.1-x86_64.repo"
          ;;
       *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
          exit 3
     esac
     ;;
  openSUSE_42.2)
     case "${ARCH}" in
       x86_64)
          onlinerepo="openSUSE_42.2-x86_64.repo"
          ;;
       *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
          exit 3
     esac
     ;;
  openSUSE_TW)
     case "${ARCH}" in
       x86_64)
          onlinerepo="openSUSE_TW-x86_64.repo"
          ;;
       *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
          exit 3
     esac
     ;;
  *) echo "Can't determine online repository for ${FAMILY} and ${ARCH}" >&2
     exit 3
esac

# Use "ppc64be" instead of "ppc64" to avoid confusion with "ppc64le"
arch="$ARCH"
[ "$arch" = "ppc64" ] && arch="ppc64be"

saxon9 $scripts/$template $scripts/autoinst.xslt \
       arch=$arch \
       hostname=$hostname \
       fips=$fips \
       graphical=$graphical \
       onlinerepo=$onlinerepo \
       updaterepo=$updaterepo > $temp/autoinst.xml
if [ $? -ne 0 ]; then
  echo "Error while preparing autoYasT file" >&2
  exit 4
fi

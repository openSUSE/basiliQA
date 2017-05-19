#! /bin/bash
#
# cloud-rc.sh
# Set up environment for basiliQA cloud

# Copyright (C) 2015,2016,2017 SUSE LLC
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

name="$1"

if [ -z "$name" ]; then
  echo "Please specify cloud name" >&2
  exit 1
fi

export OS_AUTH_URL=http://${name}:5000/v3/
export OS_PROJECT_NAME="openstack"
unset OS_PROJECT_ID
export OS_USERNAME="basiliqa"
export OS_PASSWORD="opensuse"

export OS_USER_DOMAIN_NAME='Default'
export OS_IDENTITY_API_VERSION="3"
export OS_REGION_NAME='CustomRegion'

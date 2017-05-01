#! /bin/bash
#
# run-tests-in-vms.sh
# Run a set of tests in Virtual Machines - main script

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

# Input is taken from the same environment
# variables as with do-tests-in-vms, plus:
#
#   Variable         Example value
#
#   JAIL_ROOT        /home/johndoe/jail       (with jail)
#                    none                     (no jail)
#   TEST_PARAMETERS  TEST_PRECISE,FAST
#
# The JAIL_ROOT variable, if omitted, will be taken
# from defaults in /etc/basiliqa/basiliqa.conf.

scripts=$(dirname "$0")
source $scripts/../lib/basiliqa-basic-functions.sh

get-default "JAIL_ROOT" "directories/@jail-root"
check-value "JAIL_ROOT" "$JAIL_ROOT"
# empty TEST_PARAMETERS is okay and means "no test suite parameters to export"

if [[ "$(grep name /proc/1/cgroup)" =~ jail ]]; then
  echo "You are in the jail. Please exit the jail before you run basiliQA." >&2
  exit 255
fi

if [ "$JAIL_ROOT" = "none" ]; then
  "$scripts/do-tests-in-vms.sh"
else
  vars='PROJECT_NAME CONTROL_PKG HOME_PROJECT BUILD_ROOT
        IMAGE_SOURCE IMAGE_NAME_.*
        WORKSPACE_ROOT IMAGE_DIR
        TARGET_TYPE VIRSH_DEFAULT_CONNECT_URI
        VM_MODEL SUBNET_FIXED SUBNET6_FIXED
        REMOTE_VIRT_HOST REMOTE_VIRT_USER REMOTE_DHCP_HOST REMOTE_DHCP_USER
        WORKSPACE BUILD_NUMBER EXECUTION_CONTEXT
        KEEP_IF_SUCCESS
        UNINSTALL_.* REPO_.* EXTRA_REPO_.* INSTALL_.* REFRESH.* NIC_.* MODEL_.*
        SUBNET_.* SUBNET6_.* DHCP_.* GATEWAY_.*'
  vars="$vars ${TEST_PARAMETERS//,/ }"
  run-in-jail "/usr/lib/basiliqa/vms/do-tests-in-vms.sh" "$vars"
fi

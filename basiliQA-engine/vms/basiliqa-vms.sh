#! /bin/bash
#
# basiliqa-vms.sh
# Convenience wrapper for run-tests-in-vms.sh

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

function basiliqa-vms-help
{
  cat <<ENDHELP
Syntax:
basiliqa-vms.sh
    -h|--help

basiliqa-vms.sh
    [-i|--image <node>=<image-name>]...
    [ <optional parameters> ]
    [ <nodes file overrides> ]
    <project-name>

Optional parameters:
    [-s|--image-source <image-url>]
    [-d|--image-dir <image-directory>]
    [-c|--control-pkg <control-package>]
    [-p|--home-project <name-in-build-system>]
    [-l|--local] | [-b|--build-root <local-build-directory>]
    [-j|--jail]  | [-r|--jail-root <jail-root-directory>]
    [-u|--virsh-uri <virsh-uri>]
    [-m|--vm-model <flavor>]
    [-v|--virtio]
    [-f|--subnet-fixed <cidr>]
    [-g|--subnet6-fixed <cidr6>]
    [-w|--workspace <workspace-directory>]
    [-x|--context <execution-context>]
    [-t|--test-parameters <parameters>]

Nodes file overrides:
    [-K|--keep]
    [-U|--uninstall <node>=<packages>]...
    [-R|--repo <node>=<repo-urls>]...
    [-X|--extra-repo <node>=<repo-urls>]...
    [-I|--install <node>=<packages>]...
    [-A|--refresh <node>=<yes-or-no>]...
    [-N|--nic <node>=<networks>]...
    [-V|--disk <node>=<sizes>]...
    [-M|--model <node>=<flavor>]...
    [-S|--subnet <network>=<cidr>]...
    [-6|--subnet6 <network>=<cidr6>]...
    [-D|--dhcp <network>=<yes-or-no>]...
    [-G|--gateway <network>=<yes-or-no>]...

ENDHELP
}

# Default values
export CONTROL_PKG="tests-control"
export TARGET_TYPE="ssh"

# Parse arguments
ARGS=$(getopt -o "hljvi:s:d:c:p:b:r:u:m:f:g:w:x:t:KU:R:X:I:A:N:V:M:S:6:D:G:" \
              --long "help,local,jail,virtio,image:,image-source:,image-dir:,control-pkg:,home-project:,build-root:,jail-root:,virsh-uri:,vm-model:,subnet-fixed:,subnet6-fixed:,workspace:,context:,test-parameters:,keep,uninstall:,repo:,extra_repo:,install:,refresh:,nic:,disk:,model:,subnet:,subnet6:,dhcp:,gateway:" \
              -- "$@")
if [ $? -ne 0 ]; then
  basiliqa-vms-help >&2
  exit 1
fi
eval set -- "$ARGS"

action="run"
while true; do
  case "$1" in
    -h|--help)
      shift
      action="help"
      ;;
    -l|--local)
      shift
      export BUILD_ROOT="/var/tmp/build-root"
      ;;
    -j|--jail)
      shift
      export JAIL_ROOT="$HOME/jail"
      ;;
    -v|--virtio)
      shift
      export TARGET_TYPE="virtio"
      ;;
    -i|--image)
      shift
      node="${1%=*}"
      image="${1#*=}"
      shift
      eval "export IMAGE_NAME_${node^^}='$image'"
      ;;
    -s|--image-source)
      shift
      export IMAGE_SOURCE="$1"
      shift
      ;;
    -d|--image-dir)
      shift
      export IMAGE_DIR="$1"
      shift
      ;;
    -c|--control-pkg)
      shift
      export CONTROL_PKG="$1"
      shift
      ;;
    -p|--home-project)
      shift
      export HOME_PROJECT="$1"
      shift
      ;;
    -b|--build-root)
      shift
      export BUILD_ROOT="$1"
      shift
      ;;
    -r|--jail-root)
      shift
      export JAIL_ROOT="$1"
      shift
      ;;
    -u|--virsh-uri)
      shift
      export VIRSH_DEFAULT_CONNECT_URI="$1"
      shift
      ;;
    -m|--vm-model)
      shift
      export VM_MODEL="$1"
      shift
      ;;
    -f|--subnet-fixed)
      shift
      export SUBNET_FIXED="$1"
      shift
      ;;
    -g|--subnet6-fixed)
      shift
      export SUBNET6_FIXED="$1"
      shift
      ;;
    -w|--workspace)
      shift
      export WORKSPACE="$1"
      shift
      ;;
    -x|--context)
      shift
      export EXECUTION_CONTEXT="$1"
      shift
      ;;
    -t|--test-parameters)
      shift
      export TEST_PARAMETERS="$1"
      shift
      ;;
    -K|--keep)
      shift
      export KEEP_IF_SUCCESS="yes"
      ;;
    -U|--uninstall)
      shift
      node="${1%=*}"
      packages="${1#*=}"
      shift
      eval "export UNINSTALL_${node^^}='$packages'"
      ;;
    -R|--repo)
      shift
      node="${1%=*}"
      urls="${1#*=}"
      shift
      eval "export REPO_${node^^}='$urls'"
      ;;
    -X|--extra-repo)
      shift
      node="${1%=*}"
      urls="${1#*=}"
      shift
      eval "export EXTRA_REPO_${node^^}='$urls'"
      ;;
    -I|--install)
      shift
      node="${1%=*}"
      packages="${1#*=}"
      shift
      eval "export INSTALL_${node^^}='$packages'"
      ;;
    -A|--refresh)
      shift
      node="${1%=*}"
      yesorno="${1#*=}"
      shift
      eval "export REFRESH_${node^^}='$yesorno'"
      ;;
    -N|--nic)
      shift
      node="${1%=*}"
      networks="${1#*=}"
      shift
      eval "export NIC_${node^^}='$networks'"
      ;;
    -V|--disk)
      shift
      node="${1%=*}"
      sizes="${1#*=}"
      shift
      eval "export DISK_${node^^}='$sizes'"
      ;;
    -M|--model)
      shift
      node="${1%=*}"
      flavor="${1#*=}"
      shift
      eval "export MODEL_${node^^}='$flavor'"
      ;;
    -S|--subnet)
      shift
      network="${1%=*}"
      cidr="${1#*=}"
      shift
      eval "export SUBNET_${network^^}='$cidr'"
      ;;
    -6|--subnet6)
      shift
      network="${1%=*}"
      cidr6="${1#*=}"
      shift
      eval "export SUBNET6_${network^^}='$cidr6'"
      ;;
    -D|--dhcp)
      shift
      network="${1%=*}"
      yesorno="${1#*=}"
      shift
      eval "export DHCP_${network^^}='$yesorno'"
      ;;
    -G|--gateway)
      shift
      network="${1%=*}"
      yesorno="${1#*=}"
      shift
      eval "export GATEWAY_${network^^}='$yesorno'"
      ;;
    --)
      shift;
      break;
      ;;
    *)
      basiliqa-vms-help >&2
      exit 1
      ;;
  esac
done

case $action in
  help)
    if [ $# -ne 0 ]; then
      basiliqa-vms-help >&2
      exit 1
    fi
    basiliqa-vms-help
    ;;
  run)
    if [ $# -ne 1 ]; then
      basiliqa-vms-help >&2
      exit 1
    fi
    export PROJECT_NAME="$1"
    /usr/lib/basiliqa/vms/run-tests-in-vms.sh
esac

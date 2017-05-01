#! /bin/bash
#
# basiliqa-query.sh
# Various queries around basiliQA

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

function basiliqa-query-help
{
  cat <<ENDHELP
Syntax:
basiliqa-query.sh
    -h|--help

basiliqa-query.sh
    [-s|--image-source <image-url>]
    [-j|--jail]  | [-r|--jail-root <jail-root-directory>]
    -i|--images

basiliqa-query.sh
    [-j|--jail]  | [-r|--jail-root <jail-root-directory>]
    -e|--external-ip <testsuite>[-<context>] <node>

ENDHELP
}

function get-external-ip
{
  local testsuite="$1"
  local node="$2"
  local conf

  if [ "$JAIL_ROOT" = "none" ]; then
    conf=$(cat "/etc/basiliqa/basiliqa.conf")
  else
    conf=$(sudo systemd-nspawn -q -D "$JAIL_ROOT" cat "/etc/basiliqa/basiliqa.conf")
  fi

  WORKSPACE_ROOT=$(echo "$conf" | \
    xmllint --xpath "string(/basiliqa-conf/directories/@workspace-root)" -)

  echo "External IP for node $node of suite $testsuite:"
  echo
  if [ "$JAIL_ROOT" = "none" ]; then
    testenv -f "$WORKSPACE_ROOT/$testsuite/testenv.xml" "node:external-ip" "$node"
  else
    sudo systemd-nspawn -q -D "$JAIL_ROOT" testenv -f "$WORKSPACE_ROOT/$testsuite/testenv.xml" "node:external-ip" "$node"
  fi
  echo
}

function list-available-images
{
  local conf
  local list

  if [ "$JAIL_ROOT" = "none" ]; then
    conf=$(cat "/etc/basiliqa/basiliqa.conf")
  else
    conf=$(sudo systemd-nspawn -q -D "$JAIL_ROOT" cat "/etc/basiliqa/basiliqa.conf")
  fi

  if [ "$IMAGE_SOURCE" = "" ]; then
    IMAGE_SOURCE=$(echo "$conf" | \
      xmllint --xpath "string(/basiliqa-conf/images/@source)" -)
  fi

  if [[ "$IMAGE_SOURCE" =~ ^http: ]]; then
    list=$(wget -q -O - "$IMAGE_SOURCE/images.list")
  else
    if [ "$JAIL_ROOT" = "none" ]; then
      list=$(cat "$IMAGE_SOURCE/images.list")
    else
      list=$(sudo systemd-nspawn -q -D "$JAIL_ROOT" cat "$IMAGE_SOURCE/images.list" | tr -d '\r')
    fi
  fi

  echo
  echo "Images converted from ISO images:"
  echo
  echo "$list" | awk '/^-/ {gsub(".qcow2", ""); print $3 "\t(" $2 ")"}'
  echo
  echo "Hidden images:"
  echo
  echo "$list" | awk '/^H/ {gsub(".qcow2", ""); print $3 "\t(" $2 ")"}'
  echo
}

# Default values
export JAIL_ROOT=$(xmllint --xpath "string(/basiliqa-conf/directories/@jail-root)" /etc/basiliqa/basiliqa.conf)
export CONTROL_PKG="tests-control"
export TARGET_TYPE="ssh"

# Parse arguments
ARGS=$(getopt -o "heijs:r:" \
              --long "help,external-ip,images,jail,image-source:,jail-root:" \
              -- "$@")
if [ $? -ne 0 ]; then
  basiliqa-query-help >&2
  exit 1
fi
eval set -- "$ARGS"

action="help"
while true; do
  case "$1" in
    -h|--help)
      shift
      action="help"
      ;;
    -e|--external-ip)
      shift
      action="externalip"
      ;;
    -i|--images)
      shift
      action="images"
      ;;
    -j|--jail)
      shift
      export JAIL_ROOT="$HOME/jail"
      ;;
    -s|--image-source)
      shift
      export IMAGE_SOURCE="$1"
      shift
      ;;
    -r|--jail-root)
      shift
      export JAIL_ROOT="$1"
      shift
      ;;
    --)
      shift;
      break;
      ;;
    *)
      basiliqa-query-help >&2
      exit 1
      ;;
  esac
done

case $action in
  help)
    if [ $# -ne 0 ]; then
      basiliqa-query-help >&2
      exit 1
    fi
    basiliqa-query-help
    ;;
  externalip)
    if [ $# -ne 2 ]; then
      basiliqa-query-help >&2
      exit 1
    fi
    get-external-ip "$1" "$2"
    ;;
  images)
    if [ $# -ne 0 ]; then
      basiliqa-query-help >&2
      exit 1
    fi
    list-available-images
    ;;
esac

#! /bin/bash
#
# basiliqa-static.sh
# Convenience wrapper for run-tests-in-static-environment.sh

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

function basiliqa-static-help
{
  cat <<ENDHELP
Syntax:
basiliqa-static.sh
    -h|--help

basiliqa-static.sh
    [ <optional parameters> ]
    -e|--test-environment <environment-file>

basiliqa-static.sh
    [ <optional parameters> ]
    <project-name>

Optional parameters:
    [-c|--control-pkg <control-package>]
    [-j|--jail]  | [-r|--jail-root <jail-root-directory>]
    [-w|--workspace <workspace-directory>]
    [-t|--test-parameters <parameters>]
ENDHELP
}

ARGS=$(getopt -o "hjc:e:r:w:p:" \
              --long "help,jail,control-pkg:,test-environment:,jail-root:,workspace:,export:" \
              -- "$@")
if [ $? -ne 0 ]; then
  basiliqa-static-help >&2
  exit 1
fi
eval set -- "$ARGS"

# Default values
export CONTROL_PKG="tests-control"

action="by-project-name"
while true; do
  case "$1" in
    -h|--help)
      shift
      action="help"
      ;;
    -j|--jail)
      shift
      export JAIL_ROOT="$HOME/jail"
      ;;
    -c|--control-pkg)
      shift
      export CONTROL_PKG="$1"
      shift
      ;;
    -e|--test-environment)
      shift
      action="by-env-file"
      export TESTENV_FILE="$1"
      shift
      ;;
    -r|--jail-root)
      shift
      export JAIL_ROOT="$1"
      shift
      ;;
    -w|--workspace)
      shift
      export WORKSPACE="$1"
      shift
      ;;
    -t|--test-parameters)
      shift
      export TEST_PARAMETERS="$1"
      shift
      ;;
    --)
      shift;
      break;
      ;;
    *)
      basiliqa-static-help >&2
      exit 1
      ;;
  esac
done

case $action in
  help)
    if [ $# -ne 0 ]; then
      basiliqa-static-help >&2
      exit 1
    fi
    basiliqa-static-help
    ;;
  by-env-file)
    if [ $# -ne 0 ]; then
      basiliqa-static-help >&2
      exit 1
    fi
    /usr/lib/basiliqa/static/run-tests-in-static-environment.sh
    ;;
  by-project-name)
    if [ $# -ne 1 ]; then
      basiliqa-static-help >&2
      exit 1
    fi
    export PROJECT_NAME="$1"
    /usr/lib/basiliqa/static/run-tests-in-static-environment.sh
esac

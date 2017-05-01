#! /bin/bash
#
# do-tests-in-static-environment.sh
# Run a set of tests in a static environment - do the real job, in a jail or not

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

# Input is taken from environment variables:
#
#   Variable                   Example value
#
#   TESTENV_FILE               /var/tmp/basiliqa/workspace/tests-helloworld/testenv.xml
#
#   PROJECT_NAME               tests-helloworld
#   CONTROL_PKG                tests-control
#   TEST_PARAMETERS            TEST_PRECISE,FAST
#
#   WORKSPACE_ROOT             /var/tmp/basiliqa/workspace
#   WORKSPACE                  /var/tmp/basiliqa/workspace/tests-helloworld
#
# The following variable, if omitted, will be taken from defaults
# in /etc/basiliqa/basiliqa.conf:
#
#   WORKSPACE_ROOT
#
# The following variables, if omitted, will be computed from other
# variables:
#
#   TESTENV_FILE
#   WORKSPACE

source $(dirname "$0")/../lib/basiliqa-basic-functions.sh
source $(dirname "$0")/../lib/basiliqa-functions.sh

##############################################################

# Get default values
get-default "WORKSPACE_ROOT" "directories/@workspace-root"

# Read static test setup from testenv.xml
scripts=$(dirname "$0")
if [ -z "$TESTENV_FILE" ]; then
  if [ -z "$WORKSPACE" ]; then
    check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
    check-value "PROJECT_NAME" "$PROJECT_NAME"
    export WORKSPACE="$WORKSPACE_ROOT/$PROJECT_NAME"
  fi
  export TESTENV_FILE="$WORKSPACE/testenv.xml"
fi
eval $(xsltproc $scripts/testenv.xslt $TESTENV_FILE)

# Guess missing arguments
if [ -z "$WORKSPACE" ]; then
  check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
  check-value "PROJECT_NAME" "$PROJECT_NAME"
  export WORKSPACE="$WORKSPACE_ROOT/$PROJECT_NAME"
fi
if [ -z "$REPORT" ]; then
  export REPORT="$WORKSPACE/junit-results.xml"
fi

# Check mandatory and semi-mandatory arguments
check-value "CONTROL_PKG" "$CONTROL_PKG"
check-value "PROJECT_NAME" "$PROJECT_NAME"

# Create workspace if needed
echo "Creating workspace in $WORKSPACE if needed"
create-workspace
echo

# Prepare log files
echo "Preparing log files"
LOGFILE="${WORKSPACE}/junit-results.log"
rm -f "$REPORT" "$LOGFILE"
touch "$LOGFILE"
echo

# Nodes preparations
for node_name in $NODES; do
  echo "Preparations for node $node_name"
  node=${node_name^^}
  eval "target=\"\$TARGET_$node\""
  eval "internal_ip=\"\$INTERNAL_IP_$node\""
  eval "external_ip=\"\$EXTERNAL_IP_$node\""

  # Guess missing target
  if [ "$target" = "" ]; then
    if [ "$external_ip" != "" ]; then
      target="ssh:$external_ip"
      eval "export TARGET_$node=\"$target\""
    elif [ "$internal_ip" != "" ]; then
      target="ssh:$internal_ip"
      eval "export TARGET_$node=\"$target\""
    else
      echo "Please define at least target, external IP or internal IP for node $node_name" >&2
      exit 2
    fi
  fi
  TARGET="$target"

  # Guess missing IPv4 addresses
  if [ "$internal_ip" = "" -a "$external_ip" != "" ]; then
    internal_ip="$external_ip"
    eval "export INTERNAL_IP_$node=\"$internal_ip\""
  elif [ "$external_ip" = "" -a "$internal_ip" != "" ]; then
    external_ip="$internal_ip"
    eval "export EXTERNAL_IP_$node=\"$external_ip\""
  elif [ "$internal_ip" = "" -a "$external_ip" = "" ]; then
    if [ "${target%:*}" = "ssh" ]; then
      internal_ip="${target#ssh:}"
      eval "export INTERNAL_IP_$node=\"$internal_ip\""
      external_ip="${target#ssh:}"
      eval "export EXTERNAL_IP_$node=\"$external_ip\""
    else
      echo "Can't guess internal IP and external IP from non-SSH target" >&2
      exit 2
    fi
  fi

  # Display system information
  echo "Trying to get system information for target $TARGET"
  get-system-information
  echo
done

# Get the tests table
TESTS_DIR="/var/lib/basiliqa/${PROJECT_NAME}/${CONTROL_PKG}/bin"
declare -a TESTS_TABLE
echo "Trying to read tests table"
get-tests-table
echo

# Prepare failures file
FAILURES="${WORKSPACE}/failed.txt"
rm -f "$FAILURES"
touch "$FAILURES"

# Run one test after the other
for current_test in ${TESTS_TABLE[@]}; do
  echo "Trying to run test ${current_test}"
  run-tests $current_test
  echo
done

# Check for failures
echo "Checking for failed tests"
check-failures
echo

# Finish log files
echo "Finishing log files"
finish-logs
echo

echo "SUCCESS"
echo

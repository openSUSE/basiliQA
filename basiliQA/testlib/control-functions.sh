#! /bin/bash
#
# control-functions.sh
# Bash helper library for basiliQA testsuites on the control node.

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

# Usage: source /usr/lib/basiliqa/testlib/helper-functions.sh
#
# Functions:
#   jlogger()    Produce junit XML output
#   run_test()   Run a test on a SUT
#   ssh_access() Copy SSH keys from a SUT onto other SUTs

###############################################################################

# jlogger_usage()
#
# (internal use only)
function jlogger_usage
{
  echo "Usage:" >&2
  echo "" >&2
  echo "  jlogger testsuite [-i <identifier>] [-t <text>] [-h <hostname>]" >&2
  echo "      start test suite" >&2
  echo "" >&2
  echo "  jlogger endsuite" >&2
  echo "      end test suite" >&2
  echo "" >&2
  echo "  jlogger testcase [-i <identifier>] [-t <text>]" >&2
  echo "      start test case" >&2
  echo "" >&2
  echo "  jlogger success" >&2
  echo "      end succesful test case" >&2
  echo "" >&2
  echo "  jlogger skipped" >&2
  echo "      skips test that is not suitable for configuration/machine" >&2
  echo "" >&2
  echo "  jlogger failure [-T <type>] [-t <text>]" >&2
  echo "      end failed test case" >&2
  echo "" >&2
  echo "  jlogger error [-T <type>] [-t <text>]" >&2
  echo "      end test case aborted due to internal error" >&2
  echo "" >&2
}

# jlogger()
#
# Produce junit XML output
#
# Syntax:
#   jlogger testsuite [-i <identifier>] [-t <text>] [-h <hostname>]
#   jlogger endsuite
#   jlogger testcase [-i <identifier>] [-t <text>]
#   jlogger success
#   jlogger failure [-T <type>] [-t <text>]
#   jlogger error [-T <type>] [-t <text>]
#   jlogger testsuite -t "Testing the calculator functions"
#
# Usage example:
#   jlogger testcase -t "verify addition"
#   jlogger success
#   jlogger testcase -t "verify division"
#   jlogger failure -T "Segmentation failure"
#   jlogger endsuite
function jlogger
{
  TIME=$(date +%Y-%m-%dT%H:%M:%S.%N | cut -c 1-23)
  OUT="###junit $1 time=\"$TIME\""

  case "$1" in
    "testsuite")
      OPTIND=2
      while getopts "i:t:h:" OPT; do
        case "$OPT" in
          "i")
            OUT="$OUT id=\"$OPTARG\""
            ;;
          "t")
            OUT="$OUT text=\"$OPTARG\""
            ;;
          "h")
            OUT="$OUT host=\"$OPTARG\""
            ;;
          *)
            jlogger_usage
            exit 1
        esac
      done
      shift $((OPTIND-1))
      ;;
    "testcase")
      OPTIND=2
      while getopts "i:t:" OPT; do
        case "$OPT" in
          "i")
            OUT="$OUT id=\"$OPTARG\""
            ;;
          "t")
            OUT="$OUT text=\"$OPTARG\""
            ;;
          *)
            jlogger_usage
            exit 1
        esac
      done
      shift $((OPTIND-1))
      ;;
    "endsuite"|"success"|"skipped")
      shift
      ;;
    "failure"|"error")
      OPTIND=2
      while getopts "T:t:" OPT; do
        case "$OPT" in
          "T")
            OUT="$OUT type=\"$OPTARG\""
            ;;
          "t")
            OUT="$OUT text=\"$OPTARG\""
            ;;
          *)
            jlogger_usage
            exit 1
        esac
      done
      shift $((OPTIND-1))
      ;;
    *)
      jlogger_usage
      exit 1
  esac

  if [ $# -ne 0 ]; then
    jlogger_usage
    exit 1
  fi

  echo $OUT
}

###############################################################################

# run_test()
#
# Run a test on a SUT
#
# Syntax:
#   run_test <suite> <label> <user> <timeout> <target> <command>
#
# Usage example:
#   jlogger testsuite
#   run_test configure_basics \
#            root 300 $TARGET_SERVER \
#            "cd $suite && ./01_configure_basics.sh $INTERNAL_IP_SERVER"
#   if [ $? -ne 0 ] ...
#   run_test create_certificate \
#            root 300 $TARGET_SERVER \
#            "cd $suite && ./02_create_certificate.sh"
#   if [ $? -ne 0 ] ...
#   jlogger endsuite
#
run_test()
{
  local label="$1"
  local user="$2"
  local timeout="$3"
  local target="$4"
  local cmd="$5"

  local testrc

  # Start test case
  jlogger testcase -i "$label"

  # Run command
  twopence_command -b \
    -u "$user" -t "$timeout" "$target" \
    "$cmd"
  testrc=$?

  # End test case
  if [ $testrc -eq 0 ]; then
    jlogger success
  else
    jlogger failure
  fi

  return $testrc
}

###############################################################################

# ssh_access()
#
# Copy SSH keys from a SUT onto other SUTs
#
# Syntax:
#   ssh_access <src_user> <src_node> [<dst_user> <dst_node>]...
#
# Usage example:
#   ssh_access root client root server
#   [ $? -eq 0 ] || exit 1
#
ssh_access()
{
  # Prefer Jenkins project workspace if available
  if [ "$WORKSPACE" == "" ]; then
    echo "No Jenkins workspace, using /tmp" >&2
    WORKSPACE=/tmp
  fi

  # Check source user and node
  src_user="$1"
  [ "$src_user" == "" ] && return 1
  shift
  src_node="${1^^}"
  [ "$src_node" == "" ] && return 1
  shift

  # Derive source IP and twopence target
  eval "src_ip=\$INTERNAL_IP_${src_node}"
  if [ "$src_ip" == "" ]; then
    echo "\$INTERNAL_IP_${src_node} is undefined" >&2
    return 1
  fi
  eval "src_target=\$TARGET_${src_node}"
  if [ "$src_target" == "" ]; then
    echo "\$TARGET_IP_${src_node} is undefined" >&2
    return 1
  fi

  # Generate the keypair
  twopence_command -b $src_target -u $src_user \
    "[ -f .ssh/id_rsa.pub ] || ssh-keygen -t rsa -C ${src_user}@${src_ip} -N '' -f .ssh/id_rsa"
  if [ $? -ne 0 ]; then
    echo "Could not generate key pair for ${src_node}" >&2
    return 2
  fi

  # Extract the public key from source
  twopence_extract $src_target -u $src_user \
    .ssh/id_rsa.pub ${WORKSPACE}/id_rsa_pub
  if [ $? -ne 0 ]; then
    echo "Could not extract public key from ${src_node}" >&2
    return 3
  fi

  while [ $# -gt 0 ]; do
    # Check destination user and node
    dest_user="$1"
    if [ "$dest_user" == "" ]; then
      echo "Syntax error" >&2
      return 1
    fi
    shift
    dest_node="${1^^}"
    if [ "$dest_node" == "" ]; then
      echo "Syntax error" >&2
      return 1
    fi
    shift

    # Derive destination twopence target
    eval "dest_target=\$TARGET_${dest_node}"
    if [ "$dest_target" == "" ]; then
      echo "\$TARGET_${dest_node} is undefined" >&2
      return 1
    fi

    # Inject public key into destination
    twopence_inject  $dest_target -u $dest_user ${WORKSPACE}/id_rsa_pub id_rsa_pub
    if [ $? -ne 0 ]; then
      echo "Failed to inject key to ${dest_node}" >&2
      return 4
    fi

    # Install it
    twopence_command -b $dest_target -u $dest_user \
      "cat .ssh/authorized_keys id_rsa_pub > ak && mv ak .ssh/authorized_keys"
    if [ $? -ne 0 ]; then
      echo "Failed to install key on ${dest_node}" >&2
      return 5
    fi
  done

  # Do some cleanup
  rm ${WORKSPACE}/id_rsa_pub
  return 0
}


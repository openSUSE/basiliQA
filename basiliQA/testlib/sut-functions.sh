#! /bin/bash
#
# sut-functions.sh
# Bash helper library for basiliQA testsuites on the SUT nodes.

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


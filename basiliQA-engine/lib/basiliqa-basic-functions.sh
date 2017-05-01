# basiliqa-basic-functions.sh
# basiliQA shell basic utility functions (sourced)

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

##############################################################
function get-default
{
  local name="$1"
  local xpath="$2"

  local conf="/etc/basiliqa/basiliqa.conf"
  local value

  if [ -z "$(eval echo \$$name)" ]; then
    value=$(xmllint --xpath "string(/basiliqa-conf/$xpath)" $conf)
    eval "export $name=\"$value\""
  fi
}

##############################################################
function channel-count
{
  local conf="/etc/basiliqa/channels.conf"

  xmllint --xpath "count(/channels-conf/channel)" $conf
}

##############################################################
function channel-info
{
  local xpath="$1"
  local arch="$2"

  local conf="/etc/basiliqa/channels.conf"
  local value

  value=$(xmllint --xpath "string(/channels-conf/$xpath)" $conf)
  echo "${value//@@ARCH@@/$arch}"
}

##############################################################
function check-value
{
  local name="$1"
  local value="$2"

  if [ -z "$value" ]; then
    echo "Please define ${name}" >&2
    exit 1
  fi
}

##############################################################
function run-in-jail
{
  local to_run="$1"
  local vars="$2"

  local wrapper_dir="/var/tmp/basiliqa/jailed_runs"
  local wrapper_script="$wrapper_dir/$$.sh"

  local var

  mkdir -p $JAIL_ROOT/$wrapper_dir
  rm -f $JAIL_ROOT/$wrapper_script

  for vars in $vars; do
    env | grep "^$vars=" | while read -r var; do \
      name="${var%=*}"; \
      value="${var#*=}"; \
      echo "export $name='$value'" >> $JAIL_ROOT/$wrapper_script; \
    done
  done

  echo >> $JAIL_ROOT/$wrapper_script
  echo "$to_run" >> $JAIL_ROOT/$wrapper_script
  chmod +x $JAIL_ROOT/$wrapper_script

  sudo systemd-nspawn -D "$JAIL_ROOT" -M "jail$$" \
    su - basiliqa -c "$wrapper_script"
}

##############################################################

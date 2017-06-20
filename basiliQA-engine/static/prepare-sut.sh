#! /bin/bash
#
# prepare-sut.sh
# Script to prepare a system under tests in case of a static setup

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

if [ $# -ne 2 ]; then
  echo "Syntax: $0 <ip-address-of-SUT> <system-family>" >&2
  echo "Example: $0 1.2.3.4 openSUSE_42.3" >&2
  exit 1
fi
host="$1"
family="$2"

echo
echo "               THIS SCRIPT IS DANGEROUS"
echo
echo "It will allow anyone to connect to the system under tests as root."
echo
echo "Run it only on throwable test machines."
echo "Don't run it on any system used for any other task."
echo
echo "Are you sure you want to continue?"
read -p "Type 'yes' if you don't mind this machine to become unsafe. " conf
if [ "$conf" != "yes" ]; then
  echo "Giving up."
  exit 0
fi
echo

scripts=$(dirname $0)
key=$(cat $scripts/jenkins_id_rsa.pub)
script=$(cat <<EOF

echo "Creating 'testuser' user"
useradd -m "testuser"

echo "Adding public key for tests to testuser's authorized keys"
if [ ! -d /home/testuser/.ssh ]; then
  mkdir /home/testuser/.ssh
  chown testuser: /home/testuser/.ssh
  chmod go-rwx /home/testuser/.ssh
fi
echo "$key" >> /home/testuser/.ssh/authorized_keys
echo

echo "Changing testuser's password to 'opensuse'"
chpasswd <<< "testuser:opensuse"
echo

echo "Adding public key for tests to root's authorized keys"
if [ ! -d /root/.ssh ]; then
  mkdir -p /root/.ssh
  chmod go-rwx /root/.ssh
fi
echo "$key" >> /root/.ssh/authorized_keys
echo

echo "Changing root's password to 'opensuse'"
chpasswd <<< "root:opensuse"
echo

echo "Adding repository for basiliQA testsuites"
zypper --non-interactive ar http://download.opensuse.org/repositories/basiliQA:/testsuites/$family/basiliQA:testsuites.repo
zypper --non-interactive --gpg-auto-import-keys ref
echo

echo "Done."
EOF
)

ssh "root@$host" "$script"

#! /bin/bash
#
# setup.sh
# basiliQA image importer
# Install openssh and add basiliQA users on a Windows image

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

# This script is meant to be run from the powershell script
#
# Note: command-line argument given to a DOS program that uses "/" must
# be doubled because msys2 thinks they are paths and converts them

set -e

function set-owner() {
    local path="$(cygpath -w "$2")"
    powershell '$user="'"$1"'";$path="'"$path"'";$u = new-object -typename System.Security.Principal.NTAccount -ArgumentList $user;$acl = get-acl -path $path;$acl.SetOwner($u);set-acl -path $path -aclobject $acl'
}

# disable firewall
netsh advfirewall set allprofiles state off

pacman -S --force --noconfirm openssh cygrunsrv mingw-w64-x86_64-editrights

# change password restriction *before* running ssh setup script as the
# random pw is sometimes not deemed complex enough

secedit //export //cfg sec.cfg
# cannot use sed here as sec.cfg is in UTF-16
powershell 'cat sec.cfg | % { $_ -replace "PasswordComplexity = 1", "PasswordComplexity = 0" } > secnew.cfg'
secedit //configure //db 'C:\Windows\security\new.sdb' //cfg secnew.cfg //areas SECURITYPOLICY
rm sec.cfg secnew.cfg

bash ./msys2openssh.sh

# add 2 basiliqa users
net user root opensuse //add
net user testuser opensuse //add
net localgroup administrators root //add

# update administrator pw
net user administrator opensuse

# add pubkey auth for everyone
for u in administrator root testuser; do
    mkdir -p /home/$u/.ssh
    echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDimm3q0ZopDC4Qm+NF3kpNbD6759KP1FlintutW05YCur0KmPYU3YfQ4pVtYpR0VXDx7oBF3vPXkV0GhVgRwTQResATNUW9l7MnUYjhnetcvb/NZFMxEJQmsTd1MFaX9qtIIGf9iJ0s2rudgoYI2KyZjR0Td+Zw1dtv3FAeFhtx0YgMA2JpJ3ZiJ18fmWMaKH/GlBnsvYaCe9jS8O4D8tZxsVA+JuVMj9wVC5xiscMpmyju4Rha3tggbnLU6XfAXTT0kb4x0xqj5DysA8UxGoe/nL3NSFUj6a+Ssfs45t5y5r8CzrEsxRr/La1jX/D0bntt8eh5m0qAwUSsVvTPxMB jenkins@sibelius' > /home/$u/.ssh/authorized_keys
    set-owner $u /home/$u
    set-owner $u /home/$u/.ssh
    set-owner $u /home/$u/.ssh/authorized_keys
done

# fix errors on ssh user login
touch /var/log/lastlog
icacls /dev/shm //grant Users:F
icacls /dev/mqueue //grant Users:F

echo "Some ignoreable errors might have been printed"
echo "sshd should work (but you know.. try anyway)"

#! /bin/bash
#
# init-jail.sh
# Prepare container for testing locally with basiliqa

# Copyright (C) 2015,2016,2017 The basiliQA developers
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

# Syntax: init-jail.sh --help | --cloud | --local | --delete-cloud | --delete-local
#                      [ --with-importer ]
#                      [ --with-cucumber ]
#                      [ <jail-directory> ]

function finish
{
  if [ "$error" = "true" ]; then
    echo >&2
    echo "===========================================" >&2
    echo "|                                         |" >&2
    echo "| THE INSTALLATION OF THE JAIL HAS FAILED |" >&2
    echo "|                                         |" >&2
    echo "===========================================" >&2
    echo >&2
  fi
}

###############

function help
{
  echo "Syntax: $0"
  echo "           --help | --cloud | --local | --delete-cloud | --delete-local"
  echo "           [ <jail-directory> ]"
  echo
  echo "With --cloud or --local:"
  echo "           [ --with-importer ]"
  echo "           [ --with-cucumber ]"
}

###############

function create-jail
{
  # create jail directory
  if [ -d $jail ]; then
    echo "The jail already exists. Please use --delete-cloud or --delete-local to remove it" >&2
    exit 2
  fi
  echo "Installing basiliQA jail in $jail"
  echo
  mkdir $jail || exit 3

  # prepare user and group files
  sudo mkdir $jail/etc || exit 3
  sudo cp $scripts/etc_group $jail/etc/group || exit 3
  sudo cp $scripts/etc_passwd $jail/etc/passwd || exit 3
  sudo sed -i "s:@ID@:$(id -u):" $jail/etc/passwd || exit 3

  # add optional repos
  if [ "$with_cucumber" = "yes" ]; then
    sudo zypper --root $jail addrepo http://download.opensuse.org/basiliQA:/ruby/openSUSE_Leap_42.2/Devel:basiliQA:ruby.repo || exit 3
  fi

  # add normal repos
  sudo zypper --root $jail addrepo http://download.opensuse.org/distribution/leap/42.2/repo/oss/ repo-oss || exit 3
  sudo zypper --root $jail modifyrepo --priority 98 repo-oss || exit 3
  sudo zypper --root $jail addrepo http://download.opensuse.org/distribution/leap/42.2/repo/non-oss/ repo-non-oss || exit 3
  sudo zypper --root $jail modifyrepo --priority 98 repo-non-oss || exit 3
  sudo zypper --root $jail addrepo http://download.opensuse.org/update/leap/42.2/oss/openSUSE:Leap:42.2:Update.repo || exit 3
  sudo zypper --root $jail modifyrepo --priority 97 openSUSE_Leap_42.2_Update || exit 3
  sudo zypper --root $jail addrepo http://download.opensuse.org/update/leap/42.2/non-oss/openSUSE:Leap:42.2:NonFree:Update.repo || exit 3
  sudo zypper --root $jail modifyrepo --priority 97 openSUSE_Leap_42.2_NonFree_Update || exit 3
  # Temporary: the two repositories below will move ###
  sudo zypper --root $jail addrepo http://download.opensuse.org/repositories/home:/ebischoff:/basiliQA/openSUSE_Leap_42.2/home:ebischoff:basiliQA.repo || exit 3
  sudo zypper --root $jail modifyrepo --priority 96 home_ebischoff_basiliQA || exit 3
  sudo zypper --root $jail addrepo http://download.opensuse.org/repositories/home:/ebischoff:/basiliQA:/testsuites/openSUSE_Leap_42.2/home:ebischoff:basiliQA:testsuites.repo || exit 3
  sudo zypper --root $jail modifyrepo --priority 95 home_ebischoff_basiliQA_testsuites || exit 3
  # End of temporary ##################################
  if [ "$type" = "cloud" ]; then
    sudo zypper --root $jail addrepo -t yast2 http://download.opensuse.org/repositories/Cloud:/OpenStack:/Master/openSUSE_Leap_42.2/Cloud:OpenStack:Master.repo || exit 3
    sudo zypper --root $jail modifyrepo --priority 94 Cloud_OpenStack_Master || exit 3
  fi

  # refresh packages list
  sudo zypper --root $jail --gpg-auto-import-keys refresh || exit 3
  sudo mkdir $jail/etc/products.d
  sudo ln -s $jail/etc/products.d/openSUSE.prod $jail/etc/products.d/baseproduct

  # install packages
  sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses zypper || exit 3
  sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses timezone sudo iputils wget libxslt-tools libxml2-tools || exit 3
  sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses libvirt-client qemu-tools || exit 3
  sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses man vim openssh tar psmisc || exit 3
  sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses basiliqa susetest-python $pkg || exit 3
  if [ "$with_cloud" = "yes" ]; then
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses python-os-client-config || exit 3
  fi
  if [ "$with_importer" = "yes" ]; then
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses btrfsprogs saxon9 java-1_7_1-ibm expect || exit 3
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses basiliqa-engine-image-importer || exit 3
  fi
  if [ "$with_cucumber" = "yes" ]; then
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses ruby2.1-rubygem-cucumber || exit 3
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses ruby2.1-rubygem-rspec || exit 3
    sudo zypper --root $jail --non-interactive install --auto-agree-with-licenses rubygem-twopence || exit 3
  fi

  # post-installation fixes
  sudo ln -sf /etc/products.d/SLES.prod $jail/etc/products.d/baseproduct
  sudo cp $scripts/etc_sudoers $jail/etc/sudoers || exit 3
  sudo cp $scripts/etc_os_release $jail/etc/os-release || exit 3
  sudo sed -i "s:qemu\:///system:qemu+tcp\://localhost/system:" $jail/etc/basiliqa/basiliqa.conf || exit 3

  # prepare home for basiliqa user
  sudo chown $USER: $jail/var/lib/basiliqa || exit 3
  if [ "$type" = "local" ]; then
    cp $scripts/bashrc $jail/var/lib/basiliqa/.bashrc || exit 3
    sudo cp $scripts/bashrc $jail/root/.bashrc || exit 3
  fi
  mkdir $jail/var/lib/basiliqa/.ssh || exit 3
  cp $scripts/ssh_id_rsa $jail/var/lib/basiliqa/.ssh/id_rsa || exit 3
  chmod -R go-rwx $jail/var/lib/basiliqa/.ssh || exit 3
  if [ "$with_cloud" = "yes" ]; then
    mkdir $jail/var/lib/basiliqa/.glanceclient || exit 3
  fi

  # share workspace, and in case of local runs, images too
  mkdir -p $shared || exit 3
  sudo mkdir -p $jail$shared || exit 3
  sudo chown $USER: $jail$shared || exit 3
  sudo mount -o bind $jail$shared $shared || exit 3

  # share build directory
  if [ "$type" = "local" ]; then
    mkdir -p $shared2 || exit 3
    sudo mkdir -p $jail$shared2 || exit 3
    sudo chown $USER: $jail$shared2 || exit 3
    sudo mount -o bind $jail$shared2 $shared2 || exit 3
  fi

  # part not done automatically
  if [ "$type" = "local" ]; then
    cat <<EOF

The jail is installed in $jail.

Now please edit /etc/libvirt/libvirtd.conf, and make sure
that the following directives are defined:

    listen_addr = "127.0.0.1"
    listen_tcp = 1
    auth_tcp = "none"

Then restart libvirtd with the command:

    # systemctl restart libvirtd

You should then be able to do:

    # systemd-nspawn -D $jail
    # su - basiliqa
    $ virsh list

At this point, you should see an empty list of virtual machines.
To exit, type:

    $ exit
    # exit

If it works, please also modify /etc/fstab to add:

    $jail$shared   $shared   none   bind,user       0 0
    $jail$shared2   $shared2   none   bind,user       0 0
EOF
  else
    cat <<EOF2

The jail is installed in $jail.

You should be able to do:

    # systemd-nspawn -D $jail
    # su - basiliqa

To exit, type:

    $ exit
    # exit

Please also modify /etc/fstab to add:

    $jail$shared   $shared   none  bind,user       0 0
EOF2
  fi
  if [ "$with_importer" = "yes" ]; then
    cat <<EOF3
  $shared/iso2qcow2/installation.raw  $shared/iso2qcow2/mount         vfat   noauto,loop,user           0 0
EOF3
  fi
  cat <<EOF4

so you do not lose shared directories on next reboot.
EOF4
}

###############

function remove-jail
{
  # security verifications
  if [ ! -d "$jail" ]; then
    echo "The jail $jail does not exist, impossible to remove it" >&2
    exit 2
  fi
  read -p "Are you sure you want to delete ${jail}? " -r
  if [[ $REPLY =~ ^[Yy] ]]; then

    # unmount first shared directory
    echo "Unmounting ${shared}..."
    sudo umount $shared
    if [ $? -ne 0 ]; then
      echo "Unmounting ${shared} failed. Maybe you should check that no VM is currently using it, and restart." >&2
    fi

    # unmount second shared directory
    if [ "$type" = "local" ]; then
      echo "Unmounting ${shared2}..."
      sudo umount $shared2
      if [ $? -ne 0 ]; then
        echo "Unmounting ${shared2} failed. Maybe you should check that no VM is currently using it, and restart." >&2
      fi
    fi

    # remove the files
    echo "Removing $jail"
    sync
    sudo rm -r $jail || exit 3
  fi
}

###############

error="true"
trap finish EXIT

if [ $(id -u) -eq 0 ]; then
  echo "Please run this script as a normal user" >&2
  exit 1
fi

scripts=$(dirname $0)

action=""
type=""
shared=""
shared2=""
pkg=""

with_importer="no"
with_cucumber="no"

jail=$HOME/jail

while [ $# -gt 0 ]; do
  case "$1" in
    --help)             action="help"
                        ;;
    --cloud)            action="create"
                        type="cloud"
                        shared="/var/lib/jenkins/workspace"
                        # this parameter assumes that you set
                        #     ${JENKINS_HOME}/workspace/${ITEM_FULLNAME}
                        # as workspace in Jenkins global configuration
                        shared2=""
                        pkg="basiliqa-engine-cloud"
                        ;;
    --delete-cloud)     action="remove"
                        type="cloud"
                        shared="/var/lib/jenkins/workspace"
                        shared2=""
                        ;;
    --local)            action="create"
                        type="local"
                        shared="/var/tmp/basiliqa"
                        shared2="/var/tmp/build-root"
                        pkg="basiliqa-engine-vms basiliqa-engine-static"
                        ;;
    --delete-local)     action="remove"
                        type="local"
                        shared="/var/tmp/basiliqa"
                        shared2="/var/tmp/build-root"
                        ;;
    --with-importer)    with_importer="yes"
                        ;;
    --with-cucumber)    with_cucumber="yes"
                        ;;
    *)                  jail="$1"
  esac
  shift
done

case "$action" in
  help)   help
          ;;
  create) create-jail
          ;;
  remove) remove-jail
          ;;
  *)      help >&2
          exit 1
esac

error="false"

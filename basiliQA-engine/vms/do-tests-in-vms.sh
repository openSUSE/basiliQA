#! /bin/bash
#
# do-tests-in-vms.sh
# Run a set of tests in Virtual Machines - do the real job, in a jail or not

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
#   PROJECT_NAME               tests-helloworld
#   CONTROL_PKG                tests-control
#   HOME_PROJECT               hmustermann
#   BUILD_ROOT                 /var/tmp/build-root
#   EXECUTION_CONTEXT          patched
#   TEST_PARAMETERS            TEST_PRECISE,FAST
#
#   IMAGE_SOURCE               http://basiliqa.suse.de/images/
#   IMAGE_NAME_<node>          openSUSE_42.3-x86_64-default  (for each node)
#
#   WORKSPACE_ROOT             /var/tmp/basiliqa/workspace
#   IMAGE_DIR                  /var/tmp/basiliqa/images
#
#   TARGET_TYPE                ssh
#   VIRSH_DEFAULT_CONNECT_URI  qemu:///system
#   VM_MODEL                   m1.smaller
#   SUBNET_FIXED               192.168.15.0/24
#   SUBNET6_FIXED              fc00:0:0:f::/64
#   REMOTE_VIRT_HOST           1.2.3.4
#   REMOTE_VIRT_USER           basiliqa
#   REMOTE_DHCP_HOST           1.2.3.4
#   REMOTE_DHCP_USER           basiliqa
#
#   WORKSPACE                  /var/tmp/basiliqa/workspace/tests-helloworld
#
#   There are also variables to override node file settings.
#   Refer to documentation for those ones.
#
# The following variables, if omitted, will be taken from defaults
# in /etc/basiliqa/basiliqa.conf:
#
#   IMAGE_SOURCE,
#   WORKSPACE_ROOT, IMAGE_DIR,
#   VIRSH_DEFAULT_CONNECT_URI, VM_MODEL, SUBNET_FIXED, SUBNET6_FIXED,
#   REMOTE_VIRT_HOST, REMOTE_VIRT_USER, REMOTE_DHCP_HOST, REMOTE_DHCP_USER
#
# The following variable, if omitted, will be computed from other
# variables:
#
#   WORKSPACE

source $(dirname "$0")/../lib/basiliqa-basic-functions.sh
source $(dirname "$0")/../lib/basiliqa-functions.sh

##############################################################
function unique-mac-address
{
  # We use /dev/urandom and just hope we don't draw same number several times
  # There are 1.6 million combinations, so the odds are good
  dd if=/dev/urandom bs=3 count=1 2> /dev/null | \
    od -A n -t x1 | sed 's/^ /52:54:00:/; s/ /:/g'
}

##############################################################
function unique-ipv4-address
{
  # We use /dev/urandom and just hope we don't draw same number several times
  # The odds depend on the length of the mask
  dd if=/dev/urandom bs=4 count=1 2> /dev/null | \
    od -A n -t u1 | sed 's/^  *//; s/  */./g'
}

##############################################################
function ipv4-normalize
{
  local address="$1"

  printf "%02x" ${address//./ }
}

##############################################################
function ipv4-mask
{
  local prefix="$1"
  local result

  result=$(( ~0 << (32 - $prefix) ))
  printf "%08x" $(( $result & 0xffffffff ))
}

##############################################################
function ipv4-combine
{
  local n_address="$1"
  local n_mask="$2"
  local n_ored="$3"
  local result

  result=$(( (0x$n_address & 0x$n_mask) | (0x$n_ored & ~0x$n_mask) ))
  printf "%08x" $(( $result & 0xffffffff ))
}

##############################################################
function address-in-subnet
{
  local subnet="$1"
  local ored="$2"
  local address prefix
  local n_address n_mask n_ored n_result

  address="${subnet%/*}"
  prefix="${subnet#*/}"
  n_address=$(ipv4-normalize "$address")
  n_mask=$(ipv4-mask "$prefix")
  n_ored=$(ipv4-normalize "$ored")
  n_result=$(ipv4-combine "$n_address" "$n_mask" "$n_ored")
  echo "$[0x${n_result:0:2}].$[0x${n_result:2:2}].$[0x${n_result:4:2}].$[0x${n_result:6:2}]"
}

##############################################################
function ipv4-valid
{
  local address="$1"
  local subnet="$2"
  local network_name="$3"
  local n_mask n_masked n_zero n_one n_max

  # Check for invalid addresses like
  # 192.168.15.0/24 or 192.168.15.255/24
  prefix="${subnet#*/}"
  n_mask=$(ipv4-mask "$prefix")
  n_address=$(ipv4-normalize "$address")

  n_masked=$(( 0x$n_address & ~0x$n_mask ))
  n_zero=$(( 0x00000000 & ~0x$n_mask ))
  n_one=$(( 0x00000001 & ~0x$n_mask ))
  n_max=$(( 0xffffffff & ~0x$n_mask ))
  if [ $n_masked -eq $n_zero -o $n_masked -eq $n_one -o $n_masked -eq $n_max ]; then
    echo "no"
    return
  fi

  # Check for addresses that are already reserved
  virsh net-dumpxml "$network_name" | grep "<host .* ip='$address'/>"
  if [ $? -eq 0 ]; then
    echo "no"
    return
  fi

  echo "yes"
}

##############################################################
function ipv6-normalize
{
  local address="$1"
  local c replacement i word

  c=$(echo -n "${address//[^:]/}" | wc -c)

  case "$address" in
    ::*) # ::4:b:1 => 0:0:0:0:0:
      replacement=""
      for (( i=0; i<9-$c; i++ )); do
        replacement="0:${replacement}"
      done
      ;;
    *::) # fd00:c0c0:c0c0:: => :0:0:0:0:0
      replacement=""
      for (( i=0; i<9-$c; i++ )); do
        replacement="${replacement}:0"
      done
      ;;
    *::*) # fd00::5:0 => :0:0:0:0:0:
      replacement=":"
      for (( i=0; i<8-$c; i++ )); do
        replacement="${replacement}0:"
      done
      ;;
    *) # ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe =>
      replacement=""
      ;;
  esac
  address=${address/::/$replacement}
  for word in ${address//:/ }; do
    printf "%04x" 0x$word
  done
}

##############################################################
function ipv6-mask
{
  local prefix="$1"
  local i byte

  for (( i = 0; i < 128; i+= 8 )); do
    if [ $(($i+8)) -lt $prefix ]; then
      echo -n "ff"
    elif [ $i -lt $prefix ]; then
      byte=$(( ~0 << (8 - $prefix + $i) ))
      printf "%02x" $(( $byte & 0xff ))
    else
      echo -n "00"
    fi
  done
}

##############################################################
function ipv6-combine
{
  local n_address="$1"
  local n_mask=$2
  local n_ored="$3"
  local i a m o

  for (( i=0; i<32; i+=2 )); do
    a=0x${n_address:$i:2}
    m=0x${n_mask:$i:2}
    o=0x${n_ored:$i:2}
    printf "%02x" $(( ($a & $m) | ($o & ~$m) ))
  done
}

##############################################################
function mac-to-ipv6
{
  local mac="$1"
  local b

  echo -n "::"
  b=0x${mac:0:2}; printf "%02x" $(( $b ^ 2 ))
  b=0x${mac:3:2}; printf "%02x" $b
  echo -n ":"
  b=0x${mac:6:2}; printf "%02x" $b
  echo -n "ff:fe"
  b=0x${mac:9:2}; printf "%02x" $b
  echo -n ":"
  b=0x${mac:12:2}; printf "%02x" $b
  b=0x${mac:15:2}; printf "%02x" $b
}

##############################################################
function address-in-subnet6
{
  local subnet6="$1"
  local ored6="$2"
  local address prefix
  local n_address n_mask n_ored n_result

  address="${subnet6%/*}"
  prefix="${subnet6#*/}"
  n_address=$(ipv6-normalize "$address")
  n_mask=$(ipv6-mask "$prefix")
  n_ored=$(ipv6-normalize "$ored6")
  n_result=$(ipv6-combine "$n_address" "$n_mask" "$n_ored")
  echo "${n_result:0:4}:${n_result:4:4}:${n_result:8:4}:${n_result:12:4}:${n_result:16:4}:${n_result:20:4}:${n_result:24:4}:${n_result:28:4}"
}

##############################################################
function prefix-of-subnet
{
  local subnet="$1"
  local prefix

  echo -n "${subnet#*/}"
}

##############################################################
function sudo-cp
{
    # You have to allow the user running this script to use
    # "zypper" and "cp" as root by declaring in /etc/sudoers:
    #   <user> <hostname>=NOPASSWD: /usr/bin/zypper, /usr/bin/cp

    sudo cp "$@"
}

##############################################################
function unset-home-control-repo
{
  local src
  local repo_file

  src=$(dirname "$0")

  repo_file="/etc/zypp/repos.d/Home.repo"

  sed "s!enabled=1!enabled=0!" $src/home.repo > /tmp/home_$$.repo
  sudo-cp /tmp/home_$$.repo $repo_file
  if [ $? -ne 0 ]; then
    echo "Failed unsetting home test suites repository" >&2
    exit 20
  fi
}

##############################################################
function set-home-control-repo
{
  local src
  local repo_file repo_url

  src=$(dirname "$0")

  repo_file="/etc/zypp/repos.d/Home.repo"
  repo_url="http://download.opensuse.org/repositories/home:/${HOME_PROJECT}/${RUNNING_SYSTEM}"

  sed "s!baseurl=.*!baseurl=$repo_url!" $src/home.repo > /tmp/home_$$.repo
  sudo-cp /tmp/home_$$.repo $repo_file
  if [ $? -ne 0 ]; then
    echo "Failed setting up home test suites repository" >&2
    exit 21
  fi
}

##############################################################
function unset-local-control-repo
{
  local src
  local repo_file

  src=$(dirname "$0")

  repo_file="/etc/zypp/repos.d/Local.repo"

  sed "s!enabled=1!enabled=0!" $src/local.repo > /tmp/local_$$.repo
  sudo-cp /tmp/local_$$.repo $repo_file
  if [ $? -ne 0 ]; then
    echo "Failed unsetting local test suites repository" >&2
    exit 22
  fi
}

##############################################################
function set-local-control-repo
{
  local src arch
  local repo_file repo_url

  src=$(dirname "$0")
  arch=$(uname -m)

  shared="${BUILD_ROOT}/${RUNNING_SYSTEM}-${arch}/.build.packages/RPMS"
  [ -d "$shared" ] || sudo mkdir -p "$shared"

  repo_file="/etc/zypp/repos.d/Local.repo"
  repo_url="dir://$shared"

  sed "s!baseurl=.*!baseurl=$repo_url!" $src/local.repo > /tmp/local_$$.repo
  sudo-cp /tmp/local_$$.repo $repo_file
  if [ $? -ne 0 ]; then
    echo "Failed setting up local test suites repository" >&2
    exit 23
  fi
}

##############################################################
function install-twopence-server
{
  local node_name="$1"
  local family="$2"

  # We install through SSH, but after that, we switch to virtio
  twopence_command -b -q "${TARGET}" \
    "zypper --non-interactive addrepo http://download.opensuse.org/repositories/basiliQA/$family/basiliQA.repo && \
zypper --non-interactive --gpg-auto-import-keys refresh && \
zypper --non-interactive install twopence-test-server && \
zypper --non-interactive removerepo basiliQA"
  if [ $? -ne 0 ]; then
    echo "Failed to install twopence test server" >&2
    exit 24
  fi

  twopence_command -b -q "${TARGET}" \
    "systemctl enable twopence-test-server && \
systemctl start twopence-test-server"
  if [ $? -ne 0 ]; then
    echo "Failed to start twopence test server" >&2
    exit 24
  fi

  echo "Test server installed and listening for connections through virtio."
}

##############################################################
function prepare-local-repository
{
  local src

  src=$(dirname "$0")

  twopence_command -b "${TARGET}" \
    "mkdir -p /var/lib/basiliqa/RPMs"
  if [ $? -ne 0 ]; then
    echo "Failed to create RPMs directory" >&2
    exit 25
  fi

  twopence_command -b "${TARGET}" \
    "modprobe 9pnet_virtio"
  if [ $? -ne 0 ]; then
    echo "Failed to load kernel module needed to share directories" >&2
    exit 25
  fi

  twopence_command -b "${TARGET}" \
    "mount RPMs /var/lib/basiliqa/RPMs -t 9p -o trans=virtio"
  if [ $? -ne 0 ]; then
    echo "Failed to mount shared RPMs directory" >&2
    exit 25
  fi

  twopence_inject "${TARGET}" \
    "$src/local.repo" "/var/lib/basiliqa/local.repo"
  if [ $? -ne 0 ]; then
    echo "Failed to copy local repository" >&2
    exit 25
  fi
}

##############################################################
function delete-previous-instance
{
  local machine_list

  machine_list=$(virsh list)
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 26
  fi
  machine_id=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f3)
  if [ "$machine_id" = "" ]; then
    echo "No previous instance to stop"
  else
    echo "Instance ${MACHINE_NAME} is already started, stopping it"
    virsh destroy "${MACHINE_NAME}" > /dev/null
    if [ $? -ne 0 ]; then
      echo "virsh error" >&2
      exit 26
    fi
    echo "Instance has been stopped"
  fi

  machine_list=$(virsh list --all)
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 26
  fi
  machine_id=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f3)
  if [ "$machine_id" = "" ]; then
    echo "No previous instance to undefine"
  else
    echo "Instance ${MACHINE_NAME} is already defined, undefining it"
    virsh undefine "${MACHINE_NAME}" > /dev/null
    if [ $? -ne 0 ]; then
      echo "virsh error" >&2
      exit 26
    fi
    echo "Instance has been undefined"
  fi
}

##############################################################
function delete-previous-network
{
  local network_list network_id

  network_list=$(virsh net-list)
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 27
  fi
  network_id=$(echo "$network_list" | grep -m 1 " ${NETWORK_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$network_id" = "" ]; then
    echo "No previous network to stop"
  else
    echo "Network ${NETWORK_NAME} is already started, stopping it"
    virsh net-destroy "${NETWORK_NAME}" > /dev/null
    if [ $? -ne 0 ]; then
      echo "virsh error" >&2
      exit 27
    fi
    echo "Network has been stopped"
  fi

  network_list=$(virsh net-list --all)
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 27
  fi
  network_id=$(echo "$network_list" | grep -m 1 " ${NETWORK_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$network_id" = "" ]; then
    echo "No previous network to undefine"
  else
    echo "Network ${NETWORK_NAME} is already defined, undefining it"
    virsh net-undefine "${NETWORK_NAME}" > /dev/null
    if [ $? -ne 0 ]; then
      echo "virsh error" >&2
      exit 27
    fi
    echo "Network has been undefined"
  fi
}

##############################################################
function get-fixed-characteristics
{
  # Do we run our own DHCP?
  if [ "$REMOTE_DHCP_HOST" != "" -a "$REMOTE_DHCP_USER" != "" ]; then
    DHCP_FIXED="no"
  else
    DHCP_FIXED="yes"
  fi

  # Can we go out from fixed network?
  GATEWAY_FIXED="yes"

  # Is the fixed network already defined and started?
  virsh net-list | grep -q "fixed"
  if [ $? -eq 0 ]; then
    FIXED_EXISTS="yes"
  else
    # if it is defined but not started, better
    # consider it as non-existent and undefine it
    virsh net-list --all | grep -q "fixed"
    if [ $? -eq 0 ]; then
      virsh net-undefine fixed
    fi
    FIXED_EXISTS="no"
  fi
}

##############################################################
function create-network
{
  local subnet="$1"
  local subnet6="$2"
  local dhcp="$3"
  local gateway="$4"
  local src
  local bridge_name mac address prefix address6 prefix6 dhcp_start dhcp_end

  src=$(dirname "$0")

  bridge_name=$(shorten-name "${NETWORK_NAME}")
  mac=$(unique-mac-address)

  if [ "$subnet" = "" ]; then
    address=""
    prefix=""
  else
    address=$(address-in-subnet "$subnet" "0.0.0.1")
    prefix=$(prefix-of-subnet "$subnet")
  fi

  if [ "$subnet6" = "" ]; then
    address6=""
    prefix6=""
  else
    address6=$(address-in-subnet6 "$subnet6" "::1")
    prefix6=$(prefix-of-subnet "$subnet6")
  fi

  if [ "$gateway" != "yes" -o "$subnet" = "" ]; then
    GATEWAY_IP="N/A"
  else
    GATEWAY_IP="$address"
  fi

  if [ "$dhcp" != "yes" -o "$subnet" = "" ]; then
    dhcp_start=""
    dhcp_end=""
  else
    dhcp_start=$(address-in-subnet "$subnet" "0.0.0.8")
    dhcp_end=$(address-in-subnet "$subnet" "255.255.255.254")
  fi

  xsltproc \
    --stringparam "name" "${NETWORK_NAME}" \
    --stringparam "bridge_name" "$bridge_name" \
    --stringparam "mac" "$mac" \
    --stringparam "address" "$address" \
    --stringparam "prefix" "$prefix" \
    --stringparam "address6" "$address6" \
    --stringparam "prefix6" "$prefix6" \
    --stringparam "dhcp_start" "$dhcp_start" \
    --stringparam "dhcp_end" "$dhcp_end" \
    --stringparam "gateway" "$gateway" \
    $src/test-net.xslt $src/test-net.xml > "${WORKSPACE}/test-net.xml"

  virsh net-define "${WORKSPACE}/test-net.xml" > /dev/null
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 28
  fi
  echo "Network \"$NETWORK_NAME\" has been defined"

  if [ "$NETWORK_NAME" = "fixed" ]; then
    list=$(ps ax | grep dnsmasq | grep -v grep)
    if [ "$list" != "" ]; then
      echo >&2
      echo "There are dnsmasq processes running" >&2
      echo "Please stop dnsmasq service, or kill these processes, and restart command" >&2
      exit 28
    fi
  fi

  virsh net-start "${NETWORK_NAME}" > /dev/null
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 28
  fi
  echo "Network \"$NETWORK_NAME\" has been started"
}

##############################################################
function is-local-image-outdated
{
  local http_head remote_modified
  local local_modified

  http_head=$(curl -s --head ${IMAGE_SOURCE}/${IMAGE_DISK})
  if [ $? -ne 0 ]; then
    echo "HTTP error" >&2
    exit 29
  fi
  remote_modified=$(echo "$http_head" | grep "^Last-Modified: " | sed "s/^Last-Modified: //")
  echo "Image file was last modified on $(date --date "$remote_modified")"
  remote_modified=$(date --date "$remote_modified" +%s)

  local_modified=$(stat --format=%Y ${IMAGE_DIR}/${IMAGE_DISK})

  if [ $local_modified -gt $remote_modified ]; then
    return 1 # false, not outdated
  else
    return 0 # true, outdated
  fi
}

##############################################################
function download-image
{
  local image_url="${IMAGE_SOURCE}/${IMAGE_DISK}"
  local image_name="${IMAGE_DIR}/${IMAGE_DISK}"

  if [ ! -d "${IMAGE_DIR}" ]; then
    mkdir -p "${IMAGE_DIR}"
    if [ $? -ne 0 ]; then
      echo "Error creating image directory" >&2
      exit 30
    fi
  fi
  if [ -f "${image_name}" ]; then
    rm -f "${image_name}"
    if [ $? -ne 0 ]; then
      echo "Error removing previous image" >&2
      exit 30
    fi
  fi
  if [[ "${image_url}" =~ ^http: ]]; then
    curl "${image_url}" --progress-bar -o "${image_name}"
  else
    cp "${image_url}" "${image_name}"
  fi
  if [ $? -ne 0 ]; then
    echo "Error downloading image" >&2
    exit 30
  fi
  echo "Image downloaded in ${IMAGE_DIR}"
}

##############################################################
function is-remote-image-outdated
{
  local image_name="${IMAGE_DIR}/${IMAGE_DISK}"
  local remote_modified local_modified

  remote_modified=$(twopence_command -b -u "${REMOTE_VIRT_USER}" "ssh:${REMOTE_VIRT_HOST}" \
                      "stat --format=%Y ${image_name}")

  local_modified=$(stat --format=%Y ${image_name})

  if [ $local_modified -gt $remote_modified ]; then
    return 1 # false, not outdated
  else
    return 0 # true, outdated
  fi
}

##############################################################
function copy-file-to-remote-dir
{
  local dir="$1"
  local file="$2"

  # Create remote directory first
  twopence_command -b -u "${REMOTE_VIRT_USER}" "ssh:${REMOTE_VIRT_HOST}" \
    "mkdir -p ${dir}"
  if [ $? -ne 0 ]; then
    echo "Error creating remote directory" >&2
    exit 31
  fi

  # The remote file might have wrong permissions,
  # so remove it first
  twopence_command -b -u "${REMOTE_VIRT_USER}" "ssh:${REMOTE_VIRT_HOST}" \
    "rm -f ${dir}/${file}"
  if [ $? -ne 0 ]; then
    echo "Error removing remote file" >&2
    exit 31
  fi

  # FIXME: twopence seems to have problems transferring big files
  #        so we are using scp
  scp "${dir}/${file}" "${REMOTE_VIRT_USER}@${REMOTE_VIRT_HOST}:${dir}/${file}"
  if [ $? -ne 0 ]; then
    echo "Error copying file" >&2
    exit 31
  fi

  echo "File ${file} copied in ${dir} on ${REMOTE_VIRT_HOST} as ${REMOTE_VIRT_USER}"
}

##############################################################
function get-image
{
  local system_and_version="$1"
  local architecture="$2"
  local variant="$3"

  IMAGE_DISK="${system_and_version}-${architecture}-${variant}.qcow2"

  # Copy this image locally
  if [ -f "${IMAGE_DIR}/${IMAGE_DISK}" ]; then
    is-local-image-outdated
    if [ $? -ne 0 ]; then
      echo "Image ${IMAGE_DISK} is already in the local cache and up to date"
    else
      echo "Image ${IMAGE_DISK} is in the local cache, but it is outdated, downloading it again"
      download-image
    fi
  else
    echo "Image ${IMAGE_DISK} is not in the local cache yet, downloading it"
    download-image
  fi

  # Copy this image onto the remote virtualization host if there is one
  if [ "$REMOTE_VIRT_HOST" != "" -a "$REMOTE_VIRT_USER" != "" ]; then
    twopence_command -b -u "$REMOTE_VIRT_USER" "ssh:$REMOTE_VIRT_HOST" \
      "test -f ${IMAGE_DIR}/${IMAGE_DISK}"
    if [ $? -eq 0 ]; then
      is-remote-image-outdated
      if [ $? -ne 0 ]; then
        echo "Remote image ${IMAGE_DISK} is already in the cache and up to date"
      else
        echo "Remote image ${IMAGE_DISK} is in the cache, but it is outdated, downloading it again"
        copy-file-to-remote-dir "${IMAGE_DIR}" "${IMAGE_DISK}"
      fi
    else
      echo "Remote image ${IMAGE_DISK} is not in the cache yet, downloading it"
      copy-file-to-remote-dir "${IMAGE_DIR}" "${IMAGE_DISK}"
    fi
  fi
}

##############################################################
function boot-test-machine
{
  local node_name="$1"
  local family="$2"
  local arch="$3"
  local model="$4"
  local nic_list=($5)
  local disk_list=($6)

  local src
  local emulation skylake vcpus memsize disksize shared
  local n i j mac netname
  local nic0 nic1 nic2 nic3 nic4 nic5 nic6 nic7
  local socket

  src=$(dirname "$0")

  # Test whether host's arch is the same as SUT's arch (qemu or kvm?)
  if [ "$(uname -m)" = "$arch" ]; then
    emulation="no"
  else
    emulation="yes"
  fi

  # Test whether host is using Skylake CPU according to https://wiki.gentoo.org/wiki/Safe_CFLAGS#Skylake
  if [ "$(grep -zq 'vendor_id.: GenuineIntel.cpu family.: 6.model..: 94.model name' /proc/cpuinfo)" ]; then
    skylake="yes"
  else
    skylake="no"
  fi

  # Determine numeric characteristics of VM
  case "$model" in
    m1.tiny)
      vcpus="1"
      memsize="512"  # Megabytes
      disksize="1"   # Gigabytes
      ;;
    m1.smaller)
      vcpus="1"
      memsize="1024"
      disksize="18"
      ;;
    m1.small)
      vcpus="1"
      memsize="2048"
      disksize="20"
      ;;
    m1.medium)
      vcpus="2"
      memsize="4096"
      disksize="40"
      ;;
    m1.large)
      vcpus="4"
      memsize="8192"
      disksize="80"
      ;;
    m1.xlarge)
      vcpus="8"
      memsize="16384"
      disksize="160"
      ;;
    m1.ltp)
      vcpus="2"
      memsize="2048"
      disksize="20"
      ;;
    *)
      echo "Unknown flavor $model" >&2
      exit 32
      ;;
  esac

  # Determine directory to share between real host and jail
  shared=""
  if [ "${BUILD_ROOT}" != "" ]; then
    shared="${BUILD_ROOT}/${family}-${arch}/.build.packages/RPMS/"
    echo "Sharing directory \"$shared\" with virtual machine"
    [ -d "$shared" ] || sudo mkdir -p "$shared"
  fi

  # Determine network interfaces requested by user
  n=${#nic_list[@]}
  if [ $n -gt 8 ]; then
    echo "Too many network interfaces" >&2
    exit 32
  fi
  for ((i = 0; i < n; i++)); do
    mac=$(unique-mac-address)
    if [ "${nic_list[$i]}" = "fixed" ]; then
      netname="fixed"
    else
      netname=${PROJECT_AND_CONTEXT}-${nic_list[i]}
    fi
    eval "nic$i=\"--stringparam address$i \${mac} --stringparam network$i \${netname}\""
    MAC_ADDRESS+=( "$mac" )
  done

  # Determine hard disks requested by user
  d=${#disk_list[@]}
  if [ $d -gt 8 ]; then
    echo "Too many additional hard disks" >&2
    exit 32
  fi
  for ((i = 0; i < d; i++)); do
    file="${WORKSPACE}/${node_name}-disk${i}.qcow2"
    letter=$(printf "\x$(printf %x $(( 98 + $i )))")
    dev="vd${letter}"
    eval "disk$i=\"--stringparam file$i \${file} --stringparam dev$i \${dev}\""
    rm -f "$file"
    qemu-img create -f qcow2 "${file}" "${disk_list[$i]}" > /dev/null
    if [ $? -ne 0 ]; then
      echo "Error creating disk image" >&2
      exit 32
    fi
  done

  # Determine virtio socket
  socket=""
  if [ "$TARGET_TYPE" = "virtio" ]; then
    socket="${WORKSPACE}/${node_name}.sock"
  fi

  # Prepare a copy of hard disk that we will throw away after the tests
  # We do not honor the requested hard disk size,
  # as we use premade images of a given size.
  rm -f "${WORKSPACE}/${node_name}.qcow2"
  qemu-img create -f qcow2 -b "${IMAGE_DIR}/${IMAGE_DISK}" "${WORKSPACE}/${node_name}.qcow2" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Error copying disk image" >&2
    exit 32
  fi

  # Copy this hard disk onto the remote virtualization host if there is one
  if [ "$REMOTE_VIRT_HOST" != "" -a "$REMOTE_VIRT_USER" != "" ]; then
    echo "Copying hard disk to ${WORKSPACE}/${node_name}.qcow2 on ${REMOTE_VIRT_HOST} as ${REMOTE_VIRT_USER}"
    copy-file-to-remote-dir "${WORKSPACE}" "${node_name}.qcow2"
    rm "${dir}/${file}"
    if [ $? -ne 0 ]; then
      echo "Error removing local disk image" >&2
      exit 32
    fi
  fi

  # Use "ppc64be" instead of "ppc64" to avoid confusion with "ppc64le"
  [ "$arch" = "ppc64" ] && arch="ppc64be"

  # Prepare libvirt XML description of the SUT
  xsltproc \
       --stringparam "name" "${MACHINE_NAME}" \
       --stringparam "arch" "$arch" \
       --stringparam "emulation" "$emulation" \
       --stringparam "skylake" "$skylake" \
       --stringparam "vcpus" "$vcpus" \
       --stringparam "memsize" "$memsize" \
       --stringparam "disk" "${WORKSPACE}/${node_name}.qcow2" \
       --stringparam "shared" "$shared" \
       $nic0 $nic1 $nic2 $nic3 $nic4 $nic5 $nic6 $nic7 \
       $disk0 $disk1 $disk2 $disk3 $disk4 $disk5 $disk6 $disk7 \
       --stringparam "socket" "$socket" \
       "$src/test-vm.xslt" "$src/test-vm.xml" > "${WORKSPACE}/test-vm.xml"
  if [ $? -ne 0 ]; then
    echo "Error preparing VM definition" >&2
    exit 32
  fi

  # Define the VM
  virsh define "${WORKSPACE}/test-vm.xml" > /dev/null
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 32
  fi
  echo "Instance defined"

  # Start the VM
  virsh start "${MACHINE_NAME}" > /dev/null
  if [ $? -ne 0 ]; then
    echo "virsh error" >&2
    exit 32
  fi
  echo "Instance started"
}

##############################################################
function get-fixed-ipv4-local
{
  local network_name="$1"
  local dhcp="$2"
  local subnet="$3"
  local mac="$4"

  local random attempt isvalid

  local max_attempts=64

  # Chose an address in this subnet at random
  for ((attempt = 0; attempt < max_attempts; attempt++)); do
    random=$(unique-ipv4-address)
    FIXED_IP=$(address-in-subnet "$subnet" "$random")
    isvalid=$(ipv4-valid "$FIXED_IP" "$subnet" "$network_name")
    [ "$isvalid" = "yes" ] && break
  done
  if [ $attempt -eq $max_attempts ]; then
    echo "Could not pick up a valid IP address" >&2
    exit 33
  fi

  # If we provide DHCP, associate this address to the MAC address
  if [ "$dhcp" = "yes" ]; then
    virsh net-update \
      --network "$network_name" \
      add-last ip-dhcp-host \
      --xml "<host mac='$mac' ip='$FIXED_IP'/>" \
      --live --config > /dev/null
    if [ $? -ne 0 ]; then
      echo "Could not define static DHCP lease for $mac and $FIXED_IP in subnet $subnet" >&2
      exit 33
    fi
  fi

  echo "Internal IP address is $FIXED_IP"
}

##############################################################
function get-fixed-ipv4-remote
{
  local user="$1"
  local host="$2"
  local mac="$3"

  local attempt

  local max_attempts=30

  # Query remote DHCP server for the address it chose
  for ((attempt = 0; attempt < max_attempts; attempt++)); do
    FIXED_IP=$(twopence_command -b -u "${user}" "ssh:${host}" \
                 "grep -B 12 \"$mac\" /var/lib/dhcp/db/dhcpd.leases" | \
                 grep lease | tail -n 1 | cut -d' ' -f2)
    [ "$FIXED_IP" != "" ] && break
  done
  if [ $attempt -eq $max_attempts ]; then
    echo "Could not get the IP address from remote DHCP server $host" >&2
    exit 34
  fi

  echo "Internal IP address is $FIXED_IP"
}

##############################################################
function get-fixed-ipv6
{
  local subnet6="$1"
  local mac="$2"

  local derived

  derived=$(mac-to-ipv6 "$mac")
  FIXED_IP6=$(address-in-subnet6 "$subnet6" "$derived")
  echo "IPv6 address is $FIXED_IP6"
}

##############################################################
function shorten-name
{
  local name="$1"
  local sum=$(echo "$name" | md5sum)

  echo "${sum:0:11}"
}

##############################################################
function initialize-nic
{
  local network_name="$1"
  local mac="$2"

  local network
  local dhcp subnet gateway_ip subnet6

  network=${network_name^^}
  if [ "${network_name}" = "fixed" ]; then
    NETWORK_NAME="fixed"
  else
    NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
  fi
  eval "dhcp=\"\$DHCP_${network}\""
  eval "subnet=\"\$SUBNET_${network}\""
  eval "gateway_ip=\"\$GATEWAY_IP_${network}\""
  eval "subnet6=\"\$SUBNET6_${network}\""

  # Determine fixed IP
  if [ "$subnet" = "" ]; then
    echo "No IPv4 subnet for network $network_name, no internal IP address"
    FIXED_IP="N/A"
  else
    FIXED_IP=""
    echo "Determining internal IP address for network $network_name"
    if [ "$REMOTE_DHCP_HOST" != "" -a "$REMOTE_DHCP_USER" != "" ]; then
      get-fixed-ipv4-remote "$REMOTE_DHCP_USER" "REMOTE_DHCP_HOST" "$mac"
    else
      get-fixed-ipv4-local "$NETWORK_NAME" "$dhcp" "$subnet" "$mac"
    fi
  fi
  INTERNAL_IP+=( "$FIXED_IP" )

  # If a gateway is defined, then
  # use fixed IP also as floating IP
  if [ "$gateway_ip" = "N/A" ]; then
    echo "No gateway defined for network $network_name, or no IPv4 subnet defined for that network, not associating an external IP address"
    FLOATING_IP="N/A"
  else
    echo "Using internal address also as external address for network $network_name"
    FLOATING_IP="$FIXED_IP"
  fi
  EXTERNAL_IP+=( "$FLOATING_IP" )

  # Determine IPv6
  if [ "$subnet6" = "" ]; then
    echo "No IPv6 subnet for network $network_name, no IPv6 address"
    FIXED_IP6="N/A"
  else
    FIXED_IP6=""
    echo "Determining IPv6 address for network $network_name"
    get-fixed-ipv6 "$subnet6" "$mac"
  fi
  IP6+=( "$FIXED_IP6" )
}

##############################################################
function initialize-disk
{
  local disk_number="$1"
  local arch="$2"
  local disk_size="$3"

  local disk_ascii disk_letter

  case "$arch" in
    ppc64le|ppc64|aarch64)
       disk_ascii=$(( 97 + $disk_number )) # /dev/vda, ...
       ;;
    *) disk_ascii=$(( 98 + $disk_number )) # /dev/vdb, ...
       ;;
  esac
  disk_letter=$(printf "\x$(printf %x $disk_ascii)")

  DISK_NAME+=( "/dev/vd${disk_letter}" )
  DISK_SIZE+=( "${disk_size}G" )
}

##############################################################
function drop-test-machine
{
  local node_name="$1"
  local nic_list=($2)
  local disk_list=($3)

  local node n d i
  local network_name internal_ip network dhcp

  node=${node_name^^}

  virsh destroy "$MACHINE_NAME" > /dev/null
  # errors ignored
  virsh undefine "$MACHINE_NAME" > /dev/null
  # errors ignored

  n=${#nic_list[@]}
  for ((i = 0; i < n; i++)); do
    eval "network_name=\"\${nic_list[$i]}\""
    eval "internal_ip=\"\${INTERNAL_IP_$node}\""
    network=${network_name^^}
    eval "dhcp=\"\$DHCP_${network}\""
    if [ "$dhcp" = "yes" ]; then
      virsh net-update \
        --network "$network_name" \
        delete ip-dhcp-host \
        --xml "<host ip='$internal_ip'/>" \
        --live --config > /dev/null
      # errors ignored
    fi
  done

  d=${#disk_list[@]}
  for ((i = 0; i < d; i++)); do
    rm -f "${WORKSPACE}/${node_name}-disk${i}.qcow2"
    # errors ignored
  done

  rm -f "${WORKSPACE}/${node_name}.qcow2"
  # errors ignored
}

##############################################################
function drop-network
{
  virsh net-destroy "$NETWORK_NAME" > /dev/null
  # errors ignored
  virsh net-undefine "$NETWORK_NAME" > /dev/null
  # errors ignored
}

##############################################################

trap finish-test-environment EXIT

# Get default values
# no default value for $PROJECT_NAME
# no default value for $CONTROL_PKG
# no default value for $HOME_PROJECT
# no default value for $BUILD_ROOT
# no default value for $EXECUTION_CONTEXT
# no default value for $TEST_PARAMETERS
get-default "IMAGE_SOURCE" "images/@source"
get-default "WORKSPACE_ROOT" "directories/@workspace-root"
get-default "TARGET_TYPE" "vms/@target-type"
get-default "VIRSH_DEFAULT_CONNECT_URI" "vms/@virsh-uri"
get-default "VM_MODEL" "vms/@model"
get-default "SUBNET_FIXED" "vms/@subnet-fixed"
get-default "SUBNET6_FIXED" "vms/@subnet6-fixed"
get-default "IMAGE_DIR" "vms/@images"
get-default "REMOTE_VIRT_HOST" "vms/remote-virt/@host"
get-default "REMOTE_VIRT_USER" "vms/remote-virt/@user"
get-default "REMOTE_DHCP_HOST" "vms/remote-dhcp/@host"
get-default "REMOTE_DHCP_USER" "vms/remote-dhcp/@user"
# no default value for $WORKSPACE

# Check arguments
check-value "PROJECT_NAME" "$PROJECT_NAME"
check-value "CONTROL_PKG" "$CONTROL_PKG"
# empty $HOME_PROJECT is okay and means "no home project in build system"
# empty $BUILD_ROOT is okay and means "no local RPMs directory"
# empty $EXECUTION_CONTEXT is okay and means "no special context"
# empty $TEST_PARAMETERS is okay and means "no parameters to export"
check-value "IMAGE_SOURCE" "$IMAGE_SOURCE"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
check-value "IMAGE_DIR" "$IMAGE_DIR"
check-value "TARGET_TYPE" "$TARGET_TYPE"
check-value "VIRSH_DEFAULT_CONNECT_URI" "$VIRSH_DEFAULT_CONNECT_URI"
check-value "VM_MODEL" "$VM_MODEL"
check-value "SUBNET_FIXED" "$SUBNET_FIXED"
# empty $SUBNET6_FIXED is okay and means "no IPv6 networking on fixed network"
# empty $REMOTE_VIRT_HOST is okay and means "no remote virtualization"
# empty $REMOTE_VIRT_USER is okay and means "no remote virtualization"
# empty $REMOTE_DHCP_HOST is okay and means "no remote DHCP server"
# empty $REMOTE_DHCP_USER is okay and means "no remote DHCP server"
# empty $WORKSPACE is okay and means "computed value"

# Use execution context as a suffix
if [ "$EXECUTION_CONTEXT" = "" ]; then
  PROJECT_AND_CONTEXT="$PROJECT_NAME"
else
  PROJECT_AND_CONTEXT="$PROJECT_NAME-$EXECUTION_CONTEXT"
fi

# Create workspace if needed
[ -z "$WORKSPACE" ] && export WORKSPACE="$WORKSPACE_ROOT/$PROJECT_AND_CONTEXT"
echo "Creating workspace in $WORKSPACE if needed"
create-workspace
echo

# Install control RPM
RUNNING_SYSTEM="$(get-running-system)"
echo "Installing control RPM"
if [ "$HOME_PROJECT" = "" ]; then
  unset-home-control-repo
else
  set-home-control-repo
fi
if [ "$BUILD_ROOT" = "" ]; then
  unset-local-control-repo
else
  set-local-control-repo
fi
install-control-rpm
echo

# Get all repository channels for the chosen systems
if [ "$HOME_PROJECT" = "" ]; then
  home_repo=""
else
  home_repo="http://download.opensuse.org/repositories/home:/$HOME_PROJECT/@@FAMILY@@/home:$HOME_PROJECT.repo"
fi
if [ "$BUILD_ROOT" = "" ]; then
  local_repo=""
else
  local_repo="/var/lib/basiliqa/local.repo"
fi
get-channels "$home_repo" "$local_repo"
echo

# Prepare log files
echo "Preparing log files"
export REPORT="${WORKSPACE}/junit-results.xml"
LOGFILE="${WORKSPACE}/junit-results.log"
rm -f "$REPORT" "$LOGFILE"
touch "$LOGFILE"
echo

display-nodes-file
export RUN_NAME=""
for RUN_NAME in $(list-runs); do
  # Parse nodes file
  NETWORKS=""
  NODES=""
  echo "Parsing nodes file (run $RUN_NAME)"
  parse-nodes-file
  echo

  # Start test environment file
  set-test-environment
  echo

  # Delete nodes and networks left over from previous tests
  for node_name in $NODES; do
    echo "Cleanup for node $node_name"
    MACHINE_NAME="${PROJECT_AND_CONTEXT}-${node_name}"
    echo "Trying to remove previous instance of test machine for node $node_name"
    delete-previous-instance
    echo
  done
  for network_name in $NETWORKS; do
    echo "Cleanup for network $network_name"
    NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
    echo "Trying to remove previous network $network_name"
    delete-previous-network
    echo
  done

  # Start "fixed" network if needed
  # We never stop it nor undefine it, because another test
  #   may be running at same time and using it
  # So the user has to clean it manually with net-destroy
  #   and net-undefine when he/she is finished with testing
  DHCP_FIXED=""
  GATEWAY_FIXED=""
  FIXED_EXISTS=""
  get-fixed-characteristics
  if [ "$FIXED_EXISTS" = "no" ]; then
    echo "Trying to create network fixed"
    NETWORK_NAME="fixed"
    GATEWAY_IP=""
    create-network "$SUBNET_FIXED" "$SUBNET6_FIXED" "$DHCP_FIXED" "$GATEWAY_FIXED"
  else
    echo "Network fixed already exists"
    GATEWAY_IP=$(address-in-subnet "$SUBNET_FIXED" "0.0.0.1")
  fi
  define-network-variables "fixed" "$SUBNET_FIXED" "$SUBNET6_FIXED"
  echo "Adding information about network fixed to test environment file"
  set-network-environment "fixed"
  echo

  # Prepare networks
  for network_name in $NETWORKS; do
    # Get network characteristics
    network=${network_name^^}
    eval "subnet=\$SUBNET_$network"
    eval "subnet6=\$SUBNET6_$network"
    eval "dhcp=\$DHCP_$network"
    eval "gateway=\$GATEWAY_$network"

    # Create network
    NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
    GATEWAY_IP=""
    echo "Trying to create network $network_name"
    create-network "$subnet" "$subnet6" "$dhcp" "$gateway"

    # Define environement variables for network
    define-network-variables "$network_name" "$subnet" "$subnet6"

    # Add network to test environment file
    echo "Adding information about network $network_name to test environment file"
    set-network-environment "$network_name"
    echo
  done

  # Boot nodes
  for node_name in $NODES; do
    # Get node characteristics
    node=${node_name^^}
    eval "image_name=\$IMAGE_NAME_$node"
    eval "system=\"\$SYSTEM_$node\""
    eval "family=\"\$FAMILY_$node\""
    eval "arch=\"\$ARCH_$node\""
    eval "variant=\"\$VARIANT_$node\""
    eval "model=\"\$MODEL_$node\""
    eval "nic_list=\"\$NIC_$node\""
    eval "disk_list=\"\$DISK_$node\""

    # Check that image name is properly defined for this node
    check-value "\$IMAGE_NAME_$node" "$image_name"

    # Get QCow2 image if not already there
    IMAGE_DISK=""
    echo "Trying to get image for system $system, architecture $arch, and variant $variant"
    get-image "$system" "$arch" "$variant"
    echo

    # Boot test machine
    MACHINE_NAME="${PROJECT_AND_CONTEXT}-${node_name}"
    MAC_ADDRESS=()
    echo "Trying to spawn new virtual machine for node $node_name"
    boot-test-machine "$node_name" "$family" "$arch" "$model" "$nic_list" "$disk_list"
    echo

    # Initialize all networking cards
    INTERNAL_IP=()
    EXTERNAL_IP=()
    IP6=()
    i=0
    echo "Initializing all network interfaces on node $node_name"
    for network_name in $nic_list; do
      initialize-nic "$network_name" "${MAC_ADDRESS[$i]}"
      (( i++ ))
    done
    echo

    # Initialize all disks
    DISK_NAME=()
    DISK_SIZE=()
    i=0
    echo "Initializing all disks on node $node_name"
    for disk_size in $disk_list; do
      initialize-disk "$i" "$arch" "$disk_size"
      (( i++ ))
    done
    echo

    # Define environment variables for node
    TARGET=""
    if [ "$TARGET_TYPE" = "virtio" ]; then
      TARGET="virtio:${WORKSPACE}/${node_name}.sock"
    fi
    define-node-variables "$node_name" "$nic_list" "$disk_list"
    echo
  done

  # Wait for SSH to become available on all machines
  echo "Waiting for SSH to be available on all machines"
  wait_list=""
  for node_name in $NODES; do
    # Get node characteristics
    node=${node_name^^}
    eval "external_ip=\"\$EXTERNAL_IP_$node\""

    # Build wait list
    wait_list="${wait_list}${external_ip} "
  done
  wait-for-ssh "$wait_list"
  echo

  # Initialize started nodes
  for node_name in $NODES; do
    # Get node characteristics
    node=${node_name^^}
    eval "external_ip=\"\$EXTERNAL_IP_$node\""
    eval "family=\"\$FAMILY_$node\""
    eval "uninstall_list=\"\$UNINSTALL_$node\""
    eval "repo_list=\"\$REPO_$node\""
    eval "install_list=\"\$INSTALL_$node\""
    eval "refresh=\"\$REFRESH_$node\""

    # Start twopence test server if requested
    TARGET="ssh:${external_ip}"
    if [ "$TARGET_TYPE" = "virtio" ]; then
      echo "Trying to install twopence test server"
      install-twopence-server "$node_name" "$family"
      TARGET="virtio:${WORKSPACE}/${node_name}.sock"
    fi

    # Install local repository
    if [ "$BUILD_ROOT" != "" ]; then
      echo "Trying to prepare local repository"
      prepare-local-repository
    fi

    # Uninstall packages
    if [ "$uninstall_list" != "" ]; then
      echo "Trying to uninstall the requested packages"
      uninstall-rpms "$uninstall_list"
    fi

    # Install additional repositories
    if [ "$repo_list" != "" ]; then
      echo "Trying to install the requested repositories"
      install-repositories "$repo_list"
    fi

    # Install packages
    if [ "$install_list" != "" ]; then
      echo "Trying to install the requested packages"
      install-rpms "$family" "$install_list"
    fi

    # Refresh all packages
    if [ "$refresh" = "yes" ]; then
      echo "Upgrading all packages"
      upgrade-rpms
    fi

    # Add node to test environment file
    echo "Adding information about node $node_name to test environment file"
    set-node-environment "$node_name"
    echo

    # Display system information
    echo "Trying to get system information"
    get-system-information
    echo
  done

  # End test environment file
  finish-test-environment

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

  # Drop VMs and networks unless explicitely requested
  if [ "$KEEP_IF_SUCCESS" = "yes" ]; then
    echo "Intentionally keeping virtual machines, virtual networks, and virtual disks"
    echo
  else
    for node_name in $NODES; do
      node=${node_name^^}
      eval "nic_list=\"\$NIC_$node\""
      eval "disk_list=\"\$DISK_$node\""
      MACHINE_NAME="${PROJECT_AND_CONTEXT}-${node_name}"
      echo "Stopping virtual machine ${MACHINE_NAME}"
      drop-test-machine "$node_name" "$nic_list" "$disk_list"
      echo
    done
    rm -f "${WORKSPACE}/test-vm.xml"
    for network_name in $NETWORKS; do
      NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
      echo "Stopping network ${NETWORK_NAME}"
      drop-network
      echo
    done
    rm -f "${WORKSPACE}/test-net.xml"
  fi
  echo "================================="
  echo
done

# Finish log files
echo "Finishing log files"
finish-logs
echo

echo "SUCCESS"
echo

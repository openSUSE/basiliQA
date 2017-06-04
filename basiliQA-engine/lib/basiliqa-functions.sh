# basiliqa-functions.sh
# basiliQA shell utility functions (sourced)

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

##############################################################
function create-workspace
{
  if [ ! -d "$WORKSPACE" ]; then
    mkdir -p "$WORKSPACE"
    if [ $? -ne 0 ]; then
      echo "Can't create workspace directory" >&2
      exit 2
    fi
  fi
}

##############################################################
function sudo-zypper
{
    # You have to allow the user running this script to use
    # "zypper" as root by declaring in /etc/sudoers:
    #   <user> <hostname>=NOPASSWD: /usr/bin/zypper

    sudo zypper "$@"
}

##############################################################
function get-running-system
{
  local id version_id

  id=$(grep "^ID=" /etc/os-release 2>/dev/null | sed 's/"//g; s/^ID=//')
  if [ $? -ne 0 ]; then
    echo "Cannot get ID of running system" >&2
    exit 3
  fi

  version_id=$(grep "^VERSION_ID=" /etc/os-release 2>/dev/null | sed 's/"//g; s/^VERSION_ID=//')
  if [ $? -ne 0 ]; then
    echo "Cannot get version ID of running system" >&2
    exit 3
  fi

  case "$id" in
    sled|sles)
      case "$version_id" in
        12) echo "SLE_12"
            ;;
        12.1) echo "SLE_12_SP1"
              ;;
        12.2) echo "SLE_12_SP2"
              ;;
        12.3) echo "SLE_12_SP3"
              ;;
        *) echo "Unknown SLE version $version_id" >&2
           exit 3
      esac
      ;;
    opensuse)
      case "$version_id" in
        13.2) echo "openSUSE_13.2"
              ;;
        42.1) echo "openSUSE_Leap_42.1"
              ;;
        42.2) echo "openSUSE_Leap_42.2"
              ;;
        42.3) echo "openSUSE_Leap_42.3"
              ;;
        20*) echo "openSUSE_Tumbleweed"
             ;;
        *) echo "Unknown openSUSE version $version_id" >&2
           exit 3
      esac
      ;;
    *) echo "Unknown running system $id" >&2
       exit 3
  esac
}

##############################################################
function install-control-rpm
{
  local repo_file repo_url rpm_name

  # Temporary
  repo_file="/etc/zypp/repos.d/home_ebischoff_basiliQA_testsuites.repo"
  repo_url="http://download.opensuse.org/repositories/home:/ebischoff:/basiliQA:/testsuites/${RUNNING_SYSTEM}/home:ebischoff:basiliQA:testsuites.repo"
  # repo_file="/etc/zypp/repos.d/basiliQA_testsuites.repo"
  # repo_url="http://download.opensuse.org/repositories/basiliQA:/testsuites/${RUNNING_SYSTEM}/basiliQA:testsuites.repo"

  if [ ! -f "$repo_file" ]; then
    sudo-zypper --non-interactive addrepo "${repo_url}"
    if [ $? -ne 0 ]; then
      echo "Failed installing test suites repository" >&2
      exit 4
    fi
  fi

  sudo-zypper --non-interactive --gpg-auto-import-keys refresh
  if [ $? -ne 0 ]; then
    echo "Failed refreshing package list" >&2
    exit 4
  fi

  rpm_name="${PROJECT_NAME}-${CONTROL_PKG}"
  sudo-zypper --non-interactive remove "${rpm_name}" 2>/dev/null
  sudo-zypper --non-interactive install --oldpackage --download-in-advance "${rpm_name}"
  if [ $? -ne 0 ]; then
    echo "Failed installing ${rpm_name}" >&2
    exit 4
  fi
}

##############################################################
function get-family
{
  local image_name="$1"
  local list="$2"

  awk -v name="${image_name}.qcow2" '$3 == name {print $2}' "$list"
}

##############################################################
function get-repo
{
  local channel="$1"
  local i="$2"
  local family="$3"
  local arch="$4"

  local repo

  repo=$(channel-info "channel[$i]/repo[@family = \"$family\"]/@url" "$arch")

  # If the repo is not a ".repo" file,
  # incorporate the name of channel
  if [ "$repo" != "" ]; then
    if [[ "$repo" =~ \.repo$ ]]; then
      echo -n "$repo"
    else
      echo -n "$channel|$repo"
    fi
  fi
}

##############################################################
function get-channels
{
  local home_repo="$1"
  local local_repo="$2"

  local list_url list
  local variable node image_name
  local system arch variant
  local n i
  local channel family name value

  list_url="${IMAGE_SOURCE}/images.list"
  list="${WORKSPACE}/images.list"

  if [[ "$list_url" =~ ^http: ]]; then
    wget "$list_url" -O "$list" > /dev/null
  else
    cp "$list_url" "$list"
  fi
  if [ $? -ne 0 ]; then
    echo "Error downloading list of images" >&2
    exit 5
  fi

  for variable in $(env | grep "^IMAGE_NAME_" | sed "s/=.*$//"); do
    if [[ $variable =~ ^(IMAGE)_(NAME)_([^_]*)$ ]]; then
      node=${BASH_REMATCH[3]}
    else
      echo "$variable name must be of form 'IMAGE_NAME_<node>'" >&2
      exit 5
    fi

    eval "image_name=\$$variable"
    if [[ $image_name =~ ^([^-]*)-([^-]*)-([^-]*)$ ]]; then
      echo "Processing image ${variable}=${image_name}:"
      system=${BASH_REMATCH[1]}
      arch=${BASH_REMATCH[2]}
      variant=${BASH_REMATCH[3]}
    else
      echo "$variable value must be of form '<system>-<arch>-<variant>'" >&2
      exit 5
    fi

    family=$(get-family "$image_name" "$list")
    if [ "$family" = "" ]; then
      echo "Family of image $image_name is unknown" >&2
      echo "Are you sure this image still exist on server?" >&2
      exit 5
    fi

    name="SYSTEM_${node^^}"
    eval "export $name=\"$system\""
    echo "Defined variable $name with value \"$system\""
    name="FAMILY_${node^^}"
    eval "export $name=\"$family\""
    echo "Defined variable $name with value \"$family\""
    name="ARCH_${node^^}"
    eval "export $name=\"$arch\""
    echo "Defined variable $name with value \"$arch\""
    name="VARIANT_${node^^}"
    eval "export $name=\"$variant\""
    echo "Defined variable $name with value \"$variant\""

    n=$(channel-count)
    for ((i = 1; i <= $n; i++)); do
      channel=$(channel-info "channel[$i]/@name" "$arch")
      name="CHANNEL_${channel^^}_${node^^}"
      value=$(get-repo "$channel" "$i" "$family" "$arch")
      if [ "${channel^^}" = "BASILIQA" ]; then
        if [ "$home_repo" != "" ]; then
          value="${home_repo//@@FAMILY@@/$family} $value"
        fi
        if [ "$local_repo" != "" ]; then
          value="$local_repo $value"
        fi
      fi
      eval "export $name=\"$value\""
      echo "Defined variable $name with value \"$value\""
    done

  done
}

##############################################################
function global-options
{
  local keep="$1"

  local userdef

  # All the variables can be redefined by the user at run time.
  # The redefined variables have priority over the values
  #   defined in the nodes file.
  userdef="$KEEP_IF_SUCCESS"
  if [ -z "$userdef" ]; then
    eval "KEEP_IF_SUCCESS=\"$keep\""
  else
    eval "KEEP_IF_SUCCESS=\"$userdef\""
  fi
}

##############################################################
function network-options
{
  local network="$1"
  local dhcp="$2"
  local gateway="$3"
  local subnet="$4"
  local subnet6="$5"

  local userdef

  # All the variables can be redefined by the user at run time.
  # The redefined variables have priority over the values
  #   defined in the nodes file.
  # These variables are "internal": they are not exported.
  eval "userdef=\"\$SUBNET_${network}\""
  if [ -z "$userdef" ]; then
    eval "SUBNET_${network}=\"$subnet\""
  else
    eval "SUBNET_${network}=\"$userdef\""
  fi

  eval "userdef=\"\$SUBNET6_${network}\""
  if [ -z "$userdef" ]; then
    eval "SUBNET6_${network}=\"$subnet6\""
  else
    eval "SUBNET6_${network}=\"$userdef\""
  fi

  eval "userdef=\"\$DHCP_${network}\""
  if [ -z "$userdef" ]; then
    eval "DHCP_${network}=\"$dhcp\""
  else
    eval "DHCP_${network}=\"$userdef\""
  fi

  eval "userdef=\"\$GATEWAY_${network}\""
  if [ -z "$userdef" ]; then
    eval "GATEWAY_${network}=\"$gateway\""
  else
    eval "GATEWAY_${network}=\"$userdef\""
  fi
}

##############################################################
function node-options
{
  local node="$1"
  local model="$2"
  local uninstall="$3"
  local repo="$4"
  local install="$5"
  local refresh="$6"
  local nic="$7"
  local disk="$8"

  local userdef

  # All the variables can be redefined by the user at run time.
  # The redefined variables have priority over the values
  #   defined in the nodes file.
  # These variables are "internal": they are not exported.
  eval "userdef=\"\$MODEL_${node}\""
  if [ -z "$userdef" ]; then
    eval "MODEL_${node}=\"$model\""
  else
    eval "MODEL_${node}=\"$userdef\""
  fi

  eval "userdef=\"\$UNINSTALL_${node}\""
  if [ -z "$userdef" ]; then
    eval "UNINSTALL_${node}=\"$uninstall\""
  else
    eval "UNINSTALL_${node}=\"$userdef\""
  fi

  eval "userdef=\"\$REPO_${node}\""
  if [ -z "$userdef" ]; then
    eval "REPO_${node}=\"$repo\""
  else
    eval "REPO_${node}=\"$userdef\""
  fi
  eval "userdef=\"\$EXTRA_REPO_${node}\""
  if [ -n "$userdef" ]; then
    eval "REPO_${node}=\"${userdef} \$REPO_${node}\""
  fi

  eval "userdef=\"\$INSTALL_${node}\""
  if [ -z "$userdef" ]; then
    eval "INSTALL_${node}=\"$install\""
  else
    eval "INSTALL_${node}=\"$userdef\""
  fi

  eval "userdef=\"\$REFRESH_${node}\""
  if [ -z "$userdef" ]; then
    eval "REFRESH_${node}=\"$refresh\""
  else
    eval "REFRESH_${node}=\"$userdef\""
  fi

  eval "userdef=\"\$NIC_${node}\""
  if [ -z "$userdef" ]; then
    if [ "$nic" = "" ]; then
      nic="fixed"
    fi
    eval "NIC_${node}=\"$nic\""
  else
    eval "NIC_${node}=\"$userdef\""
  fi

  eval "userdef=\"\$DISK_${node}\""
  if [ -z "$userdef" ]; then
    eval "DISK_${node}=\"$disk\""
  else
    eval "DISK_${node}=\"$userdef\""
  fi
}

##############################################################
function display-nodes-file
{
  local nodes_file

  nodes_file="/var/lib/basiliqa/${PROJECT_NAME}/${CONTROL_PKG}/nodes"

  if [ ! -r "${nodes_file}" ]; then
    exit 6
  fi

  echo "========== Nodes file ==========="
  cat "${nodes_file}"
  echo "================================="
}

##############################################################
function list-runs
{
  local nodes_file

  nodes_file="/var/lib/basiliqa/${PROJECT_NAME}/${CONTROL_PKG}/nodes"

  /usr/lib/basiliqa/lib/read_nodes_file -l "${nodes_file}"
  if [ $? -ne 0 ]; then
    exit 6
  fi
}

##############################################################
function parse-nodes-file
{
  local nodes_file

  nodes_file="/var/lib/basiliqa/${PROJECT_NAME}/${CONTROL_PKG}/nodes"

  eval $(/usr/lib/basiliqa/lib/read_nodes_file "${RUN_NAME}" "${nodes_file}")
  if [ $? -ne 0 ]; then
    exit 6
  fi
}

##############################################################
function set-test-environment
{
  local testenv="${WORKSPACE}/testenv-${RUN_NAME}.xml"

  echo "<testenv name=\"${PROJECT_NAME}\" context=\"${EXECUTION_CONTEXT}\" parameters=\"${TEST_PARAMETERS}\" workspace=\"${WORKSPACE}\" report=\"${WORKSPACE}/junit-results.xml\">" > "$testenv"
  echo "" >> "$testenv"
  if [ -n "$OS_AUTH_URL" ]; then
    echo "  <cloud auth-url=\"$OS_AUTH_URL\" project-name=\"$OS_PROJECT_NAME\" username=\"$OS_USERNAME\" model=\"$VM_MODEL\" />" >> "$testenv"
  fi
  if [ -n "$VIRSH_DEFAULT_CONNECT_URI" ]; then
    echo "  <vms virsh-uri=\"$VIRSH_DEFAULT_CONNECT_URI\" model=\"$VM_MODEL\" />" >> "$testenv"
  fi
  echo "" >> "$testenv"

  # These variables are already defined elsewhere, but we inform nonetheless
  if [ -n "$EXECUTION_CONTEXT" ]; then
    echo "Variable EXECUTION_CONTEXT has value \"${EXECUTION_CONTEXT}\""
  fi
  echo "Variable REPORT has value \"${REPORT}\""
  if [ -n "$OS_AUTH_URL" ]; then
    echo "Variable OS_AUTH_URL has value \"${OS_AUTH_URL}\""
    echo "Variable OS_PROJECT_NAME has value \"${OS_PROJECT_NAME}\""
    echo "Variable OS_USERNAME has value \"${OS_USERNAME}\""
    # OS_PASSWORD omitted, even though it is no big secret
  fi
  if [ -n "$VIRSH_DEFAULT_CONNECT_URI" ]; then
    echo "Variable VIRSH_DEFAULT_CONNECT_URI has value \"${VIRSH_DEFAULT_CONNECT_URI}\""
  fi
  # VM_MODEL not displayed as it is just a default value that can be redefined on a per node basis
}

##############################################################
function define-network-variables
{
  local network_name="$1"
  local subnet="$2"
  local subnet6="$3"

  local network

  network=${network_name^^}
  [ "$subnet" = "" ] && subnet="N/A"
  [ "$subnet6" = "" ] && subnet6="N/A"

  # Define variables SUBNET_IP_network, SUBNET6_IP_network, and GATEWAY_IP_network
  eval "export SUBNET_IP_${network}=${subnet}"
  echo "Defined variable SUBNET_IP_${network} with value \"${subnet}\""
  eval "export SUBNET6_IP_${network}=${subnet6}"
  echo "Defined variable SUBNET6_IP_${network} with value \"${subnet6}\""
  eval "export GATEWAY_IP_${network}=${GATEWAY_IP}"
  echo "Defined variable GATEWAY_IP_${network} with value \"${GATEWAY_IP}\""
}

##############################################################
function define-node-variables
{
  local node_name="$1"
  local nic_list=($2)
  local disk_list=($3)

  local node
  local n d i
  local internal_ip external_ip
  local target
  local ip6

  node=${node_name^^}

  # Define variables INTERFACES_node,
  # INTERNAL_IP_node_nic, EXTERNAL_IP_node_nic, IP6_node_nic, and NETWORK_node_nic
  n=${#nic_list[@]}
  eval "export INTERFACES_${node}=${n}"
  echo "Defined variable INTERFACES_${node} with value \"${n}\""
  for ((i = 0; i < $n; i++)); do
    eval "export INTERNAL_IP_${node}_ETH${i}=${INTERNAL_IP[$i]}"
    echo "Defined variable INTERNAL_IP_${node}_ETH${i} with value \"${INTERNAL_IP[$i]}\""
    eval "export EXTERNAL_IP_${node}_ETH${i}=${EXTERNAL_IP[$i]}"
    echo "Defined variable EXTERNAL_IP_${node}_ETH${i} with value \"${EXTERNAL_IP[$i]}\""
    eval "export IP6_${node}_ETH${i}=${IP6[$i]}"
    echo "Defined variable IP6_${node}_ETH${i} with value \"${IP6[$i]}\""
    eval "export NETWORK_${node}_ETH${i}=${nic_list[$i]}"
    echo "Defined variable NETWORK_${node}_ETH${i} with value \"${nic_list[$i]}\""
  done

  # Define variables DISKS_node,
  # DISK_NAME_node_disk and DISK_SIZE_node_disk
  d=${#disk_list[@]}
  eval "export DISKS_${node}=${d}"
  echo "Defined variable DISKS_${node} with value \"${d}\""
  for ((i = 0; i < $d; i++)); do
    eval "export DISK_NAME_${node}_DISK${i}=${DISK_NAME[$i]}"
    echo "Defined variable DISK_NAME_${node}_DISK${i} with value \"${DISK_NAME[$i]}\""
    eval "export DISK_SIZE_${node}_DISK${i}=${DISK_SIZE[$i]}"
    echo "Defined variable DISK_SIZE_${node}_DISK${i} with value \"${DISK_SIZE[$i]}\""
  done

  # Choose first card with an external IP
  for ((i = 0; i < $n; i++)); do
    [ "${EXTERNAL_IP[$i]}" = "N/A" ] || break
  done
  if [ $i -eq $n ]; then
    echo "No external IP available, can't communicate with instance" >&2
    exit 7
  fi

  # Use it for values INTERNAL_IP_node and EXTERNAL_IP_node
  internal_ip="${INTERNAL_IP[$i]}"
  eval "export INTERNAL_IP_${node}=$internal_ip"
  echo "Defined variable INTERNAL_IP_${node} with value \"${internal_ip}\""
  external_ip="${EXTERNAL_IP[$i]}"
  eval "export EXTERNAL_IP_${node}=$external_ip"
  echo "Defined variable EXTERNAL_IP_${node} with value \"${external_ip}\""

  # Now choose first card with an IPv6 address
  for ((i = 0; i < $n; i++)); do
    [ "${IP6[$i]}" = "N/A" ] || break
  done

  # Use it for value IP6_node
  if [ $i -eq $n ]; then ip6="N/A"
  else ip6="${IP6[$i]}"
  fi
  eval "export IP6_${node}=${ip6}"
  echo "Defined variable IP6_${node} with value \"${ip6}\""

  # Use external IP for value TARGET_node, unless the target is defined otherwise
  if [ "$TARGET" != "" ]; then
    target="$TARGET"
  else
    target="ssh:${external_ip}"
  fi
  eval "export TARGET_${node}=$target"
  echo "Defined variable TARGET_${node} with value \"${target}\""
}

##############################################################
function wait-for-ssh
{
  local list_ping="$1"

  local timeout

  local list_ssh list_remaining
  local i external_ip who

  timeout=120

  list_ssh=""
  for ((i = 0; i < $timeout; i++)); do
    # First try to ping to machine
    list_remaining=""
    for external_ip in $list_ping; do
      if ping -q -c 1 ${external_ip} > /dev/null; then
        list_ssh="${list_ssh}${external_ip} "
      else
        list_remaining="${list_remaining}${external_ip} "
      fi
    done
    list_ping="$list_remaining"

    # If ping succeeded, then try to ssh to machine
    list_remaining=""
    for external_ip in $list_ssh; do
      who=$(twopence_command -b "ssh:${external_ip}" "whoami" 2>&1 || true)
      if [[ "$who" =~ root ]]; then
        :
      else
        list_remaining="${list_remaining}${external_ip} "
      fi
    done
    list_ssh="$list_remaining"

    [ "$list_ping" = "" -a "$list_ssh" = "" ] && break
    sleep 1
  done

  if [ $i -eq $timeout ]; then
    echo "Timeout" >&2
    for external_ip in $list_ping; do
      echo "$external_ip did not answer to ping" >&2
    done
    for external_ip in $list_ssh; do
      echo "$external_ip answered to ping, but did not answer to ssh" >&2
    done
    exit 8
  fi
  echo "SSH is now available on all machines"
}

##############################################################
function uninstall-rpms
{
  local rpm_list="$1"

  twopence_command -b -t 240 "${TARGET}" \
    "zypper --non-interactive remove --force ${rpm_list}"
  if [ $? -ne 0 ]; then
    echo "Failed to uninstall packages ${rpm_list}" >&2
    exit 9
  fi

  echo "Uninstalled packages ${rpm_list}"
}

##############################################################
function install-repositories
{
  local repo_list="$1"

  local priority repo_url repo_name

  priority=1                      # 1 = maximal priority
  for repo_url in $repo_list; do
    if [[ "$repo_url" =~ (.*)\|(.*) ]]; then
      # <name>|<url>
      repo_name=${BASH_REMATCH[1]}
      repo_url=${BASH_REMATCH[2]}
      twopence_command -b \
        -o "${WORKSPACE}/output" "${TARGET}" \
        "zypper addrepo ${repo_url} ${repo_name}"
      if [ $? -ne 0 ]; then
        grep "Repository named .* already exists. Please use another alias." "${WORKSPACE}/output"
        if [ $? -eq 0 ]; then
          echo "Repository already installed, doing nothing."
          continue
        else
          echo "Failed to download repository ${repo_name} from ${repo_url}" >&2
          exit 10
        fi
      fi
      rm "${WORKSPACE}/output"
    elif [[ "$repo_url" =~ \.repo$ ]]; then
      # <url>.repo
      twopence_command -b \
        -o "${WORKSPACE}/output" "${TARGET}" \
        "zypper addrepo ${repo_url}"
      if [ $? -ne 0 ]; then
        grep "Repository named .* already exists. Please use another alias." "${WORKSPACE}/output"
        if [ $? -eq 0 ]; then
          echo "Repository already installed, doing nothing."
          continue
        else
          echo "Failed to download repository from ${repo_url}" >&2
          exit 10
        fi
      fi
      repo_name=$(head -n 1 "${WORKSPACE}/output" | sed "s/^[^']*'\\(.*\\)'.*$/\1/")
      rm "${WORKSPACE}/output"
    else
      echo "${repo_url} does not look like '<url>.repo' nor '<name>|<url>'" >&2
      exit 10
    fi

    twopence_command -b "${TARGET}" \
      "zypper modifyrepo -p ${priority} \"${repo_name}\""
    if [ $? -ne 0 ]; then
      echo "Failed to set priority of repository ${repo_name} to ${priority}" >&2
      exit 10
    fi

    (( priority++ ))
  done

  twopence_command -b -t 360 "${TARGET}" \
    "zypper --non-interactive --gpg-auto-import-key refresh"
  if [ $? -ne 0 ]; then
    echo "Failed to refresh packages list" >&2
    exit 10
  fi

  echo "Installed repositories ${repo_list}"
}

##############################################################
function install-rpms
{
  local family="$1"
  local rpm_list="$2"

  if [ "$family" = "SLE_11_SP3" -o "$family" = "SLE_11_SP4" ]; then
    options="--oldpackage --force-resolution"
  else
    options="--oldpackage --force-resolution --replacefiles"
  fi

  twopence_command -b -t 240 "${TARGET}" \
    "zypper --non-interactive install ${options} ${rpm_list}"
  if [ $? -ne 0 ]; then
    echo "Failed to install packages ${rpm_list}" >&2
    exit 11
  fi

  echo "Installed packages ${rpm_list}"
}

##############################################################
function upgrade-rpms
{
  # zypper ref already done

  # this can be a relatively long operation: allowing 20 minutes
  twopence_command -b -t 1200 "${TARGET}" \
    "zypper --non-interactive update --auto-agree-with-licenses"
  if [ $? -ne 0 ]; then
    echo "Failed to upgrade all packages" >&2
    exit 12
  fi

  echo "Upgraded all packages"
}

##############################################################
function set-network-environment
{
  local network_name="$1"
  local testenv="${WORKSPACE}/testenv-${RUN_NAME}.xml"

  local network
  local subnet subnet6 gateway

  network=${network_name^^}
  eval "subnet=\"\$SUBNET_IP_${network}\""
  eval "subnet6=\"\$SUBNET6_IP_${network}\""
  eval "gateway=\"\$GATEWAY_IP_${network}\""

  # Add declaration for network to test environment file
  echo "  <network name=\"${network_name}\" subnet=\"${subnet}\" subnet6=\"${subnet6}\" gateway=\"${gateway}\" />" >> "$testenv"
  echo >> "$testenv"
}

##############################################################
function set-node-environment
{
  local node_name="$1"
  local testenv="${WORKSPACE}/testenv-${RUN_NAME}.xml"

  local node
  local n d i
  local internal_ip external_ip ip6 network
  local disk_name disk_size

  node=${node_name^^}

  # Add declaration for node to test environment file
  eval "internal_ip=\"\$INTERNAL_IP_${node}\""
  eval "external_ip=\"\$EXTERNAL_IP_${node}\""
  eval "ip6=\"\$IP6_${node}\""
  echo "  <node name=\"${node_name}\" target=\"${TARGET}\" internal-ip=\"${internal_ip}\" external-ip=\"${external_ip}\" ip6=\"${ip6}\">" >> "$testenv"

  # Add declarations for network interface cards to test environment file
  eval "n=\"\$INTERFACES_${node}\""
  for ((i = 0; i < $n; i++)); do
    eval "internal_ip=\"\$INTERNAL_IP_${node}_ETH${i}\""
    eval "external_ip=\"\$EXTERNAL_IP_${node}_ETH${i}\""
    eval "ip6=\"\$IP6_${node}_ETH${i}\""
    eval "network=\"\$NETWORK_${node}_ETH${i}\""
    echo "    <interface name=\"eth${i}\" internal-ip=\"${internal_ip}\" external-ip=\"${external_ip}\" ip6=\"${ip6}\" network=\"${network}\" />" >> "$testenv"
  done

  # Add declarations for disks to test environment file
  eval "d=\"\$DISKS_${node}\""
  for ((i = 0; i < $d; i++)); do
    eval "disk_name=\"\$DISK_NAME_${node}_DISK${i}\""
    eval "disk_size=\"\$DISK_SIZE_${node}_DISK${i}\""
    echo "    <disk name=\"${disk_name}\" size=\"${disk_size}\" />" >> "$testenv"
  done
  echo "  </node>" >> "$testenv"
  echo >> "$testenv"
}

##############################################################
function finish-test-environment
{
  local testenv="${WORKSPACE}/testenv-${RUN_NAME}.xml"
  local last

  if [ -s "$testenv" ]; then
    last=$(tail -n -1 "$testenv")
    if [ "$last" != "</testenv>" ]; then
      echo "</testenv>" >> "$testenv"
    fi

    ln -sf "testenv-${RUN_NAME}.xml" "${WORKSPACE}/testenv.xml"
  fi
}

##############################################################
function get-system-information
{
  local info

  echo "========== System info =========="
  info=$(twopence_command -b "${TARGET}" "uname -a")
  if [ $? -ne 0 ]; then
    echo "WARNING: could not get system information" >&2
    # error is not fatal
  else
    echo "$info"
  fi
  echo "================================="
}

##############################################################
function get-tests-table
{
  IFS=$'\r\n' TESTS_TABLE=($(ls ${TESTS_DIR}))
  if [ ${#TESTS_TABLE[@]} -eq 0 ]; then
    echo "Failed to read tests directory" >&2
    exit 13
  fi
  echo "======== Tests to be run ========"
  for line in ${TESTS_TABLE[@]}; do
    echo "$line"
  done
  echo "================================="
  IFS=$' \t\r'
}

##############################################################
function run-tests
{
  local test="$1"
  local output date

  output="${WORKSPACE}/__results.log"

  pushd "${TESTS_DIR}" > /dev/null
  ("./${test}" 2>&1 || echo "${test}" >> "$FAILURES") | tee "$output"
  popd > /dev/null

  if [ ! -f "$REPORT" ]; then
    if grep -q "^###junit" "$output"; then
      echo "Copying JUnit XML results for test ${test}"
      sed 's/</\&lt;/g; s/>/\&gt;/g; s/&/\&amp;/g; s/\x1B/^/g; s/\x01/^/g' "$output" >> "$LOGFILE"
    else
      echo "Faking JUnit XML results for test ${test}"
      date=$(date +%Y-%m-%dT%H:%M:%S.%N | cut -c 1-23)
      echo "###junit testsuite time=\"$date\" id=\"${PROJECT_NAME}.${RUN_NAME}.autogenerated\" text=\"${PROJECT_NAME}\"" >> "$LOGFILE"
      echo "###junit testcase time=\"$date\" id=\"tests.autogenerated\" text=\"${test}\"" >> "$LOGFILE"
      sed 's/</\&lt;/g; s/>/\&gt;/g; s/&/\&amp;/g; s/\x1B/^/g; s/\x01/^/g' "$output" >> "$LOGFILE"
      if grep -q "^${test}\$" "$FAILURES"; then
        echo "###junit failure time=\"$date\"" >> "$LOGFILE"
      else
        echo "###junit success time=\"$date\"" >> "$LOGFILE"
      fi
      echo "###junit endsuite time=\"$date\"" >> "$LOGFILE"
    fi
  fi
  rm "$output"
}

##############################################################
function finish-logs
{
  local date

  # Prepare junit file
  if [ -f "$REPORT" ]; then
    echo "Test suite has directly produced JUnit XML results"
  else
    echo "Post-processing log file $LOGFILE"
    /usr/lib/basiliqa/lib/to_junit "$LOGFILE" "$REPORT"
  fi
}

##############################################################
function check-failures
{
  local failed;

  failed=$(cat "$FAILURES")

  # If failures, display them, and give up abruptly,
  # so virtual machines are not stopped.
  # This allows to investigate the problems manually.
  if [ "$failed" != "" ]; then
    echo "Finishing log files"
    finish-logs
    echo

    echo "========== Failed tests ========="
    echo "$failed"
    echo "================================="
    exit 255
  fi
}

##############################################################

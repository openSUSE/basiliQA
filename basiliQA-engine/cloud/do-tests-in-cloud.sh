#! /bin/bash
#
# do-tests-in-cloud.sh
# Run a set of tests in a cloud - do the real job, in a jail or not

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
#   EXECUTION_CONTEXT          patched
#   TEST_PARAMETERS            TEST_PRECISE,FAST
#
#   IMAGE_SOURCE               http://basiliqa.suse.de/images/
#   IMAGE_NAME_<node>          SLE_12-x86_64-default  (for each node)
#
#   WORKSPACE_ROOT             /var/lib/jenkins/workspace
#
#   OS_AUTH_URL                http://basiliqa-cloud.suse.de:5000/v2.0/
#   OS_PROJECT_NAME            openstack
#   OS_PROJECT_ID              fc94d380bfe14a81aa2ab157d8e9a7e2
#   OS_USERNAME                basiliqa
#   OS_PASSWORD                opensuse
#   VM_MODEL                   m1.medium
#   SEC_GROUP                  allow-all
#
#   WORKSPACE                  /var/lib/jenkins/workspace/suite-helloworld/workspace
#
#   There are also variables to override node file settings.
#   Refer to documentation for those ones.
#
# The following variables, if omitted, will be taken from defaults
# in /etc/basiliqa/basiliqa.conf:
#
#   IMAGE_SOURCE, WORKSPACE_ROOT,
#   OS_AUTH_URL, OS_PROJECT_NAME, OS_PROJECT_ID,
#   OS_USERNAME, OS_PASSWORD, VM_MODEL, SEC_GROUP
#
# The following variable, if omitted, will be computed from other
# variables:
#
#   WORKSPACE

source $(dirname "$0")/../lib/basiliqa-basic-functions.sh
source $(dirname "$0")/../lib/basiliqa-functions.sh

##############################################################
function delete-previous-instance
{
  local timeout
  local machine_list machine_id machine_status
  local addresses_list addresses floating_ip
  local i

  timeout=60

  machine_list=$(openstack server list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 20
  fi
  machine_id=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$machine_id" = "" ]; then
    echo "No previous instance to delete"
  else
    machine_status=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f6)
    if [ "$machine_status" = "DELETED" ]; then
      echo "Instance ${MACHINE_NAME} with ID ${machine_id} is already being deleted"
    else
      echo "Instance ${MACHINE_NAME} with ID ${machine_id} already exists, deleting it"
      addresses_list=$(openstack server show "${machine_id}" | grep " addresses " | cut -d'|' -f3)
      if [ $? -ne 0 ]; then
        echo "Openstack error" >&2
        exit 20
      fi
      for addresses in $(echo "$addresses_list" | tr -d ' ' | tr ';' ' '); do
        floating_ip=$(echo "$addresses" | sed 's/^.*,//')
        openstack server remove floating ip "${machine_id}" "${floating_ip}"
        if [ $? -ne 0 ]; then
          echo "Openstack error" >&2
          exit 20
        fi
        echo "Floating IP ${floating_ip} has been removed"
      done
      openstack server delete "$machine_id"
      if [ $? -ne 0 ]; then
        echo "Openstack error" >&2
        exit 20
      fi
    fi
    for ((i = 0; i < $timeout; i++)); do
      machine_list=$(openstack server list)
      if [ $? -ne 0 ]; then
        echo "Openstack error" >&2
        exit 20
      fi
      machine_id=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f2)
      [ "$machine_id" != "" ] || break
      sleep 1
    done
    if [ "$machine_id" != "" ]; then
      echo "Timeout" >&2
      exit 20
    fi
    echo "Instance has been deleted"
  fi
}

##############################################################
function delete-previous-router
{
  local router_list router_id

  router_list=$(openstack router list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 21
  fi
  router_id=$(echo "$router_list" | grep -m 1 " ${NETWORK_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$router_id" = "" ]; then
    echo "No previous router to delete"
  else
    echo "Router ${NETWORK_NAME} with ID ${router_id} already exists, deleting it"
    openstack router unset --external-gateway "${router_id}"
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 21
    fi
    openstack router remove subnet "${router_id}" "${NETWORK_NAME}-ipv4"
    openstack router remove subnet "${router_id}" "${NETWORK_NAME}-ipv6"
    # We just ignore the error codes, because the subnets might not exist
    # TODO: find a way to know whether the router really has these subnets before trying to delete them
    openstack router delete "${router_id}"
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 21
    fi
    echo "Router has been deleted"
  fi
}

##############################################################
function delete-previous-network
{
  local network_list network_id

  network_list=$(openstack network list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 22
  fi
  network_id=$(echo "$network_list" | grep -m 1 " ${NETWORK_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$network_id" = "" ]; then
    echo "No previous network to delete"
  else
    echo "Network ${NETWORK_NAME} with ID ${network_id} already exists, deleting it"
    # we don't delete its subnets first, but apparently that's okay
    openstack network delete "$network_id"
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 22
    fi
    echo "Network has been deleted"
  fi
}

##############################################################
function create-network
{
  openstack network create --share "$NETWORK_NAME" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 23
  fi
  echo "Network \"$NETWORK_NAME\" has been created"
}

##############################################################
function get-fixed-characteristics
{
  local subnet_show

  subnet_show=$(openstack subnet show "fixed")
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 24
  fi
  SUBNET_FIXED=$(echo "$subnet_show" | grep -m 1 " cidr " | tr -s ' ' | cut -d' ' -f4)
  GATEWAY_IP=$(echo "$subnet_show" | grep -m 1 " gateway_ip " | tr -s ' ' | cut -d' ' -f4)
}

##############################################################
function create-subnet
{
  local subnet="$1"
  local dhcp="$2"
  local gateway="$3"
  local option_dhcp option_gateway
  local subnet_name subnet_show

  # TODO: we could let the user define the DHCP pool directly
  #       with --allocation-pool start=IP_ADDR,end=IP_ADDR
  if [ "$dhcp" = "yes" ]; then
    option_dhcp="--dhcp"
  else
    option_dhcp="--no-dhcp"
  fi
  # TODO: we could let the user define the gateway address directly
  #       with --gateway GATEWAY_IP
  if [ "$gateway" = "yes" ]; then
    option_gateway="--gateway auto"
  else
    option_gateway="--gateway none"
  fi
  subnet_name="${NETWORK_NAME}-ipv4"
  # TODO: we could let the user create more than one subnet per network
  subnet_show=$(openstack subnet create \
          $option_dhcp \
          $option_gateway \
          --subnet-range "$subnet" \
          --network "$NETWORK_NAME" \
          "$subnet_name")
  if [ $? -ne 0 ]; then
    echo "Impossible to create subnet \"$subnet_name\"" >&2
    exit 25
  fi
  SUBNET_ID=$(echo "$subnet_show" | grep -m 1 " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$SUBNET_ID" == "" ]; then
    echo "Subnet \"$subnet_name\" not found" >&2
    exit 25
  fi
  if [ "$gateway" = "yes" ]; then
    GATEWAY_IP=$(echo "$subnet_show" | grep -m 1 " gateway_ip " | tr -s ' ' | cut -d' ' -f4)
  fi
  echo "Subnet \"$subnet_name\" created" >&2
}

##############################################################
function create-subnet6
{
  local subnet6="$1"
  local subnet6_name subnet6_show

  # TODO: we could let the user choose options related to RADVD, DHCPv6, a gateway...
  #       for now we provide only a bare subnet
  subnet6_name="${NETWORK_NAME}-ipv6"
  # TODO: we could let the user create more than one subnet6 per network
  subnet6_show=$(openstack subnet create \
          --ip-version 6 \
          --ipv6-ra-mode slaac \
          --ipv6-address-mode slaac \
          --subnet-range "$subnet6" \
          --network "$NETWORK_NAME" \
          "$subnet6_name")
  if [ $? -ne 0 ]; then
    echo "Impossible to create subnet \"$subnet6_name\"" >&2
    exit 26
  fi
  SUBNET6_ID=$(echo "$subnet6_show" | grep -m 1 " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$SUBNET6_ID" == "" ]; then
    echo "Subnet \"$subnet6_name\" not found" >&2
    exit 26
  fi
  echo "Subnet \"$subnet6_name\" created" >&2
}

##############################################################
function create-router
{
  local router_show

  router_show=$(openstack router create "$NETWORK_NAME")
  if [ $? -ne 0 ]; then
    echo "Impossible to create router \"$NETWORK_NAME\"" >&2
    exit 27
  fi
  ROUTER_ID=$(echo "$router_show" | grep -m 1 " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$ROUTER_ID" == "" ]; then
    echo "Router \"$NETWORK_NAME\" not found" >&2
    exit 27
  fi
  openstack router set --external-gateway floating "$ROUTER_ID"
  if [ $? -ne 0 ]; then
    echo "Impossible to create external interface for router \"$NETWORK_NAME\"" >&2
    exit 27
  fi
  openstack router add subnet "$ROUTER_ID" "$SUBNET_ID"
  if [ $? -ne 0 ]; then
    echo "Impossible to create internal interface for router \"$NETWORK_NAME\"" >&2
    exit 27
  fi
  echo "Router \"$NETWORK_NAME\" created" >&2
}

##############################################################
function is-image-outdated
{
  local image_name="$1"
  local http_head last_modified
  local property_list created

  http_head=$(curl -s --head ${IMAGE_SOURCE}/${image_name}.qcow2)
  if [ $? -ne 0 ]; then
    echo "HTTP error" >&2
    exit 28
  fi
  last_modified=$(echo "$http_head" | grep "^Last-Modified: " | sed "s/^Last-Modified: //")
  echo "Image file was last modified on $(date --date "$last_modified")"
  last_modified=$(date --date "$last_modified" +%s)

  property_list=$(openstack image show "$IMAGE_ID")
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 28
  fi
  created=$(echo "$property_list" | grep "^| created_at " | tr -s ' ' | cut -d' ' -f4)
  echo "Image was uploaded in cloud on $(date --date "$created")"
  created=$(date --date "$created" +%s)

  if [ $created -gt $last_modified ]; then
    return 1 # false, not outdated
  else
    return 0 # true, outdated
  fi
}

##############################################################
function delete-image
{
  openstack image delete "$IMAGE_ID"
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 29
  fi
}

##############################################################
function download-image
{
  local image_name="$1"
  local image_url="$2"
  local architecture="$3"
  local image_arch image_tmp

  mkdir -p /var/tmp/basiliqa
  image_tmp=$(mktemp /var/tmp/basiliqa/image-XXXXX)

  echo "Downloading image from ${image_url}..."
  if [ "$architecture" = "i586" ]; then
    image_arch="i686"
  else
    image_arch="$architecture"
  fi

  if [[ "$image_url" =~ ^http: ]]; then
    curl "${image_url}" --progress-bar -o "${image_tmp}"
  else
    cp "${image_url}" "${image_tmp}"
  fi
  if [ $? -ne 0 ]; then
    echo "Image downloading failed" >&2
    exit 30
  fi

  openstack image create \
           --file "${image_tmp}" \
           --disk-format qcow2 \
           --container-format bare \
           --property is-public="true" \
           --property hw_rng_model="virtio" \
           --property architecture="${image_arch}" \
           "${image_name}" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    # Remove image if openstack failed
    rm "${image_tmp}" > /dev/null 2>&1
    exit 30
  fi

  rm "${image_tmp}" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Removal of ${image_tmp} failed" >&2
    exit 30
  fi
}

##############################################################
function wait-for-image
{
  local image_name="$1"
  local timeout
  local i
  local image_list

  timeout=180

  for ((i = 0; i < $timeout; i++)); do
    image_list=$(openstack image list)
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 31
    fi
    IMAGE_ID=$(echo "$image_list" | grep -m 1 " ${image_name} " | grep " active " | tr -s ' ' | cut -d' ' -f2)
    [ "$IMAGE_ID" = "" ] || break
    sleep 1
  done

  if [ "$IMAGE_ID" = "" ]; then
    echo "Timeout" >&2
    exit 31
  fi
  echo "Image ${image_name} with ID ${IMAGE_ID} is now in the cloud"
}

##############################################################
function get-image
{
  local system_and_version="$1"
  local architecture="$2"
  local variant="$3"
  local image_url
  local image_name image_list image_state

  image_url="${IMAGE_SOURCE}/${system_and_version}-${architecture}-${variant}.qcow2"

  image_name="${system_and_version}-${architecture}-${variant}"
  image_list=$(openstack image list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 32
  fi
  IMAGE_ID=$(echo "$image_list" | grep -m 1 " ${image_name} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$IMAGE_ID" = "" ]; then
    echo "Image $image_name is not in the cloud yet, downloading it"
    download-image "$image_name" "$image_url" "$architecture"
    wait-for-image "$image_name"
  else
    image_state=$(echo "$image_list" | grep -m 1 " ${image_name} " | tr -s ' ' | cut -d' ' -f6)
    if [ "$image_state" = "saving" ]; then
      echo "Image $image_name with ID $IMAGE_ID is already being downloaded"
      wait-for-image "$image_name"
    else
      is-image-outdated "$image_name"
      if [ $? -ne 0 ]; then
        echo "Image $image_name with ID $IMAGE_ID is already in the cloud and up to date"
      else
        echo "Image $image_name is already in the cloud with ID $IMAGE_ID, but it is outdated, downloading it again"
        delete-image
        download-image "$image_name" "$image_url" "$architecture"
        wait-for-image "$image_name"
      fi
    fi
  fi
}

##############################################################
function get-network-id
{
  local network_name="$1"
  local network_list

  if [ "$network_name" = "fixed" ]; then
    NETWORK_NAME="fixed"
  else
    NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
  fi
  network_list=$(openstack network list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 33
  fi
  NETWORK_ID=$(echo "$network_list" | grep -m 1 " ${NETWORK_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$NETWORK_ID" == "" ]; then
    echo "Network \"$network_name\" not found" >&2
    exit 33
  fi
}

##############################################################
function create-disk
{
  local disk_dev="$1"
  local disk_size="$2"

  local out

  DISK_NAME="${MACHINE_NAME}-${disk_dev}"
  out=$(openstack volume create --size "${disk_size%G}" "${DISK_NAME}")
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 34
  fi
  DISK_ID=$(echo "$out" | grep " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$DISK_ID" == "" ]; then
    echo "Openstack error" >&2
    exit 34
  fi
  echo "Created disk $DISK_NAME with ID $DISK_ID"
}

##############################################################
function boot-test-machine
{
  local model="$1"
  local nic_list=($2)
  local disk_list=($3)
  local timeout
  local n i nic0 nic1 nic2 nic3 nic4 nic5 nic6 nic7
  local machine_list

  timeout=120

  n=${#nic_list[@]}
  if [ $n -gt 8 ]; then
    echo "Too many network interfaces" >&2
    exit 35
  fi
  NETWORK_ID=""
  for ((i = 0; i < n; i++)); do
    get-network-id "${nic_list[$i]}"
    eval "nic$i=\"--nic net-id=\$NETWORK_ID\""
  done

  d=${#disk_list[@]}
  if [ $d -gt 8 ]; then
    echo "Too many additional hard disks" >&2
    exit 35
  fi
  DISK_NAME=""
  DISK_ID=""
  for ((i = 0; i < d; i++)); do
    letter=$(printf "\x$(printf %x $(( 98 + $i )))")
    dev="vd${letter}"
    size="${disk_list[$i]}"
    create-disk "$dev" "$size"
    eval "disk$i=\"--block-device-mapping ${dev}=${DISK_ID}:::1\""
  done

  openstack server create \
       --image "$IMAGE_ID" \
       --flavor "$model" \
       $nic0 $nic1 $nic2 $nic3 $nic4 $nic5 $nic6 $nic7 \
       $disk0 $disk1 $disk2 $disk3 $disk4 $disk5 $disk6 $disk7 \
       "$MACHINE_NAME" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 35
  fi
  for ((i = 0; i < $timeout; i++)); do
    machine_list=$(openstack server list)
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 35
    fi
    MACHINE_ID=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | grep -E "ACTIVE|ERROR" | tr -s ' ' | cut -d' ' -f2)
    [ "$MACHINE_ID" = "" ] || break
    sleep 1
  done
  if [ "$MACHINE_ID" = "" ]; then
    echo "Timeout" >&2
    exit 35
  fi
  machine_list=$(openstack server list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 35
  fi
  MACHINE_ID=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | grep "ACTIVE" | tr -s ' ' | cut -d' ' -f2)
  if [ "$MACHINE_ID" = "" ]; then
    echo "Error creating VM" >&2
    exit 35
  fi
  echo "Machine ${MACHINE_NAME} with ID ${MACHINE_ID} is in the cloud"
}

##############################################################
function get-fixed-ips
{
  local machine_list addresses_list
  local -a addresses
  local address

  # Get list of addresses associated to this network
  machine_list=$(openstack server list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 36
  fi
  addresses_list=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | sed "s/.* ${NETWORK_NAME}=\\([^;|]*\\).*/\\1/")
  IFS=',' read -ra addresses <<< "$addresses_list"

  # Get first valid IPv4 address
  for address in ${addresses[*]}; do
    if [[ "$address" =~ ^[0-9.]+$ ]]; then
      FIXED_IP=$address
      break
    fi
  done
  if [ "$FIXED_IP" = "" ]; then
    FIXED_IP="N/A"
    echo "No internal IP address"
  else
    echo "Internal IP address is $FIXED_IP"
  fi

  # Get first valid IPv6 address
  for address in ${addresses[*]}; do
    if [[ "$address" =~ ^[0-9a-f:]+$ ]]; then
      FIXED_IP6=$address
      break
    fi
  done
  if [ "$IP6" = "" ]; then
    FIXED_IP6="N/A"
    echo "No IPv6 address"
  else
    echo "IPv6 address is $FIXED_IP6"
  fi
}

##############################################################
function associate-floating-ip
{
  local timeout
  local floating_list
  local i
  local port_id

  timeout=60

  floating_list=$(openstack floating ip list)
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 37
  fi
  FLOATING_IP=$(echo "$floating_list" | grep -m 1 ' None ' | tr -s ' ' | cut -d' ' -f4)
  if [ "$FLOATING_IP" = "" ]; then
    echo "No IP address available" >&2
    exit 37
  fi
  openstack server add floating ip \
       --fixed-ip-address "${FIXED_IP}" \
       "${MACHINE_ID}" \
       "${FLOATING_IP}"
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 37
  fi
  for ((i = 0; i < $timeout; i++)); do
    floating_list=$(openstack floating ip list)
    if [ $? -ne 0 ]; then
      echo "Openstack error" >&2
      exit 37
    fi
    port_id=$(echo "$floating_list" | grep -m 1 " ${FLOATING_IP} " | tr -s ' ' | cut -d' ' -f8)
    [ "$port_id" = "None" ] || break
    sleep 1
  done
  if [ "$port_id" = "None" ]; then
    echo "IP address ${FLOATING_IP} not associated" >&2
    exit 37
  fi
  echo "IP address ${FLOATING_IP} associated"
}

##############################################################
function initialize-nic
{
  local network_name="$1"

  local network
  local gateway_ip

  # Determine fixed IPs
  FIXED_IP=""
  FIXED_IP6=""
  if [ "$network_name" = "fixed" ]; then
    NETWORK_NAME="fixed"
  else
    NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
  fi
  echo "Determining internal IP addresses for network $network_name"
  get-fixed-ips
  INTERNAL_IP+=( "$FIXED_IP" )
  IP6+=( "$FIXED_IP6" )

  # If a gateway is defined, then
  # pick first available floating IP and associate it to the fixed IP
  FLOATING_IP="N/A"
  network=${network_name^^}
  eval "gateway_ip=\"\$GATEWAY_IP_${network}\""
  if [ "$gateway_ip" = "N/A" ]; then
    echo "No gateway defined for network $network_name, not associating an external IP address"
  else
    echo "Trying to associate an external IP address for network $network_name"
    associate-floating-ip
  fi
  EXTERNAL_IP+=( "$FLOATING_IP" )
}

##############################################################
function initialize-disk
{
  local disk_number="$1"
  local disk_size="$2"

  # 98 = ASCII code for 'b'
  local disk_letter=$(printf "\x$(printf %x $(( 98 + $disk_number )))")

  DISK_NAME+=( "/dev/vd${disk_letter}" )
  DISK_SIZE+=( "${disk_size}G" )
}

##############################################################
function add-secgroup
{
  openstack server add security group "$MACHINE_ID" "$SEC_GROUP"
  if [ $? -ne 0 ]; then
    echo "Openstack error" >&2
    exit 38
  fi
  echo "Added security group $SEC_GROUP"
}

##############################################################
function drop-test-machine
{
  local machine_list machine_id
  local floating_list floating_ip

  machine_list=$(openstack server list)
  # errors ignored
  machine_id=$(echo "$machine_list" | grep -m 1 " ${MACHINE_NAME} " | tr -s ' ' | cut -d' ' -f2)
  if [ "$machine_id" != "" ]; then
    floating_list=$(openstack server show "${machine_id}" | grep " addresses " | sed 's/^.*, //; s/ *|$//')
    # errors ignored
    for floating_ip in $floating_list; do
      openstack server remove floating ip "${machine_id}" "${floating_ip}"
      # errors ignored
    done
  fi
  openstack server delete "$MACHINE_NAME"
  # errors ignored
}

##############################################################
function drop-router
{
  openstack router unset --external-gateway "$NETWORK_NAME"
  # errors ignored
  openstack router remove subnet "$NETWORK_NAME" "${NETWORK_NAME}-ipv4"
  # errors ignored
  openstack router remove subnet "$NETWORK_NAME" "${NETWORK_NAME}-ipv6"
  # errors ignored
  openstack router delete "$NETWORK_NAME"
  # errors ignored
}

##############################################################
function drop-network
{
  local subnet_id port_id

  subnet_id=$(openstack subnet show "${NETWORK_NAME}-ipv4" 2>/dev/null | grep " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$subnet_id" != "" ]; then
    for port_id in $(openstack port list | grep " $subnet_id " | tr -s ' ' | cut -d' ' -f2); do
      openstack port delete $port_id
      # errors ignored
    done
    openstack subnet delete "${NETWORK_NAME}-ipv4"
    # errors ignored
  fi

  subnet6_id=$(openstack subnet show "${NETWORK_NAME}-ipv6" 2>/dev/null | grep " id " | tr -s ' ' | cut -d' ' -f4)
  if [ "$subnet6_id" != "" ]; then
    for port_id in $(openstack port list | grep " $subnet6_id " | tr -s ' ' | cut -d' ' -f2); do
      openstack port delete $port_id
      # errors ignored
    done
    openstack subnet delete "${NETWORK_NAME}-ipv6"
    # errors ignored
  fi

  openstack network delete "$NETWORK_NAME"
  # errors ignored
}

##############################################################

trap finish-test-environment EXIT

# Get default values
# no default value for $PROJECT_NAME
# no default value for $CONTROL_PKG
# no default value for $EXECUTION_CONTEXT
# no default value for $TEST_PARAMETERS
get-default "IMAGE_SOURCE" "images/@source"
get-default "WORKSPACE_ROOT" "directories/@workspace-root"
get-default "OS_AUTH_URL" "cloud/@auth-url"
get-default "OS_PROJECT_NAME" "cloud/@project-name"
get-default "OS_PROJECT_ID" "cloud/@project-id"
get-default "OS_USERNAME" "cloud/@username"
get-default "OS_PASSWORD" "cloud/@password"
get-default "VM_MODEL" "cloud/@model"
get-default "SEC_GROUP" "cloud/@sec-group"
# no default value for $WORKSPACE

# Check arguments
check-value "PROJECT_NAME" "$PROJECT_NAME"
check-value "CONTROL_PKG" "$CONTROL_PKG"
# empty $EXECUTION_CONTEXT is okay and means "no special context"
# empty $TEST_PARAMETERS is okay and means "no parameters to export"
check-value "IMAGE_SOURCE" "$IMAGE_SOURCE"
check-value "WORKSPACE_ROOT" "$WORKSPACE_ROOT"
check-value "OS_AUTH_URL" "$OS_AUTH_URL"
check-value "OS_PROJECT_NAME" "$OS_PROJECT_NAME"
check-value "OS_PROJECT_ID" "$OS_PROJECT_ID"
check-value "OS_USERNAME" "$OS_USERNAME"
check-value "OS_PASSWORD" "$OS_PASSWORD"
check-value "VM_MODEL" "$VM_MODEL"
check-value "SEC_GROUP" "$SEC_GROUP"
# empty $WORKSPACE is okay and means "computed value"

export OS_USER_DOMAIN_NAME="Default"
export OS_IDENTITY_API_VERSION="3"
export OS_REGION_NAME="CustomRegion"
export TARGET_TYPE="ssh"    # would be nice to support virtio in cloud

# Use execution context as a suffix
if [ "$EXECUTION_CONTEXT" = "" ]; then
  PROJECT_AND_CONTEXT="$PROJECT_NAME"
else
  PROJECT_AND_CONTEXT="$PROJECT_NAME-$EXECUTION_CONTEXT"
fi

# Create workspace
[ -z "$WORKSPACE" ] && export WORKSPACE="$WORKSPACE_ROOT/$PROJECT_AND_CONTEXT"
echo "Creating workspace in $WORKSPACE"
create-workspace
echo

# Install control RPM
RUNNING_SYSTEM="$(get-running-system)"
echo "Installing control RPM"
install-control-rpm
echo

# Get all repository channels for the chosen systems
get-channels "" ""
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

  # Delete nodes, routers, and networks left over from previous tests
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
    echo "Trying to remove previous router $network_name"
    delete-previous-router
    echo "Trying to remove previous network $network_name"
    delete-previous-network
    echo
  done

  # Get characteristics of predefined "fixed" network
  SUBNET_FIXED=""
  GATEWAY_IP=""
  get-fixed-characteristics
  define-network-variables "fixed" "$SUBNET_FIXED" ""
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
    NETWORK_ID=""
    echo "Trying to create network $network_name"
    create-network

    # Create IPv4 subnet
    SUBNET_ID=""
    GATEWAY_IP="N/A"
    if [ "$subnet" != "" ]; then
      echo "Trying to create IPv4 subnet for $network_name"
      create-subnet "$subnet" "$dhcp" "$gateway"
    fi

    # Create IPv6 subnet
    SUBNET6_ID=""
    if [ "$subnet6" != "" ]; then
      echo "Trying to create IPv6 subnet for $network_name"
      create-subnet6 "$subnet6"
    fi

    # Create router
    ROUTER_ID=""
    if [ "$gateway" = "yes" ]; then
      echo "Trying to create router for network $network_name"
      create-router
    fi

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
    IMAGE_ID=""
    echo "Trying to get image for system $system, architecture $arch, and variant $variant"
    get-image "$system" "$arch" "$variant"
    echo

    # Boot test machine
    MACHINE_NAME="${PROJECT_AND_CONTEXT}-${node_name}"
    MACHINE_ID=""
    echo "Trying to spawn new virtual machine for node $node_name"
    boot-test-machine "$model" "$nic_list" "$disk_list"
    echo

    # Initialize all networking cards
    INTERNAL_IP=()
    EXTERNAL_IP=()
    IP6=()
    echo "Initializing all network interfaces on node $node_name"
    for network_name in $nic_list; do
      initialize-nic "$network_name"
    done
    echo

    # Initialize all disks
    DISK_NAME=()
    DISK_SIZE=()
    i=0
    echo "Initializing all disks on node $node_name"
    for disk_size in $disk_list; do
      initialize-disk "$i" "$disk_size"
      (( i++ ))
    done
    echo

    # Add a security group if needed
    if [ "$SEC_GROUP" != "none" ]; then
      echo "Trying to add security group"
      add-secgroup
      echo
    fi

    # Define environment variables for node
    TARGET=""
    define-node-variables "$node_name" "$nic_list" "$disk_list"
    echo
  done

  # Wait for SSH to become available on all machines
  echo "Waiting for SSH to become available"
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
    eval "uninstall_list=\"\$UNINSTALL_$node\""
    eval "repo_list=\"\$REPO_$node\""
    eval "install_list=\"\$INSTALL_$node\""
    eval "refresh=\"\$REFRESH_$node\""

    # Determine target
    TARGET="ssh:${external_ip}"

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
    echo "Setting environment variables for the node $node_name"
    set-node-environment "$node_name" "$nic_list" "$disk_list"
    echo

    # Display system information
    echo "Trying to get system information for target $TARGET"
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

  # Prepare failures files
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
    echo "Intentionally keeping virtual machines, networks, and disks in the cloud"
    echo
  else
    for node_name in $NODES; do
      MACHINE_NAME="${PROJECT_AND_CONTEXT}-${node_name}"
      echo "Stopping virtual machine ${MACHINE_NAME}"
      drop-test-machine
      echo
    done
    for network_name in $NETWORKS; do
      NETWORK_NAME="${PROJECT_AND_CONTEXT}-${network_name}"
      network=${network_name^^}
      eval "gateway=\$GATEWAY_$network"
      if [ "$gateway" = "yes" ]; then
        echo "Deleting router ${NETWORK_NAME}"
        drop-router
      fi
      echo "Stopping network ${NETWORK_NAME}"
      drop-network
      echo
    done
  fi
  echo "================================="
  echo
done

# Finish log files
echo "Finishing log files"
finish-logs
echo

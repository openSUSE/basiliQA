#! /bin/bash
#
# cloud-setup.sh
# Setup of cloud for basiliQA

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

name="$1"

INSTANCES_QUOTA=80
RAM_QUOTA=100
VCPU_QUOTA=80
FLOATINGIP_QUOTA=80
PORT_QUOTA=100

# Check cloud name or IP address
if [ -z "$name" ]; then
  echo "Please specify cloud name" >&2
  exit 1
fi

# Actions that have to be done directly on the dashboard
read -r -d '' <<'EOF' SCRIPT

# Create "basiliqa" user
source .openrc
openstack user create --password opensuse basiliqa
openstack role add  --user basiliqa --project openstack admin
openstack user list
EOF
ssh-keygen -R $name
ssh -oStrictHostKeyChecking=no root@$name "$SCRIPT"

# Now we can use the cloud API
source cloud-rc.sh $name

# Create new flavors
openstack flavor create --id 6 --ram 1024 --disk 18 --vcpus 1 m1.smaller
openstack flavor create --id 7 --ram 2048 --disk 20 --vcpus 2 m1.ltp
openstack flavor set --property hw_rng:allowed=True m1.smaller
openstack flavor set --property hw_rng:allowed=True m1.ltp

# Create security rules
openstack security group rule create --ethertype IPv4 --protocol icmp --remote-ip 0.0.0.0/0 default
openstack security group rule create --ethertype IPv4 --protocol tcp --remote-ip 0.0.0.0/0 default
openstack security group rule create --ethertype IPv4 --protocol udp --remote-ip 0.0.0.0/0 default
openstack security group rule create --ethertype IPv6 --protocol icmpv6 --remote-ip ::/0 default
openstack security group rule create --ethertype IPv6 --protocol tcp --remote-ip ::/0 default
openstack security group rule create --ethertype IPv6 --protocol udp --remote-ip ::/0 default
openstack security group show default

# Setup quotas
openstack quota set --instances    $INSTANCES_QUOTA
openstack quota set --ram          $(($RAM_QUOTA * 1024))
openstack quota set --cores        $VCPU_QUOTA
openstack quota set --floating-ips $FLOATINGIP_QUOTA
openstack quota set --ports        $PORT_QUOTA
openstack quota show

# Create floating IPs
for ((i = 0; i < $FLOATINGIP_QUOTA; i++)); do
  openstack floating ip create floating >/dev/null
done
openstack floating ip list

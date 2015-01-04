#!/usr/bin/env bash

set -euo pipefail
set -x

if [[ $# -ne 1 ]] ; then
	echo "Usage : $0 [controller|networking|compute]" 
	exit 1
fi

source common.sh

install_common()
{
	# this script must be run as root (use sudo)
	if [[ $(id -u) -ne 0 ]] ; then
		echo "Please run as root"
		exit 1
	fi
	apt-get install ubuntu-cloud-keyring
	echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
		"trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
	apt-get update && apt-get -y upgrade
	apt-get -y install ntp python-mysqldb
}

install_controller()
{
	echo "######## Installing the Controller Node..."
	install_common
	apt-get -y install keystone python-keystoneclient mariadb-server mysql rabbitmq-server
	# Configure Networking
	cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $CONTROLLER_NODE_MGMT_IFACE_NAME
iface $CONTROLLER_NODE_MGMT_IFACE_NAME inet static
        address $CONTROLLER_NODE_MGMT_IP_ADDR
        netmask $MGMT_NETWORK_MSK

auto $CONTROLLER_NODE_API_IFACE_NAME
iface $CONTROLLER_NODE_API_IFACE_NAME inet static
        address $CONTROLLER_NODE_API_IP_ADDR
        netmask $API_NETWORK_MSK

auto $CONTROLLER_NODE_NAT_IFACE_NAME
iface $CONTROLLER_NODE_NAT_IFACE_NAME inet dhcp
EOF
	# Configure NTP
	cat > /etc/ntp.conf <<EOF
driftfile /var/lib/ntp/ntp.drift

server 3.pool.ntp.org iburst
restrict -4 default kod notrap nomodify
restrict -6 default kod notrap nomodify
EOF
	# Configure Hostnames
	hostname $CONTROLLER_NODE_HOSTNAME
	echo $CONTROLLER_NODE_HOSTNAME > /etc/hostname
	cat > /etc/hosts <<EOF
127.0.0.1	localhost
127.0.1.1	$CONTROLLER_NODE_HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

$NETWORK_NODE_MGMT_IP_ADDR $NETWORK_NODE_HOSTNAME
$COMPUTE_NODE_MGMT_IP_ADDR $COMPUTE_NODE_HOSTNAME
EOF
	# configure mariadb-server
	sed -i "2i bind-address=$CONTROLLER_NODE_MGMT_IP_ADDR" /etc/mysql/my.cnf
	sed -i "3i default-storage-engine=innodb" /etc/mysql/my.cnf
	sed -i "4i innodb_file_per_table" /etc/mysql/my.cnf
	sed -i "5i collation-server=utf8_general_ci" /etc/mysql/my.cnf
	sed -i "6i init-connect='SET NAMES utf8'" /etc/mysql/my.cnf
	sed -i "7i character-set-server=utf8" /etc/mysql/my.cnf
	service mysql restart
	mysql_secure_installation
	rabbitmqctl change_password guest $RABBIT_PASS
	mysqladmin -u root password $DB_PASS
	mysqladmin -u root -h $CONTROLLER_NODE_HOSTNAME password $DB_PASS
	return 0
}

install_networking()
{
	echo "####### Installing the Network Node..."
	install_common
	# Configure Networking
	cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $NETWORK_NODE_MGMT_IFACE_NAME
iface $NETWORK_NODE_MGMT_IFACE_NAME inet static
        address $NETWORK_NODE_MGMT_IP_ADDR
        netmask $MGMT_NETWORK_MSK

auto $NETWORK_NODE_TUN_IFACE_NAME
iface $NETWORK_NODE_TUN_IFACE_NAME inet static
        address $NETWORK_NODE_TUN_IP_ADDR
        netmask $TUN_NETWORK_MSK

auto $NETWORK_NODE_API_IFACE_NAME
iface $NETWORK_NODE_API_IFACE_NAME inet static
        address $NETWORK_NODE_API_IP_ADDR
        netmask $API_NETWORK_MSK

auto $NETWORK_NODE_NAT_IFACE_NAME
iface $NETWORK_NODE_NAT_IFACE_NAME inet dhcp
EOF
	# Configure NTP
	cat > /etc/ntp.conf <<EOF
driftfile /var/lib/ntp/ntp.drift

server $CONTROLLER_NODE_HOSTNAME iburst
EOF
	# Configure Hostnames
	hostname $NETWORK_NODE_HOSTNAME
	echo $NETWORK_NODE_HOSTNAME > /etc/hostname
	cat > /etc/hosts <<EOF
127.0.0.1	localhost
127.0.1.1	$NETWORK_NODE_HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

$CONTROLLER_NODE_MGMT_IP_ADDR $CONTROLLER_NODE_HOSTNAME
$COMPUTE_NODE_MGMT_IP_ADDR $COMPUTE_NODE_HOSTNAME
EOF
	return 0
}

install_compute()
{
	echo "###### Installing a Compute Node..."
	install_common
	# Configure Networking
	cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $COMPUTE_NODE_MGMT_IFACE_NAME
iface $COMPUTE_NODE_MGMT_IFACE_NAME inet static
        address $COMPUTE_NODE_MGMT_IP_ADDR
        netmask $MGMT_NETWORK_MSK

auto $COMPUTE_NODE_TUN_IFACE_NAME
iface $COMPUTE_NODE_TUN_IFACE_NAME inet static
        address $COMPUTE_NODE_TUN_IP_ADDR
        netmask $TUN_NETWORK_MSK

auto $COMPUTE_NODE_NAT_IFACE_NAME
iface $COMPUTE_NODE_NAT_IFACE_NAME inet dhcp
EOF
	# Configure NTP
	cat > /etc/ntp.conf <<EOF
driftfile /var/lib/ntp/ntp.drift

server $CONTROLLER_NODE_HOSTNAME iburst
EOF
	# Configure Hostnames
	hostname $COMPUTE_NODE_HOSTNAME
	echo $COMPUTE_NODE_HOSTNAME > /etc/hostname
	cat > /etc/hosts <<EOF
127.0.0.1	localhost
127.0.1.1	$COMPUTE_NODE_HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

$CONTROLLER_NODE_MGMT_IP_ADDR $CONTROLLER_NODE_HOSTNAME
$NETWORK_NODE_MGMT_IP_ADDR $NETWORK_NODE_HOSTNAME
EOF
	return 0
}

case "$1" in
"compute")
	install_compute
	exit $?
	;;
"controller" | "control")
	install_controller
	exit $?
	;;
"networking" | "network")
	install_networking
	exit $?
	;;
*)
	echo "Usage : $0 [controller|networking|compute]" 
	exit 1
	;;
esac
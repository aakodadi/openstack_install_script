openstack_install_script
========================
Uncomplete Project

This script is writen on Ubuntu Server 14.04 x86_64 GNU/Linux (kernel release : 3.13.0-43-generic)

Objectif :
Install and configure openstack services according to node type.

This is how to use it :
	in a control node :
# ./install_apt_juno.sh controller

	in a network node :
# ./install_apt_juno.sh networking

	in a compute node :
# ./install_apt_juno.sh compute

Note : The "#" means you have to run this commande as root (or using sudo commande)
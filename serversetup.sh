#!/bin/bash

###################################################
#
#   ServerSetup - written by Justin Ohneiser
# ------------------------------------------------
# This program will install and configure the
# server portion of the NetBridge system.
#
# [Warning]:
# This script comes as-is with no promise of functionality or accuracy.  I strictly wrote it for personal use
# I have no plans to maintain updates, I did not write it to be efficient and in some cases you may find the
# functions may not produce the desired results so use at your own risk/discretion. I wrote this script to
# target machines in a lab environment so please only use it against systems for which you have permission!!
#-------------------------------------------------------------------------------------------------------------
# [Modification, Distribution, and Attribution]:
# You are free to modify and/or distribute this script as you wish.  I only ask that you maintain original
# author attribution and not attempt to sell it or incorporate it into any commercial offering (as if it's
# worth anything anyway :)
#
# Designed for use in Ubuntu 16.04
###################################################

Y="\033[93m"
G="\033[92m"
R="\033[91m"
END="\033[0m"

if [[ $EUID -ne 0 ]]; then
  echo -e $R"[-] Script must be run as root"$END
  exit 1
fi

declare -a ISSUES

function check() {
  if [ $? -ne 0 ]; then
    echo -e $R"[-] Error with: $1"$END
    ISSUES[${#ISSUES[*]}]="Error with: $1"
    return 1
  fi
  return 0
}

echo "=============================================="
echo "         OpenVPN Bridge Installer"
echo "                  SERVER"
echo ""
echo "Intended for installation on Ubuntu 16.04."
echo ""
echo "Based off the instructions found here:"
echo "https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04"
echo "=============================================="

echo -e $Y"[*] Updating system..."$END
apt-get update
apt-get upgrade -y
apt-get install openvpn easy-rsa -y
check "System update"

#
# ======= Configure Certificate Authority =======
#

echo -e $Y"[*] Configuring certificate authority..."$END
dir="/root/openvpn-ca"
make-cadir $dir
cd $dir
sed -i -- 's/export KEY_NAME=/export KEY_NAME="server"# /g' $dir/vars
source $dir/vars
$dir/clean-all
$dir/build-ca
check "CA configuration"

echo -e $Y"[*] Building server certificates..."$END
$dir/build-key-server server
$dir/build-dh
openvpn --genkey --secret $dir/keys/ta.key
check "Server certificate build"

echo -e $Y"[*] Building client certificates..."$END
source $dir/vars
$dir/build-key client1
$dir/build-key client2
check "Client certificate build"

#
# ======= Configure OpenVPN Server =======
#

echo -e $Y"[*] Configuring OpenVPN server..."$END
cp $dir/keys/ca.crt $dir/keys/ca.key $dir/keys/server.crt $dir/keys/server.key $dir/keys/ta.key $dir/keys/dh2048.pem /etc/openvpn
check "Moving OpenVPN key files"
dir="/etc/openvpn"
cd $dir

echo -e $Y"[*] Adding openvpn user..."$END
useradd -s /usr/sbin/nologin -r -M -d /dev/null openvpn
check "Adding openvpn user"

echo -e $Y"[*] Adding OpenVPN server configuration..."$END
echo 'port 443' > $dir/server.conf
echo 'proto tcp' >> $dir/server.conf
echo 'dev tap' >> $dir/server.conf
echo 'ca ca.crt' >> $dir/server.conf
echo 'cert server.crt' >> $dir/server.conf
echo 'dh dh2048.pem' >> $dir/server.conf
echo 'ifconfig-pool-persist ipp.txt' >> $dir/server.conf
echo 'server-bridge 10.8.0.4 255.255.255.0 10.8.0.50 10.8.0.100' >> $dir/server.conf
echo 'client-to-client' >> $dir/server.conf
echo 'tls-auth ta.key 0' >> $dir/server.conf
echo 'key-direction 0' >> $dir/server.conf
echo 'cipher AES-128-CBC' >> $dir/server.conf
echo 'auth SHA256' >> $dir/server.conf
echo 'comp-lzo' >> $dir/server.conf
echo 'user openvpn' >> $dir/server.conf
echo 'group nogroup' >> $dir/server.conf
echo 'persist-key' >> $dir/server.conf
echo 'persist-tun' >> $dir/server.conf
echo 'status openvpn-status.log' >> $dir/server.conf
echo 'verb 3' >> $dir/server.conf
check "Building $dir/server.conf"

echo -e $Y"[*] Laying out OpenVPN server scripts..."$END
mkdir /etc/openvpn/scripts
touch /etc/openvpn/scripts/up.sh
chmod 700 /etc/openvpn/scripts/up.sh
touch /etc/openvpn/scripts/down.sh
chmod 700 /etc/openvpn/scripts/down.sh
touch /etc/openvpn/scripts/connect.sh
chmod 700 /etc/openvpn/scripts/connect.sh
touch /etc/openvpn/scripts/disconnect.sh
chmod 700 /etc/openvpn/scripts/disconnect.sh
check "Laying out OpenVPN server scripts"

echo -e $Y"[*] Enabling openvpn user to run OpenVPN server scripts..."$END
bash -c 'echo "openvpn ALL=NOPASSWD: /etc/openvpn/scripts/up.sh" | (EDITOR="tee -a" visudo)'
bash -c 'echo "openvpn ALL=NOPASSWD: /etc/openvpn/scripts/down.sh" | (EDITOR="tee -a" visudo)'
bash -c 'echo "openvpn ALL=NOPASSWD: /etc/openvpn/scripts/connect.sh" | (EDITOR="tee -a" visudo)'
bash -c 'echo "openvpn ALL=NOPASSWD: /etc/openvpn/scripts/disconnect.sh" | (EDITOR="tee -a" visudo)'
check "Adding openvpn sudo access to scripts"

echo -e $Y"[*] Enabling OpenVPN server scripts in OpenVPN server configuration..."$END
echo "script-security 2" >> $dir/server.conf
echo "up '/usr/bin/sudo /etc/openvpn/scripts/up.sh'" >> $dir/server.conf
echo "down '/usr/bin/sudo /etc/openvpn/scripts/down.sh'" >> $dir/server.conf
echo "client-connect '/usr/bin/sudo /etc/openvpn/scripts/connect.sh'" >> $dir/server.conf
echo "client-disconnect '/usr/bin/sudo /etc/openvpn/scripts/disconnect.sh'" >> $dir/server.conf
check "Adding scripts to OpenVPN server configuration"

echo -e $Y"[*] Enabling systemctl portforwarding..."$END
sed -i -- 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
check "Enabling systemctl portforwarding"

echo -e $Y"[*] Enabling OpenVPN server to run at boot..."$END
systemctl enable openvpn@server
check "Enabling OpenVPN server to run at boot"

#
# ======= Configure OpenVPN Client =======
#
echo -e $Y"[*] Creating folder for OpenVPN client configuration files..."$END
dir="/root/client-configs"
mkdir -p $dir/files
cd $dir
chmod 700 $dir/files
check "Creating /root/client-configs/files"

echo -e $Y"[*] Creating base model for client configuration file generation..."$END
echo "client" > $dir/base.conf
echo "dev tap" >> $dir/base.conf
echo "proto tcp" >> $dir/base.conf
read -p "What is the server IP address? " ip_address
echo "remote $ip_address 443" >> $dir/base.conf
echo "resolv-retry infinite" >> $dir/base.conf
echo "nobind" >> $dir/base.conf
echo "user nobody" >> $dir/base.conf
echo "group nogroup" >> $dir/base.conf
echo "persist-key" >> $dir/base.conf
echo "persist-tun" >> $dir/base.conf
echo "remote-cert-tls server" >> $dir/base.conf
echo "cipher AES-128-CBC" >> $dir/base.conf
echo "auth SHA256" >> $dir/base.conf
echo "comp-lzo" >> $dir/base.conf
echo "verb 3" >> $dir/base.conf
echo "script-security 2" >> $dir/base.conf
echo "up /etc/openvpn/update-resolv-conf" >> $dir/base.conf
echo "down /etc/openvpn/update-resolv-conf" >> $dir/base.conf
check "Creating client config base"

echo -e $Y"[*] Creating client configuration generation script..."$END
echo '#!/bin/bash' > $dir/make_config.sh
echo '# First argument: Client identifier' >> $dir/make_config.sh
echo 'KEY_DIR=~/openvpn-ca/keys' >> $dir/make_config.sh
echo 'OUTPUT_DIR='$dir'/files' >> $dir/make_config.sh
echo 'BASE_CONFIG='$dir'/base.conf' >> $dir/make_config.sh
echo 'cat ${BASE_CONFIG} \' >> $dir/make_config.sh
echo '  <(echo -e '\''<ca>'\'') \' >> $dir/make_config.sh
echo '  ${KEY_DIR}/ca.crt \' >> $dir/make_config.sh
echo '  <(echo -e '\''</ca>\n<cert>'\'') \' >> $dir/make_config.sh
echo '  ${KEY_DIR}/${1}.crt \' >> $dir/make_config.sh
echo '  <(echo -e '\''</cert>\n<key>'\'') \' >> $dir/make_config.sh
echo '  ${KEY_DIR}/${1}.key \' >> $dir/make_config.sh
echo '  <(echo -e '\''</key>\n<tls-auth>'\'') \' >> $dir/make_config.sh
echo '  ${KEY_DIR}/ta.key \' >> $dir/make_config.sh
echo '  <(echo -e '\''</tls-auth>'\'') \' >> $dir/make_config.sh
echo '  > ${OUTPUT_DIR}/${1}.ovpn' >> $dir/make_config.sh
chmod 700 $dir/make_config.sh
check "Creating client config generator"

echo -e $Y"[*] Generating OpenVPN clients..."$END
$dir/make_config.sh client1
$dir/make_config.sh client2
check "Generating OpenVPN clients"

#
# ======= Completion =======
#

echo -e $G"[+] COMPLETE: Retrieve your client config files at $dir/files/"$END

echo -e $Y"[*] Issues encountered: ${#ISSUES[*]}"$END
if [ ${#ISSUES[*]} -ne 0 ]; then
  for i in "${ISSUES[*]}"
    do echo -e $R"\t- $i"$END
  done
fi

echo -e $Y"[*] TODO: Configure firewall to allow the following INPUTs:"$END
echo -e "\t- 443/tcp"
echo -e $Y"[*] TODO: Add status alerts to the scripts found in /etc/openvpn/scripts"$END

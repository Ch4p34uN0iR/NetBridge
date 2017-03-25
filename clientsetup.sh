#!/bin/bash

###################################################
#
#   ClientSetup - written by Justin Ohneiser
# ------------------------------------------------
# This program will install and configure the
# client portion of the NetBridge system.
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
# [Source]:
# https://www.offensive-security.com/kali-linux/kali-rolling-iso-of-doom
#
# Designed for use on a Raspberry Pi running
# kali-2.1.2-rpi2
###################################################

Y="\033[93m"
G="\033[92m"
R="\033[91m"
END="\033[0m"

if [[ $EUID -ne 0 ]]; then
  echo -e $R"[-] Script must be run as root"$END
  exit 1
fi

if [ -z $1 ]; then
  echo -e $Y"Usage:"$END
  echo -e $Y"$0 <client1.ovpn>"$END
  exit 2
elif [ ! -f $1 ]; then
  echo -e $R"[-] File not found: $1"$END
  echo -e $Y"Usage:"$END
  echo -e $Y"$0 <client1.ovpn>"$END
  exit 2
fi

declare -a ISSUES

function check() {
  if [ $?!=0 ]; then
    echo -e $R"[-] Error with: $1"$END
    ISSUES[${#ISSUES[*]}]="Error with: $1"
  fi
}

echo "=============================================="
echo "         OpenVPN Bridge Installer"
echo "                  CLIENT"
echo ""
echo "Intended for installation on kali-2.1.2-rpi2"
echo ""
echo "Based off the instructions found here:" 
echo "https://www.offensive-security.com/kali-linux/kali-rolling-iso-of-doom" 
echo "=============================================="


echo -e $Y"[*] Updating system..."$END
apt-get update
apt-get dist-upgrade -y
apt autoremove
apt-get install -y netdiscover tcpdump
check "System update"

#
# ======= Configure OpenVPN Client =======
#

echo -e $Y"[*] Installing OpenVPN..."$END
apt-get install openvpn -y
check "OpenVPN install"

echo -e $Y"[*] Placing Configuration file..."$END
cp $1 /etc/openvpn/client1.conf
chmod 600 /etc/openvpn/client1.conf
check "Placing config file"

echo -e $Y"[*] Enabling OpenVPN to start at boot..."$END
sed -i -- 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn
systemctl enable openvpn
check "Enabling OpenVPN to start at boot"

#
# ======= Configure Port Forwarding =======
#

echo -e $Y"[*] Configuring port forwarding..."$END
sed -i -- 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
check "Configuring port forwarding"

echo -e $Y"[*] Making port forwarding persistent..."$END
apt-get install iptables-persistent -y
systemctl enable netfilter-persistent
check "Making port forwarding persistent"

#
# ======= Completion =======
#

echo -e $G"[+] Complete.  Be sure to remove $1"$END

echo -e $Y"[*] Issues encountered: ${#ISSUES[*]}"$END
for i in "${ISSUES[*]}"
  do echo -e $R"\t- $i"$END
done

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

if [[ $EUID -ne 0 ]]; then
  echo "[-] Script must be run as root"
  exit 1
fi

if [ -z $1 ]; then
  echo "Usage:"
  echo "$0 <client1.ovpn>
  exit 2
elif [ ! -f $1 ]; then
  echo "File not found: $1"
  echo "Usage:"
  echo "$0 <client1.ovpn>
  exit 2
fi

echo "=============================================="
echo "         OpenVPN Bridge Installer"
echo "                  CLIENT"
echo ""
echo "Intended for installation on kali-2.1.2-rpi2"
echo ""
echo "Based off the instructions found here:" 
echo "https://www.offensive-security.com/kali-linux/kali-rolling-iso-of-doom" 
echo "=============================================="


echo "[*] Updating system..."
apt-get update
apt-get dist-upgrade -y
apt autoremove
apt-get install -y netdiscover tcpdump

#
# ======= Configure OpenVPN Client =======
#

echo "[*] Installing OpenVPN..."
apt-get install openvpn -y

echo "[*] Placing Configuration file..."
cp $1 /etc/openvpn/client1.conf
chmod 600 /etc/openvpn/client1.conf

echo "[*] Enabling OpenVPN to start at boot..."
sed -i -- 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn
systemctl enable openvpn

#
# ======= Configure Port Forwarding =======
#

echo "[*] Configuring port forwarding..."
sed -i -- 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

echo "[*] Making port forwarding persistent..."
apt-get install iptables-persistent -y
systemctl enable netfilter-persistent

echo "[+] Complete.  Be sure to remove $1"

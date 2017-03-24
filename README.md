# NetBridge
A system designed to bridge into a target network with ease.

[Warning]:
These scripts come as-is with no promise of functionality or accuracy.  I strictly wrote them for personal use.  I have no plans to maintain updates, I did not write them to be efficient and in some cases you may find the functions may not produce the desired results so use at your own risk/discretion. I wrote these scripts to target machines in a lab environment so please only use it against systems for which you have permission!!

[Modification, Distribution, and Attribution]:
You are free to modify and/or distribute these scripts as you wish.  I only ask that you maintain original author attribution and not attempt to sell it or incorporate it into any commercial offering (as if it's worth anything anyway :)

[Sources]:
Server - https://www.digitalocean.com/community/tutorials/how-to-set-up-an-openvpn-server-on-ubuntu-16-04
Client - https://www.offensive-security.com/kali-linux/kali-rolling-iso-of-doom

------------------------------------------------

1) Spin up an Ubuntu 16.04 server and run serversetup.sh to install the NetBridge server.
- Produces two files, client1.ovpn and client2.ovpn.

2) Install kali-2.1.2-rpi2 onto a Raspberry Pi 2/3, copy over client1.ovpn, and run clientsetup.sh to install the NetBridge client.

[Result]: a droppable Raspberry Pi that, when plugged into your target network, will automatically connect to your Ubuntu OpenVPN server.  Connect to your Ubuntu OpenVPN server (openvpn client2.ovpn) and add a route to the target network through client1 (route add -net <target network range> gw <client1 vpn ip address>).

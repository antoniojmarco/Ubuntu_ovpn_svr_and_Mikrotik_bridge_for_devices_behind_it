
 # Ubuntu 20.04 + OpenVPN Server + Mikrotik OVPN client + bridge for device behind it
Tested on Ubuntu 20.04 OpenVPN (as server) and  MikroTik RBM33G 6.49.10 (as client).

## Step 1. Ubuntu OpenVPN Server installation.
You already have server with installed Ubuntu 20.04. Let's install OpenVPN svr!
Find and note down your local IP address and your public IP address 
```bash
ip a
ip a show eth0
dig +short myip.opendns.com @resolver1.opendns.com
dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}'
```
Update system
```bash
sudo apt update
sudo apt upgradeh
```
Download and run openvpn-install.sh script
```bash
wget https://git.io/vpn -O openvpn-install.sh
chmod +x openvpn-install.sh
```
Run openvpn-install.sh to install OpenVPN server
```bash
sudo ./openvpn-install.sh
```
Initializing the script:
create a new instance of OpenVPN server

'Welcome to this OpenVPN road warrior installer!'
1. Which IPv4 address should be used?:  (Provide the IPV4 network interface you want OpenVPN listening)
2. What port should OpenVPN listen to:  (Default port 1194)
3. Select a DNS server for the clients: (Google DNS are fast DNS server).
4. Enter a name for the first client:   (type your "user name" for create a client certificate)

Once the server is installed, the menu changes and will be as follows

Select an option
1. Add a new client
2. Revoke an existing client
3. Remove OpenVPN
4. Exit

After that you can modify openvpn server file  defaults if is necesary:
```bash
sudo nano /etc/openvpn/server/server.conf
```
Check your /etc/openvpn/server.conf:

```bash
local xxx.xxx.xxx.xxx #external ip of our vpn-server
port 1194 #port
proto tcp #protocol
dev tun   #type
#
ca      ca.crt
cert    server.crt
key     server.key
dh      dh.pem
#server cfg
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
#push pools
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
#push "route 10.0.0.0 255.255.252.0"
#push "route 172.16.0.0 255.255.0.0"
#
#route 172.16.0.0 255.255.0.0
#
keepalive 10 120
user nobody
group nobody
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
```
After script finish create Rules to open port to the internet:
```bash
sudo ufw allow ssh
sudo ufw allow 1194/tcp  # (1194 default) or service port defined
```
#### Routing 
Route tables depend on each scenario:

ej: route traffic from Mikrotik LAN to tunnel peer
```bash
sudo ip route add 172.16.0.0/16 via 10.8.0.2
```
Now you can start the OpenVPN service:
```bash
sudo systemctl start openvpn-server@server.service 
sudo systemctl status openvpn-server@server.service 
```
If you want start/stop/restart OpenVPN server We need to use the systemctl command:
```bash
sudo systemctl stop openvpn-server@server.service #<--- stop server
sudo systemctl start openvpn-server@server.service #<--- start server
sudo systemctl restart openvpn-server@server.service #<--- restart serve
sudo systemctl status openvpn-server@server.service #<--- get server status
```

Download into Mikrotik board certificate/key for the server:
```bash
key: /etc/openvpn/server/easy-rsa/pki/private/client.key
crt: /etc/openvpn/server/easy-rsa/pki/issued/client.crt
```
```bash
scp client.crt admin@xx.xx.xx.xx:/
scp client.key admin@xx.xx.xx.xx:/
```

#### Troubleshooting

Verify. Check if the device for the tunnel has appeared:
```bash
ifconfig tun0
```
Is assigned address and port for OpenVPN server?:
```bash
netstat -tupln
```
Errors and warnings
```bash
nano /var/log/openvpn.log
```
OpenVPN Clients connected
```bash
cat /var/log/openvpn-status.log
```
OpenVPN connection status
```bash
sudo ufw status
iptables -t nat -S
ip route list
tshark -i tun0
```
IPtables Troubleshooting
were (x)== level of log in ther work flow: https://inai.de/images/nf-packet-flow.png
```bash
iptables -t filter -I FORWARD (x) -d 10.0.0.2 -j LOG
watch iptables -t filter -vL FORWARD
```
That's all. Your OpenVPN server is ready!  Please note, if your OpenVPN server assigns the same IP's for all OpenVPN clients you need to use different certificates for all your vpn clients (go to 'Creating/deleting additional keys/certificates' step from this guide). Also keep in mind, commonName and name in your clients keys must be uniqe. For instance: client1, client2, client3, etc.
- - -

## Step 2. Mikrotik baseline configuration
### 

Enable ssh connection for login in 
https://help.mikrotik.com/docs/display/ROS/First+Time+Configuration#FirstTimeConfiguration-ConfiguringIPAccess

Acces to the router

```bash
ssh admin@xx.xx.xx.xx
```
```bash
  MMMM    MMMM       KKK                          TTTTTTTTTTT      KKK
  MMM MMMM MMM  III  KKK  KKK  RRRRRR     OOOOOO      TTT     III  KKK  KKK
  MMM  MM  MMM  III  KKKKK     RRR  RRR  OOO  OOO     TTT     III  KKKKK
  MMM      MMM  III  KKK KKK   RRRRRR    OOO  OOO     TTT     III  KKK KKK
  MMM      MMM  III  KKK  KKK  RRR  RRR   OOOOOO      TTT     III  KKK  KKK

  MikroTik RouterOS 6.49.10 (c) 1999-2017       http://www.mikrotik.com/

```
#### Check your Mikrotik OS version
All the code in this repo is for version 6.49.10. If yours is older than that go ahead and upgrade it first.
```bash
system package update download
```
#### Mikrotik basic router config
Reset previous config (if necessary)

```bash
/system reset-configuration no-defaults=yes skip-backup=yes
set passwd /password
```
#### Create Local (LAN) interface

```bash
/ip address> add address=172.16.0.250/16 interface=ether2
```

#### Create Internet (WAN) connection interface 

Dynamic address configuration is the simplest one. You just need to set up a DHCP client on the public interface. DHCP client will receive information from an internet service provider (ISP) and set up an IP address, DNS, NTP servers, and default route for you.

```bash
/ip dhcp-client add disabled=no interface=ether1
```

#### MAC Connectivity Access

MAC server section allows you to configure MAC Telnet Server, MAC WinBox Server and MAC Ping Server on RouterOS device.

```bash
/interface list add name=listBridge
/interface list member add list=listBridge interface=ether2
/interface list member add list=listBridge interface=ether3
/tool mac-server 
set allowed-interface-list=listBridge
/tool mac-server mac-winbox 
set allowed-interface-list=listBridge
```

#### Neighbor Discovery

MikroTik Neighbor discovery protocol is used to show and recognize other MikroTik routers in the network. Disable neighbor discovery on public interfaces.

```bash
/ip neighbor discovery-settings set discover-interface-list=listBridge
```

#### IP Connectivity Access

Besides the fact that the firewall protects your router from unauthorized access from outer networks, it is possible to restrict username access for the specific IP address

```bash
/user set 0 allowed-address=x.x.x.x/yy
```
IP connectivity on the public interface must be limited in the firewall. We will accept only ICMP(ping/traceroute), IP Winbox, and ssh access.

```bash
/ip firewall filter
  add chain=input connection-state=established,related action=accept comment="accept established,related";
  add chain=input connection-state=invalid action=drop;
  add chain=input in-interface=ether1 protocol=icmp action=accept comment="allow ICMP";
  add chain=input in-interface=ether1 protocol=tcp port=8291 action=accept comment="allow Winbox";
  add chain=input in-interface=ether1 protocol=tcp port=22 action=accept comment="allow SSH";
  add chain=input in-interface=ether1 action=drop comment="block everything else";
```

#### Administrative Services

Although the firewall protects the router from the public interface, you may still want to disable RouterOS services. Most of RouterOS administrative tools are configured at  the /ip service menu; Keep only secure ones,

```bash
/ip service disable telnet,ftp,api
```

#### NAT Configuration

At this point, PC is not yet able to access the Internet, because locally used addresses are not routable over the Internet. Remote hosts simply do not know how to correctly reply to your local address.
The solution for this problem is to change the source address for outgoing packets to routers public IP. This can be done with the NAT rule:

```bash
/ip firewall nat
  add chain=srcnat out-interface=ether1 action=masquerade
```

#### Port Forwarding

Some client devices may need direct access to the internet over specific ports. For example, a client with an IP address 192.168.88.254 must be accessible by Remote desktop protocol (RDP).After a quick search on Google, we find out that RDP runs on TCP port 3389. Now we can add a destination NAT rule to redirect RDP to the client's PC.

NAT CONFIG

ITEM            IP         HTTP     SSH    video
Router 0:  172.16.0.250    8080    22
HM     1:  172.16.1.252   18080    12222   1554
LAVA   2:  172.16.2.252   28080    22222
LAVA   3:  172.16.3.252   38080    32222

```bash
/ip firewall nat
```

#  HM item1 
```bash
#  port http -> (18080)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=18080 protocol=tcp to-addresses=172.16.1.252 to-ports=18080

# port ssh -> (12222)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=12222 protocol=tcp to-addresses=172.16.1.252 to-ports=12222

# port 554 -> (1554)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT ((in traffic)"  in-interface=ovpn-client port
=1554 protocol=tcp to-addresses=172.16.1.252 to-ports=1554
```

#  LAVA 1 item 2
```bash
#  port http -> (28080)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=28080 protocol=tcp to-addresses=172.16.2.252 to-ports=28080

# port ssh -> (22222)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=22222 protocol=tcp to-addresses=172.16.2.252 to-ports 22222
```
#  LAVA 2 item 3
```bash
#  port http -> (38080)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=38080 protocol=tcp to-addresses=172.16.3.252 to-ports=38080

# port ssh -> (32222)
add action=dst-nat chain=dstnat comment="Port forwarding DNAT (in traffic)"  in-interface=ovpn-client port=32222 protocol=tcp to-addresses=172.16.2.252 to-ports 32222
```

#### Write configuration
```bash
export file=configv1_router_only
```


## Step 3. Mikrotik router as OpenVPN Client.
### Mikrotik OVPN client installation.
#### Please, keep in mind:
* UDP is not supported
* LZO compression is not supported
* Username/passwords are not mandatory, so the best practice is certificate auth
##### :

#### Mikrotik config OpenVPN client
You'll need some files from your OpenVPN server or VPN provider, only 2 files are required: client.crt  client.key. Upload and import these certificates to your Mikrotik.
```bash
scp client.crt admin@xx.xx.xx.xx:/
scp client.key admin@xx.xx.xx.xx:/
certificate import file-name=client.crt
certificate import file-name=client.key
```
You can check that it's worked:
```bash
certificate print

Flags: K - private-key, D - dsa, L - crl, C - smart-card-key, A - authority, I - issued, R - revoked, E - expired, T - trusted 
 #          NAME               COMMON-NAME        SUBJECT-ALT-NAME      FINGERPRINT              
 0 K      T client.crt_0       OpenVPN                                  12911f9e101be5b3e15cd...
```
#### Create an OpenVPN PPP profile
This section contains all the details of how you will connect to the server, the following worked for me.
```bash
ppp profile add name=OVPN-client change-tcp-mss=yes only-one=yes use-encryption=yes use-mpls=no use-compression=no
```
You can check that it's worked:
```bash
ppp profile print

Flags: * - default 
 0 * name="default" use-mpls=default use-compression=default use-encryption=default only-one=default change-tcp-mss=yes use-upnp=default 
     address-list="" on-up="" on-down="" 
 1   name="OVPN-client" use-mpls=no use-compression=no use-encryption=yes only-one=yes change-tcp-mss=yes use-upnp=default address-list="" 
     on-up="" on-down="" 
 2 * name="default-encryption" use-mpls=default use-compression=default use-encryption=yes only-one=default change-tcp-mss=yes 
     use-upnp=default address-list="" on-up="" on-down=""
```
#### Create an OpenVPN interface
Here we actually create an interface for the VPN connection. Important! Change xxx.xxx.xxx.xxx to your own server address (ip address or domain name). User/password properties seem to be mandatory on the client even if the server doesn't have auth-user-pass-verify enabled.
```bash
interface ovpn-client add name=ovpn-client connect-to=xxx.xxx.xxx.xxx port=1194 mode=ip user="openvpn" password="" profile=OVPN-client certificate=client.crt_0 auth=sha1 cipher=blowfish128 add-default-route=yes
```
Check out your new open-vpn connection:
```bash
interface ovpn-client print

Flags: X - disabled, R - running 
 0  R name="ovpn-client" mac-address=xx:xx:xx:xx:xx:xx max-mtu=1500 connect-to=xxx.xxx.xxx.xxx port=1194 mode=ip user="openvpn" password="" profile=OVPN-client certificate=client.crt_0 auth=sha1 cipher=blowfish128 add-default-route=yes
```
```bash
interface ovpn-client monitor 0
  status: connected
  uptime: 18h38m31s
  encoding: BF-128-CBC/SHA1
  mtu: 1500
```
#### Configure the firewall
```bash
/ip firewall filter>
add chain=forward action=passthrough 
add chain=forward action=fasttrack-connection connection-state=established,related log=no log-prefix="" 
add chain=forward action=accept connection-state=established,related log=no log-prefix="" 
add chain=forward action=drop connection-state=invalid log=no log-prefix="" 
add chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface=ether1 log=
no log-prefix="" 
```

ip firewall filter print
```bash
Flags: X - disabled, I - invalid, D - dynamic 
 0  D ;;; special dummy rule to show fasttrack counters
      chain=forward action=passthrough 
 1    ;;; fasttrack
      chain=forward action=fasttrack-connection connection-state=established,related log=no log-prefix="" 
 2    ;;; accept established,related
      chain=forward action=accept connection-state=established,related log=no log-prefix="" 
 3    ;;; drop invalid
      chain=forward action=drop connection-state=invalid log=no log-prefix="" 
 4    ;;; drop all from WAN not DSTNATed
      chain=forward action=drop connection-state=new connection-nat-state=!dstnat in-interface=ether1 log=no log-prefix="" 
 5    chain=input action=accept protocol=icmp log=no log-prefix="" 
 6    chain=input action=accept connection-state=established log=no log-prefix="" 
 7    chain=input action=accept connection-state=related log=no log-prefix="" 
 8    chain=input action=drop in-interface=pppoe-out1 log=no log-prefix="" 
```

#### Configure masquerade
We add new masquerade NAT rule:
```bash
ip firewall nat add chain=srcnat action=masquerade out-interface=ovpn-client log=no log-prefix=""
```
Check out it:
```bash
ip firewall nat print

Flags: X - disabled, I - invalid, D - dynamic 
 0    chain=srcnat action=masquerade out-interface=pppoe-out1 log=no log-prefix=""  
 1    chain=srcnat action=masquerade out-interface=ovpn-client log=no log-prefix=""
```
#### Configure Policy Based Routing
Here we add some resources that we wanna using through our OpenVPN client. We can use domains or ip's in address:
```bash
ip firewall address-list add list="OpenVPN" address="10.0.0.1"
ip firewall address-list add list="OpenVPN" address="10.0.0.2"
ip firewall address-list add list="OpenVPN" address="10.8.0.1"
ip firewall address-list add list="OpenVPN" address="10.8.0.2"
/ip firewall filter>
add action=accept chain=input comment="Allow OpenVPN" in-interface=all-ppp protocol=tcp src-address-list=OpenVPN
```
#### Configure mangle
Then we set up mangle rule which marks packets coming from the local network and destined for the internet with a mark named 'vpn_traffic':
```bash
ip firewall mangle add chain=prerouting action=mark-routing new-routing-mark=vpn_traffic passthrough=yes dst-address-list=OpenVPN log=no
```
Check out it:
```bash
ip firewall mangle print

Flags: X - disabled, I - invalid, D - dynamic
 0  D ;;; special dummy rule to show fasttrack counters
      chain=prerouting action=passthrough
 1  D ;;; special dummy rule to show fasttrack counters
      chain=forward action=passthrough
 2  D ;;; special dummy rule to show fasttrack counters
      chain=postrouting action=passthrough
 3    chain=prerouting action=mark-routing new-routing-mark=vpn_traffic passthrough=yes dst-address-list=OpenVPN log=no log-prefix=""
```
#### Configure routing
Next we tell the router that all traffic with the 'vpn_traffic' mark should go through the VPN interface:
```bash
/ip route
add gateway="ovpn-client" type="unicast" routing-mark="vpn_traffic"
add dst-address=172.16.0.0/16 gateway=ovpn-client
```
Check out it:
```bash
ip route print

Flags: X - disabled, A - active, D - dynamic, C - connect, S - static, r - rip, b - bgp, o - ospf, m - mme, 
B - blackhole, U - unreachable, P - prohibit 
 #      DST-ADDRESS        PREF-SRC        GATEWAY            DISTANCE
 0 A S  0.0.0.0/0                          ovpn-client               1
 1 ADS  0.0.0.0/0                          10.10.1.4                 0
 2  DS  0.0.0.0/0                          10.0.0.1                  1
 3 ADC  10.0.0.1/32        10.0.0.6        ovpn-client               0
 4 ADC  10.10.1.4/32       10.10.16.25     pppoe-out1                0
 5 ADS  xxx.xxx.xxx.xxx/xx                 10.10.1.4                 0
 6 ADC  192.168.1.0/24     192.168.1.1     bridge                    0
```
Please note, if you not see ADS route with your OpenVPN server ip you have forgotten add-default-route=yes in your ovpn-client.
- - -
## Using Policy Based Routing for disabling blocking resources by your ISP
If you want to use this manual for disabling blocking resources by your ISP, use not your ISP DNS. For instance you can use free DNS by Google (8.8.8.8 or 8.8.4.4).

#### Step 1. Disable providers DNS's.
Go to PPP > Interface > Your connection (in this case it's pppoe-out1) > Dial Out and disable 'Use Peer DNS' option.
```bash
interface pppoe-client set name="pppoe-out1" max-mtu=auto max-mru=auto mrru=disabled interface=ether1 user="########" password="########" profile=default keepalive-timeout=60 service-name="" ac-name="" add-default route=yes default-route-distance=0 dial-on-demand=no use-peer-dns=no allow=pap,chap,mschap1,mschap2
```
#### Step 2. Add new DNS.
```bash
ip dns set servers=8.8.8.8
```
#### Step 3. Clear your old DNS cache.
```bash
ip dns cache flush
/system reboot
```
#### clear logs and Finally Write configuration
```bash
/system logging action set memory memory-lines=1
/system logging action set memory memory-lines=1000
/
export file=configv1_router_openvpn_client
```

#### Troubleshooting

OpenVPN connection status
```bash
interface ovpn-client monitor 0
```
Connectivity status:
```bash
/interface ovpn-client print
/ip route print detail
/ip firewall nat print
/ip address print
/interface print
```
CPU usage:
```bash
/tool profile cpu=all
- - -
## Enjoy!!

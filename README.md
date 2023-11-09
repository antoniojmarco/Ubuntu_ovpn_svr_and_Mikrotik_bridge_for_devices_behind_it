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
"Press any key to continue..."

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
#certs
ca      ca.crt
cert    server.crt
key     server.key
dh      dh.pem
#server cfg
server 10.0.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
#push pools
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
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
Verify. Check if the device for the tunnel has appeared:
```bash
ifconfig tun0
```
Is assigned address and port for OpenVPN server?:
```bash
netstat -tupln
```
That's all. Your OpenVPN server is ready!  Please note, if your OpenVPN server assigns the same IP's for all OpenVPN clients you need to use different certificates for all your vpn clients (go to 'Creating/deleting additional keys/certificates' step from this guide). Also keep in mind, commonName and name in your clients keys must be uniqe. For instance: client1, client2, client3, etc.
- - -

## Step 2. Mikrotik router as OpenVPN Client.
### Mikrotik OVPN client installation.
#### Please, keep in mind:
* UDP is not supported
* LZO compression is not supported
* Username/passwords are not mandatory, so the best practice is certificate auth
##### :
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
#### Mikrotik basic config
Reset previous config (if necessary)

```bash
/system reset-configuration no-defaults=yes skip-backup=yes
Set passwd /password
```
Local (LAN) interface config

```bash
/interface bridge add name=local
/interface bridge port add interface=ether2 bridge=local
/ip address add address=172.16.0.250/16 interface=local
```
Internet (WAN)connection interface config

```bash
/ip dhcp-client add disabled=no interface=ether1
```


```bash




```


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
ip firewall filter print

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
ip firewall address-list add list="OpenVPN" address="somehost.com"
ip firewall address-list add list="OpenVPN" address="xxx.xxx.xxx.xxx"
ip firewall address-list add list="OpenVPN" address="xxx.xxx.xxx.xxx/xx"
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
ip route add gateway="ovpn-client" type="unicast" routing-mark="vpn_traffic"
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
```
- - -
## Enjoy!!

# nov/10/2023 12:47:03 by RouterOS 6.49.10
# software id = 6AVE-TZPR
#
# model = RBM33G
# serial number = HED08PGK7YP
/interface bridge
add name=local
/interface ethernet
set [ find default-name=ether1 ] comment=WAN
/interface list
add name=listBridge
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ppp profile
add change-tcp-mss=yes name=OVPN-client only-one=yes use-compression=no \
    use-encryption=yes use-mpls=no
/interface ovpn-client
add add-default-route=yes certificate=mikrotik.crt_0 connect-to=\
    38.242.230.195 mac-address=FE:A0:1C:48:7D:33 name=ovpn-client port=4194 \
    profile=OVPN-client user=mikrotik
/interface bridge port
add bridge=local interface=ether2
/ip neighbor discovery-settings
set discover-interface-list=listBridge
/interface list member
add interface=local list=listBridge
/ip address
add address=172.16.0.250/16 interface=local network=172.16.0.0
/ip dhcp-client
add disabled=no interface=ether1
/ip firewall filter
add action=accept chain=input comment="accept established,related" \
    connection-state=established,related
add action=drop chain=input connection-state=invalid
add action=accept chain=input comment="allow ICMP" in-interface=ether1 \
    protocol=icmp
add action=accept chain=input comment="allow Winbox" in-interface=ether1 \
    port=8291 protocol=tcp
add action=accept chain=input comment="allow SSH" in-interface=ether1 port=22 \
    protocol=tcp
add action=drop chain=input comment="block everything else" in-interface=\
    ether1
add action=accept chain=input in-interface=all-ppp in-interface-list=all \
    protocol=icmp
add action=accept chain=input in-interface=ovpn-client protocol=icmp
add action=accept chain=input in-interface=ovpn-client port="" protocol=tcp \
    src-port=22
/ip firewall mangle
add action=mark-routing chain=prerouting dst-address-list=OpenVPN \
    new-routing-mark=vpn_traffic passthrough=yes
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether1
# no interface
add action=masquerade chain=srcnat out-interface=*7
add action=masquerade chain=srcnat out-interface=ovpn-client
/ip route
add distance=1 gateway=ovpn-client routing-mark=vpn_traffic
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
/system clock
set time-zone-name=Europe/Madrid
/tool mac-server
set allowed-interface-list=listBridge
/tool mac-server mac-winbox
set allowed-interface-list=listBridge
/tool netwatch
add host=10.8.0.1
add host=10.0.0.1
add host=10.0.0.2
add host=172.16.200.200
add host=192.168.1.1
/tool sniffer
set filter-interface=ovpn-client
/tool traffic-monitor
add interface=ether1 name=tmon1

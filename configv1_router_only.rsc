# oct/31/2023 11:53:12 by RouterOS 6.49.10
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
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether1
/ip route
add distance=1 gateway=172.16.0.250
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
/tool traffic-monitor
add interface=ether1 name=tmon1

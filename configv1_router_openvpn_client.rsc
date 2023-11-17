# nov/17/2023 12:23:01 by RouterOS 6.49.10
# software id = 6AVE-TZPR
#
# model = RBM33G
# serial number = HED08PGK7YP
/interface ethernet
set [ find default-name=ether1 ] comment=WAN
set [ find default-name=ether2 ] comment=LAN
/interface list
add name=listBridge
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip hotspot profile
set [ find default=yes ] html-directory=hotspot
/ppp profile
add change-tcp-mss=yes name=OVPN-client only-one=yes use-compression=no \
    use-encryption=yes use-mpls=no
/interface ovpn-client
add add-default-route=yes certificate=mikrotik.crt_0 connect-to=\
    38.242.230.195 mac-address=FE:1F:7C:29:F2:27 name=ovpn-client port=4194 \
    profile=OVPN-client user=mikrotik
/ip neighbor discovery-settings
set discover-interface-list=listBridge
/interface list member
add interface=ether2 list=listBridge
add interface=ether3 list=listBridge
/ip address
add address=192.168.88.1/24 comment=defconf interface=ether1 network=\
    192.168.88.0
add address=172.16.0.250/16 interface=ether2 network=172.16.0.0
/ip dhcp-client
add disabled=no interface=ether1
/ip firewall address-list
add address=10.0.0.1 list=OpenVPN
add address=10.0.0.2 list=OpenVPN
add address=10.8.0.1 list=OpenVPN
add address=10.8.0.2 list=OpenVPN
add address=172.16.1.252 list=OpenVPN
/ip firewall filter
add action=accept chain=input comment="allow ICMP" in-interface=ether2 \
    protocol=icmp
add action=accept chain=input comment="allow Winbox" in-interface=ether1 \
    port=8291 protocol=tcp
add action=accept chain=input in-interface=ether3 port=8291 protocol=tcp
add action=accept chain=input comment="allow SSH" in-interface=ether2 port=22 \
    protocol=tcp
add action=passthrough chain=forward comment=\
    "special dummy rule to show fasttrack counters"
add action=fasttrack-connection chain=forward comment=fasttrack \
    connection-state=established,related
add action=accept chain=forward comment="accept established,related" \
    connection-state=established,related
add action=accept chain=input comment="Allow OpenVPN" in-interface=all-ppp \
    protocol=tcp src-address-list=OpenVPN
add action=drop chain=forward comment="drop invalid" connection-state=invalid \
    disabled=yes
add action=drop chain=forward comment="drop all from WAN not DSTNATed" \
    connection-nat-state=!dstnat connection-state=new in-interface=ether1
add action=drop chain=input comment="block everything else" disabled=yes \
    in-interface=ether1
/ip firewall mangle
add action=mark-routing chain=prerouting dst-address-list=OpenVPN \
    new-routing-mark=vpn_traffic passthrough=yes
/ip firewall nat
add action=masquerade chain=srcnat comment="NATs (out traffic)" \
    out-interface=ether1
add action=masquerade chain=srcnat out-interface=ovpn-client
add action=dst-nat chain=dstnat comment="Port forwarding DNAT ((in traffic)" \
    in-interface=ovpn-client port=18080 protocol=tcp to-addresses=\
    172.16.1.252 to-ports=18080
/ip route
add distance=1 gateway=ovpn-client
add distance=1 dst-address=172.16.0.0/16 gateway=ovpn-client
/ip service
set telnet disabled=yes
set ftp disabled=yes
set api disabled=yes
/system clock
set time-zone-name=Europe/Madrid
/tool mac-server
set allowed-interface-list=listBridge
/tool mac-server mac-winbox
set allowed-interface-list=listBridge


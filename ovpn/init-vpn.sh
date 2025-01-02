#! /bin/bash

SERVER_IP="127.0.0.1" #stunnel
LOCKFILE="/run/vpn-lock"
CLIENT_CONF_PATH="/etc/openvpn/clients_conf/"
CLIENT_CERT_PATH="/etc/openvpn/keys"
CLIENT_CERT_PREFIX="client"
USER_COUNT=2


generate_server_conf() {
    cat << EOF > /etc/openvpn/server.conf
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
duplicate-cn
keepalive 10 120
cipher AES-256-GCM
ncp-ciphers AES-256-GCM:AES-256-CBC
auth SHA512
persist-key
persist-tun
status openvpn-status.log
verb 1
tls-server
tls-version-min 1.2
tls-auth /etc/openvpn/ta.key 0
crl-verify /etc/openvpn/crl.pem
EOF
}

generate_user_conf() {
    client_id=$1
    mkdir -p $CLIENT_CONF_PATH

    cat << EOF > $CLIENT_CONF_PATH$client_id.ovpn
client
dev tun123
proto tcp
remote $SERVER_IP 65000
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA512
verb 3
tls-client
tls-version-min 1.2
key-direction 1
remote-cert-tls server

<ca>
$(cat /etc/openvpn/ca.crt)
</ca>

<cert>
$(cat $CLIENT_CERT_PATH/$client_id.crt)
</cert>

<key>
$(cat $CLIENT_CERT_PATH/$client_id.key)
</key>

<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF
}


generate_cert() {
    client_name=$1
    mode=${2:-"server"}
    dst_path=${3:-"/etc/openvpn"}

    mkdir -p $dst_path

    echo "Generate cert for $client_name"

    echo | easyrsa gen-req $client_name nopass &> /dev/null
    echo yes | easyrsa sign-req $mode $client_name &> /dev/null

    cp pki/issued/$client_name.crt pki/private/$client_name.key $dst_path
}


if [ ! -f $LOCKFILE ]; then
    touch $LOCKFILE

    mkdir -p /dev/net/

    if [ ! -c /dev/net/tun ]; then
        echo "Creating tun device."
        mknod /dev/net/tun c 10 200
    fi

    echo "Init PKI"
    easyrsa --batch init-pki &> /dev/null

    echo "Generate Diffie–Hellman"
    easyrsa --batch gen-dh &> /dev/null

    echo "Build CA"
    echo | easyrsa build-ca nopass &> /dev/null

    echo yes | openvpn --genkey --secret pki/ta.key &> /dev/null

    echo "Generate CRL"
    easyrsa --days=1000 gen-crl &> /dev/null

    cp pki/dh.pem pki/ca.crt pki/crl.pem pki/ta.key /etc/openvpn

    generate_cert "server"
    generate_server_conf

    for i in $(seq 1 $USER_COUNT) ; do 
        generate_cert "${CLIENT_CERT_PREFIX}_${i}" "client" $CLIENT_CERT_PATH
        echo "Generate openvpn conf for ${CLIENT_CERT_PREFIX}_${i}"
        generate_user_conf "${CLIENT_CERT_PREFIX}_${i}"
    done

    iptables -A INPUT -i eth0 -p tcp -m state --state NEW,ESTABLISHED --dport 1194 -j ACCEPT
    iptables -A OUTPUT -o eth0 -p tcp -m state --state ESTABLISHED --sport 1194 -j ACCEPT

    iptables -A INPUT -i tun0 -j ACCEPT
    iptables -A FORWARD -i tun0 -j ACCEPT
    iptables -A OUTPUT -o tun0 -j ACCEPT

    iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
fi

openvpn --config /etc/openvpn/server.conf

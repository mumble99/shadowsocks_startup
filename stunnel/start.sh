#! /bin/bash

CONN_STRING="vpn:1194"
IMAGE_NAME="stunnel"
CONF_NAME="stunnel.conf"
CERT_DIR="certs"
CA_CERT="$CERT_DIR/ca-cert.pem"
CA_KEY="$CERT_DIR/ca-key.pem"
SERVER_CERT="$CERT_DIR/server-cert.pem"
SERVER_KEY="$CERT_DIR/server-key.pem"
CLIENT_COUNT=2


generate_ca() {
    echo "Generate CA cert"

    dd if=/dev/urandom of=$CERT_DIR/rnd bs=256 count=1 2> /dev/null
    openssl req -new -x509 -days 10000 -batch -rand $CERT_DIR/rnd -config openssl.cnf -out $CA_CERT -keyout $CA_KEY 2> /dev/null
}

generate_signed_certs() {
    cert_path=$1
    key_path=$2

    echo "Generate cert"

    openssl genrsa -out $key_path 2048 2> /dev/null
    openssl req -new -key $key_path -out $CERT_DIR/req.csr -batch -config openssl.cnf 2> /dev/null
    openssl x509 -req -in $CERT_DIR/req.csr -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $cert_path -days 10000 2> /dev/null
}

generate_certs() {
    mkdir -p $CERT_DIR

    if [ -z "$(which openssl)" ] ; then
        echo "Please install openssl"
        exit 1
    fi

    generate_ca

    generate_signed_certs $SERVER_CERT $SERVER_KEY

    for i in $(seq 1 $CLIENT_COUNT) ; do
        generate_signed_certs "$CERT_DIR/client-cert-$i.pem" "$CERT_DIR/client-key-$i.pem"
    done
    
    rm -f $CERT_DIR/rnd $CERT_DIR/*.csr $CERT_DIR/*.srl
}


example_conf() {
    cat << EOF > /dev/stdout
;#------CLIENT-------
[vpn]
client = yes
accept = 127.0.0.1:65000
cert = $CLIENT_CERT
key = $CLIENT_KEY
CAfile = $CA_CERT
verify = 2
;#####################

EOF
}


create_server_conf() {
    cat << EOF > $CONF_NAME
foreground = yes

[vpn]
accept = 5050
connect = $CONN_STRING
cert = /etc/stunnel/server-cert.pem
key = /etc/stunnel/server-key.pem
CAfile = /etc/stunnel/ca.pem
verify = 2
EOF
}


start() {
    echo "Example configuration for client"
    example_conf

    generate_certs

    echo "Create server config"
    create_server_conf
    
    echo "Build docker image"
    docker build -t $IMAGE_NAME --build-arg CONF=$CONF_NAME --build-arg CA=$CA_CERT --build-arg CERT=$SERVER_CERT --build-arg KEY=$SERVER_KEY . &> /dev/null

    rm -f $CONF_NAME
}


start

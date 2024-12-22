#! /bin/bash

CONN_STRING="vpn:9091" # CHANGE THIS
IMAGE_NAME="stunnel"
CONTAINER_NAME="st"
CONF_NAME="stunnel.conf"
CERT_DIR="certs"
CA_CERT="$CERT_DIR/ca-cert.pem"
CLIENT_CERT="$CERT_DIR/client-cert.pem"
CLIENT_KEY="$CERT_DIR/client-key.pem"
SERVER_CERT="$CERT_DIR/server-cert.pem"
SERVER_KEY="$CERT_DIR/server-key.pem"


generate_certs() {
    mkdir -p $CERT_DIR

    if [ -z "$(which openssl)" ] ; then
        echo "Please install openssl"
        exit 1
    fi

    dd if=/dev/urandom of=$CERT_DIR/rnd bs=256 count=1 2> /dev/null
    
    echo "Create CA cert"
    openssl req -new -x509 -days 10000 -batch -rand $CERT_DIR/rnd -config openssl.cnf -out $CA_CERT -keyout $CA_CERT 2> /dev/null

    echo "Generate server key"
    openssl genrsa -out $SERVER_KEY 2048 2> /dev/null

    echo "Create server CSR"
    openssl req -new -key $SERVER_KEY -out $CERT_DIR/server.csr -batch -config openssl.cnf 2> /dev/null

    echo "Sign server cert"
    openssl x509 -req -in $CERT_DIR/server.csr -CA $CA_CERT -CAkey $CA_CERT -CAcreateserial -out $SERVER_CERT -days 10000 2> /dev/null

    echo "Generate client key"
    openssl genrsa -out $CLIENT_KEY 2048 2> /dev/null

    echo "Create client CSR"
    openssl req -new -key $CLIENT_KEY -out $CERT_DIR/client.csr -batch -config openssl.cnf 2> /dev/null

    echo "Sign client cert"
    openssl x509 -req -in $CERT_DIR/client.csr -CA $CA_CERT -CAkey $CA_CERT -CAcreateserial -out $CLIENT_CERT -days 10000 2> /dev/null
    
    rm -f $CERT_DIR/rnd $CERT_DIR/*.csr $CERT_DIR/*.srl
}


example_conf() {
    cat << EOF > /dev/stdout
;#------CLIENT-------
[vpn]
client = yes
accept = 127.0.0.1:65000
connect = ur_ip:ur_port
cert = $CLIENT_CERT
key = $CLIENT_KEY
CAfile = $CA_CERT
verify = 3
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
verify = 3
EOF
}


stop() {
    docker stop $CONTAINER_NAME &> /dev/null
    docker rm $CONTAINER_NAME &> /dev/null
    docker rmi $IMAGE_NAME &> /dev/null
}

start() {
    echo "Example configuration for client"
    example_conf

    if [[ ! -d $CERT_DIR || ! -f $SERVER_CERT || ! -f $SERVER_KEY || ! -f $CLIENT_CERT || ! -f $CLIENT_KEY ]] ; then
        generate_certs
    fi

    echo "Create server config"
    create_server_conf
    
    stop

    echo "Build docker image"
    docker build -t $IMAGE_NAME --build-arg $CONF_NAME --build-arg CA=$CA_CERT --build-arg CERT=$SERVER_CERT --build-arg KEY=$SERVER_KEY . 2> /dev/null

    echo "Start docker container"
    docker run -d -it -p 5050:5050 --name $CONTAINER_NAME $IMAGE_NAME > /dev/null

    rm -f $CONF_NAME
}


case "$1" in
    start) start ;;
    example) example_conf ;;
    regenerate) generate_certs ;;
    *) echo "Usage: $0 start|example|regenerate" ;;
esac

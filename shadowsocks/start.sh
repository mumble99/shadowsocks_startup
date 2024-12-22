#! /bin/bash

EXT_PORT=444
INT_PORT=8388
CONTAINER_NAME="shadowsocks"
CONF_PATH="/opt/shadowsocks/config.json"
COMMAND=$1

print_help() {
    printf 'start\t-\tstart shadowsocks docker container\nstop\t-\tstop and delete docker container\nandroid client url:\thttps://github.com/shadowsocks/shadowsocks-android/releases\nwindows client url:\thttps://github.com/shadowsocks/shadowsocks-windows/releases\n'
}


generate_password() {
     < /dev/urandom tr -dc A-Za-z0-9 | head -c 16; echo;
}

generate_config() {
    pass=$(generate_password)
    json='{\n\t"server": "0.0.0.0",\n\t"server_port": %d,\n\t"timeout": 300,\n\t"nameserver": "8.8.8.8",\n\t"password": "%s",\n\t"method": "aes-256-gcm",\n\t"mode": "tcp_and_udp"\n}'
    mkdir -p /opt/shadowsocks
    printf "$json" $INT_PORT $pass > $CONF_PATH
    printf "\nsave password!!!: $pass\n"
}

install_dependencies() {
    if [[ -z $(which docker) ]]; then
        apt update
        apt install ca-certificates curl -y
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo \
             "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
             $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
             tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
    fi
}


start() {
    stop
    generate_config
    docker run --name $CONTAINER_NAME --restart always -p $EXT_PORT:$INT_PORT/tcp -p $EXT_PORT:$INT_PORT/udp -d -it \
     -v $CONF_PATH:/etc/shadowsocks-rust/config.json ghcr.io/shadowsocks/ssserver-rust:latest
}

stop(){
    printf "\nstoping $CONTAINER_NAME\n"
    docker stop $CONTAINER_NAME 2> /dev/null
    docker rm $CONTAINER_NAME   2> /dev/null
}


install_dependencies

if [[ "$COMMAND" = "start" ]]; then
    start
elif [[ "$COMMAND" = "stop" ]]; then
    stop
else
    print_help; exit 1;
fi

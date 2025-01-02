#! /bin/bash


build() {
    echo "Start build image"
    docker build -t openvpn . &> /dev/null
}

build
FROM debian:bullseye-slim


RUN apt update && apt install -y openvpn easy-rsa iproute2 iptables && rm -rf /var/lib/apt/lists/*

COPY ./init-vpn.sh /usr/local/bin/init-vpn.sh

RUN chmod +x /usr/local/bin/init-vpn.sh && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/bin/easyrsa

WORKDIR /opt

CMD ["/usr/local/bin/init-vpn.sh"]
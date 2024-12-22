FROM debian:12.8-slim as builder

ENV VERSION="stunnel-5.74"
WORKDIR /opt

RUN apt update && apt install -y curl build-essential libssl-dev && rm -rf /var/lib/apt/lists/*  && \
    curl -L https://github.com/mtrojnar/stunnel/archive/refs/tags/$VERSION.tar.gz -o stunnel.tar.gz && \
    tar xf stunnel.tar.gz && rm -f stunnel.tar.gz && cd stunnel-$VERSION && \
    sed -i 's/^stunnel_LDFLAGS = /&-all-static /' src/Makefile.in && \
    CFLAGS='-Os -fomit-frame-pointer -pipe' ./configure \
    --enable-static --disable-fips --disable-shared --disable-silent-rules --sysconfdir=/etc/ && \
    make -j 2 && strip src/stunnel && mv src/stunnel /opt/stunnel



FROM scratch

ARG CONF=$CONF
ARG CA=$CA
ARG CERT=$CERT
ARG KEY=$KEY
WORKDIR /opt

COPY --from=builder /opt/stunnel /opt/stunnel
ADD $CONF /etc/stunnel/stunnel.conf
ADD $CA /etc/stunnel/ca.pem
ADD $CERT /etc/stunnel/server-cert.pem
ADD $KEY /etc/stunnel/server-key.pem

ENTRYPOINT ["/opt/stunnel"]
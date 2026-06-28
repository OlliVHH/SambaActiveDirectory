# Native Samba AD DC für Raspberry Pi 5 / aarch64 (Debian Bookworm, wie RPi OS).
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="samba-ad-orv" \
      org.opencontainers.image.description="Samba Active Directory DC for ad.orv.space (ARM64 Bookworm)"

ENV DEBIAN_FRONTEND=noninteractive \
    SAMBA_STATE=/var/lib/samba

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    samba \
    samba-ad-provision \
    samba-dsdb-modules \
    samba-vfs-modules \
    winbind \
    krb5-user \
    ldap-utils \
    attr \
    acl \
    iproute2 \
    procps \
    tini \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/samba/smb.conf \
 && mkdir -p /etc/samba \
 && samba -V

COPY sbin/ /usr/local/sbin/
RUN chmod +x /usr/local/sbin/*.sh

# AD DC Ports (Macvlan: direkt im LAN erreichbar)
EXPOSE 53/tcp 53/udp 88/tcp 88/udp 135/tcp 137/udp 138/udp 139/tcp 389/tcp 445/tcp \
       464/tcp 464/udp 636/tcp 3268/tcp 3269/tcp

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/sbin/entrypoint.sh"]

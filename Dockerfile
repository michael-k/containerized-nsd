FROM alpine:3.11

LABEL description "Simple DNS authoritative server with DNSSEC support" \
      maintainer="Hardware <contact@meshup.net>"

ARG NSD_VERSION=4.2.4

# https://nlnetlabs.nl/people/
# http://hkps.pool.sks-keyservers.net/pks/lookup?search=0x9F6F1C2D7E045F8D&fingerprint=on&op=index
# pub  4096R/7E045F8D 2011-04-21 W.C.A. Wijngaards <wouter@nlnetlabs.nl>
ARG GPG_SHORTID_PRIMARY="0x7E045F8D"
ARG GPG_FINGERPRINT_PRIMARY="EDFA A3F2 CA4E 6EB0 5681  AF8E 9F6F 1C2D 7E04 5F8D"
# http://hkps.pool.sks-keyservers.net/pks/lookup?search=0xBA811E62E7194568&fingerprint=on&op=index
# pub  4096R/E7194568 2019-12-10 Jeroen Koekkoek <jeroen@nlnetlabs.nl>
ARG GPG_SHORTID_SECONDARY="0xE7194568"
ARG GPG_FINGERPRINT_SECONDARY="C3E3 5678 8FAD 0179 D872  D092 BA81 1E62 E719 4568"
ARG SHA256_HASH="9ebd6d766765631a56c0eb332eac26b310fa39f662e5582c8210488cf91ef27c"

ENV UID=991 GID=991

RUN apk add --no-cache --virtual build-dependencies \
      gnupg \
      build-base \
      libevent-dev \
      openssl-dev \
      ca-certificates \
 && apk add --no-cache \
      ldns \
      ldns-tools \
      libevent \
      openssl \
      tini \
 && cd /tmp \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.asc \
 && echo "Verifying both integrity and authenticity of nsd-${NSD_VERSION}.tar.gz..." \
 && CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi \
 && ( \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "${GPG_SHORTID_PRIMARY}" "${GPG_SHORTID_SECONDARY}" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "${GPG_SHORTID_PRIMARY}" "${GPG_SHORTID_SECONDARY}" || \
    gpg --keyserver pgp.mit.edu --recv-keys "${GPG_SHORTID_PRIMARY}" "${GPG_SHORTID_SECONDARY}" \
    ) \
 && FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 \
  | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
 && if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi \
 && if [[ "${FINGERPRINT}" != "${GPG_FINGERPRINT_PRIMARY}" && "${FINGERPRINT}" != "${GPG_FINGERPRINT_SECONDARY}" ]]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi \
 && echo "All seems good, now unpacking nsd-${NSD_VERSION}.tar.gz..." \
 && tar xzf nsd-${NSD_VERSION}.tar.gz && cd nsd-${NSD_VERSION} \
 && ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" \
 && make && make install \
 && apk del build-dependencies \
 && rm -rf /var/cache/apk/* /tmp/* /root/.gnupg

COPY bin /usr/local/bin
VOLUME /zones /etc/nsd /var/db/nsd
EXPOSE 53 53/udp
CMD ["run.sh"]

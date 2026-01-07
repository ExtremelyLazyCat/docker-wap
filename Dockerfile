FROM ubuntu:noble

RUN apt-get update && \
apt-get install -y wget patch gcc libxml2-dev make bison git automake libtool \
	sox libmp3lame-dev mpg123 imagemagick curl dos2unix ffmpeg && \
mkdir /tmp/build

WORKDIR /tmp/build

RUN wget https://kannel.org/download/1.4.5/gateway-1.4.5.tar.gz --no-check-certificate && \
tar -xvf gateway-1.4.5.tar.gz && \
rm gateway-1.4.5.tar.gz && \
cd gateway-1.4.5 && \
wget https://github.com/cyrenity/kannel/raw/refs/heads/main/gateway-1.4.5.patch.gz && \
wget -O 10_fix_multiple_definitions.patch https://aur.archlinux.org/cgit/aur.git/plain/10_fix_multiple_definitions.patch?h=kannel && \
gunzip -c gateway-1.4.5.patch.gz | patch -p1 && \
patch -p1 < 10_fix_multiple_definitions.patch && \
rm gateway-1.4.5.patch.gz && \
rm 10_fix_multiple_definitions.patch && \
./configure && \
make && \
make install && \
ldconfig -i

RUN git clone https://github.com/ExtremelyLazyCat/mbuni.git --branch pdp-1.1 --depth 1 && \
cd mbuni && \
./bootstrap && \
./configure --enable-shared=no LDFLAGS="-no-pie" && \
make -j$(nproc) && \
make install && \
ldconfig -i

RUN wget https://obs.osmocom.org/projects/osmocom/public_key && \
mv public_key /etc/apt/trusted.gpg.d/osmocom.asc && \
export OSMOCOM_REPO="https://downloads.osmocom.org/packages/osmocom:/latest/xUbuntu_24.04" && \
echo "deb [signed-by=/etc/apt/trusted.gpg.d/osmocom.asc] $OSMOCOM_REPO/ ./" | tee /etc/apt/sources.list.d/osmocom-latest.list && \
apt-get update && \
apt-get install -y pkg-config libosmocore-dev iptables && \
git clone https://github.com/osmocom/osmo-ggsn --branch 1.14.0 --depth 1

COPY osmo-ggsn-patch-1.14.0 /tmp/build/osmo-ggsn

RUN cd osmo-ggsn && \
ls && \
patch -p1 < pdp.patch && \
autoreconf -i && \
./configure && \
make -j$(nproc) && \
make install && \
ldconfig -i && \
cd ..

RUN curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg | tee /etc/apt/keyrings/openvpn-repo-public.asc && \
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/openvpn-repo-public.asc] https://build.openvpn.net/debian/openvpn/stable noble main" > /etc/apt/sources.list.d/openvpn-aptrepo.list && \
apt-get update && \
apt-get install -y openvpn && \
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz && \
tar -xvf EasyRSA-3.2.4.tgz && \
rm EasyRSA-3.2.4.tgz && \
cd EasyRSA-3.2.4 && \
./easyrsa --batch init-pki && \
./easyrsa --batch gen-dh && \
./easyrsa --nopass --req-cn=docker --batch build-ca && \
./easyrsa --nopass --req-cn=docker --batch build-server-full server && \
./easyrsa --nopass --req-cn=mmsc --batch build-client-full mmsc && \
./easyrsa --nopass --req-cn=bearerbox --batch build-client-full bearerbox && \
./easyrsa --nopass --req-cn=wapbox --batch build-client-full wapbox && \
mkdir /keys && \ 
cp ./pki/dh.pem /keys && \ 
cp ./pki/ca.crt /keys && \ 
cp ./pki/issued/mmsc.crt /keys && \
cp ./pki/private/mmsc.key /keys && \
cp ./pki/issued/bearerbox.crt /keys && \
cp ./pki/private/bearerbox.key /keys && \
cp ./pki/issued/wapbox.crt /keys && \
cp ./pki/private/wapbox.key /keys && \
cp ./pki/issued/server.crt /keys && \
cp ./pki/private/server.key /keys

WORKDIR /var/

RUN wget https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/2.1.15/dnscrypt-proxy-linux_x86_64-2.1.15.tar.gz && \
tar -xvf dnscrypt-proxy-linux_x86_64-2.1.15.tar.gz && \
rm -R dnscrypt-proxy-linux_x86_64-2.1.15.tar.gz

RUN echo "dos2unix /etc/wap/osmocom/iptables_run.sh && /etc/wap/osmocom/iptables_run.sh && openvpn --dh /keys/dh.pem --config /etc/wap/openvpn/server.conf & sleep 5 && /usr/local/bin/osmo-ggsn -c /etc/wap/osmocom/osmo-ggsn.cfg & /var/linux-x86_64/dnscrypt-proxy -config /etc/wap/dnscrypt/dnscrypt-proxy.toml" > /usr/bin/ggsn.sh; chmod +x /usr/bin/ggsn.sh && \
echo "dos2unix /etc/wap/mbuni/routing.sh && openvpn --config /etc/wap/openvpn/mmsc.conf & sleep 5 && /usr/local/bin/mmsc -F /etc/wap/mbuni/mmsc.log -V 1 /etc/wap/mbuni/mbuni.conf" > /usr/bin/mmsc.sh; chmod +x /usr/bin/mmsc.sh && \
echo "openvpn --config /etc/wap/openvpn/bearerbox.conf & sleep 5 && /usr/local/sbin/bearerbox -F /etc/wap/kannel/bearerbox.log -V 1 /etc/wap/kannel/kannel.conf" > /usr/bin/bearerbox.sh; chmod +x /usr/bin/bearerbox.sh && \
echo "openvpn --config /etc/wap/openvpn/wapbox.conf & sleep 5 && /usr/local/sbin/wapbox -F /etc/wap/kannel/wapbox.log -V 1 /etc/wap/kannel/kannel.conf" > /usr/bin/wapbox.sh; chmod +x /usr/bin/wapbox.sh && \
rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

WORKDIR /tmp/

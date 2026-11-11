#!/bin/bash
# 在板卡上配置 WiFi 连接（RTL8822BS / wlan0）
# 用法: wifi_setup.sh <SSID> <PASSWORD> [static-ip/prefix] [gateway]
set -e
SSID="$1"; PASS="$2"; STATIC="$3"; GW="$4"
[ -n "$SSID" ] || { echo "usage: $0 <ssid> <password> [static-ip/prefix] [gateway]"; exit 1; }

mkdir -p /etc/wpa_supplicant
wpa_passphrase "$SSID" "$PASS" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf.new
# 同时保留明文 ssid 便于调试（密码仍为 psk）
mv /etc/wpa_supplicant/wpa_supplicant-wlan0.conf.new /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

mkdir -p /etc/systemd/network
if [ -n "$STATIC" ]; then
cat > /etc/systemd/network/25-wlan0.network <<NET
[Match]
Name=wlan0

[Network]
Address=$STATIC
Gateway=$GW
DNS=192.168.2.1 8.8.8.8
NET
else
cat > /etc/systemd/network/25-wlan0.network <<NET
[Match]
Name=wlan0

[Network]
DHCP=yes
NET
fi

systemctl enable wpa_supplicant@wlan0.service 2>/dev/null || true
systemctl restart wpa_supplicant@wlan0.service
systemctl restart systemd-networkd
sleep 6
ip -br addr show wlan0
iw dev wlan0 link

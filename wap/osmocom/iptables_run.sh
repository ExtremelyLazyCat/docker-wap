#!/bin/bash
iptables -t nat -A POSTROUTING -s 10.10.11.0/24 ! -d 10.10.10.0/24 -o eth0+ -j MASQUERADE
iptables -t nat -A PREROUTING -s 10.10.11.0/24 -d 8.8.8.8 -j DNAT --to-destination 172.20.0.14

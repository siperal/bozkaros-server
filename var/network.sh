#!/bin/sh

if [[ -z "${NETWORK:-}" && -z "${IP:-}" ]]; then
    read -p "Static IP [leave empty for dynamic]: " -e -i "192.168.1.200" IP
fi

if [[ -z $IP ]]; then
    NETWORK=dhcp
else
    NETWORK=static
fi

if [[ -z "${GATEWAY:-}" ]]; then
    read -p "Gateway IP: " -e -i "192.168.1.1" GATEWAY
fi

if [[ -z "${DEVICE:-}" ]]; then
    read -p "Device: " -e -i "link" DEVICE
fi

if [[ -z "${HOSTNAME:-}" ]]; then
    read -p "Hostname: " -e -i "siperal" HOSTNAME
fi

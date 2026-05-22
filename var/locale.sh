#!/bin/sh

if [[ -z "${LOCALE:-}" ]]; then
    read -p "Locale: " -e -i "tr_TR.UTF8" LOCALE
fi
if [[ -z "${KEYMAP:-}" ]]; then
    read -p "Keyboard Layout: " -e -i "tr" KEYMAP
fi
if [[ -z "${TIMEZONE:-}" ]]; then
    read -p "Timezone: " -e -i "Europe/Istanbul" TIMEZONE
fi


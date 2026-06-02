#!/bin/sh
set -euo pipefail

# GRUB
GRUB2_PASS=$(openssl rand -base64 32 | tr -d '\n')
sed -i -e "s|^GRUB2_PASS=.*|GRUB2_PASS='${GRUB2_PASS}'|" "${WORKDIR}/.env"
GRUB2_HASH=$(echo -e "${GRUB2_PASS}\n${GRUB2_PASS}" | grub2-mkpasswd-pbkdf2 | awk '/grub.pbkdf/{print $NF}')
if [[ -z GRUB2_HASH ]]; then
    echo "GRUB2 hash is empty"
    exit 1
fi
GRUB2_HASH=$(echo "$GRUB2_HASH" | grep -oP '(?<=sha512\.10000\.).*')
sed -i -e "s|^GRUB2_HASH=.*|GRUB2_HASH='${GRUB2_HASH}'|" "${WORKDIR}/.env"
echo "GRUB2 hash generated"

# Users
BOZKAROS_PASS="123qweASDyxc===qwe"
# TODO $(openssl rand -base64 32 | tr -d '\n')
sed -i -e "s|^BOZKAROS_PASS=.*|BOZKAROS_PASS='${BOZKAROS_PASS}'|" "${WORKDIR}/.env"
BOZKAROS_HASH=$(python3 -c "from passlib.hash import sha512_crypt; print(sha512_crypt.using(rounds=5000).hash('${BOZKAROS_PASS}'))")
if [[ -z BOZKAROS_HASH ]]; then
    echo "User hash is empty"
    exit 1
fi
sed -i -e "s|^BOZKAROS_HASH=.*|BOZKAROS_HASH='${BOZKAROS_HASH}'|" "${WORKDIR}/.env"
echo "User hash generated"

#!/bin/sh
set -euo pipefail

# GRUB
GRUB2_PASS=$(openssl rand -base64 32 | tr -d '\n')
read -p "Enter GRUB2 password (3 times): " -e -i "${GRUB2_PASS}" GRUP2_PASS
GRUB2_HASH=$(grub2-mkpasswd-pbkdf2)
echo "GRUB2 hash generated"

# Users
read -p "Admin user password (bozkaros): " BOZKAROS_PASS
BOZKAROS_HASH=$(python3 -c "import crypt; print(crypt.crypt('${BOZKAROS_PASS}', crypt.mksalt(crypt.METHOD_SHA512)))")
echo "User hash generated"

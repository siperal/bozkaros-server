#!/usr/bin/env bash
set -euo pipefail

echo "Siperal Bozkaros Imager"
echo "-----------------------"
echo

# -----------------------------------------------------------------------------
# CONFIGURABLE STATIC PARAMETERS
# -----------------------------------------------------------------------------

ORIGINAL_ISO="./iso/Rocky-10.1-x86_64-minimal.iso"
RBRANDED_ISO="_rocky-to-bozkaros.iso"
BOZKAROS_ISO="Siperal-Bozkaros-Server-1.0-x86_64.iso"
ORIGINAL_VOLID="Rocky-10-1-x86_64-dvd"
ORIGINAL_VOLID_MINI="Rocky-10-1-x86_64-minimal"
BOZKAROS_VOLID="BOZKAROS_SERVER_1_0_X86_64"
WORKDIR="$(pwd)/build"
WORKMNT="/mnt/bozkaros-iso"
WORKISO="$(pwd)/mnt"
WORKIMG="$(pwd)/img"
HOSTNAME="bozkaros"

if [[ -f "./.env" ]]; then
    . .env
fi

# -----------------------------------------------------------------------------
# PREREQUISITES
# -----------------------------------------------------------------------------

echo "Prerequisites..."

if ! command -v mkksiso >/dev/null 2>&1 || ! command -v xorriso >/dev/null 2>&1; then
    sudo dnf install -y \
        createrepo_c \
        lorax \
        openssl \
        podman \
        pykickstart \
        rpm-build \
        rpmdevtools \
        rsync \
        xorriso
fi

if [ ! -f "${ORIGINAL_ISO}" ]; then
    echo "Original ISO not found: ${ORIGINAL_ISO}" >&2
    exit 1
fi

if [[ ! -f ./cis/goss-linux-amd64 ]]; then
    echo "Downloading GOSS binary for linux amd64..."
    mkdir -p ./cis
    curl --output ./cis/goss-linux-amd64 "https://github.com/goss-org/goss/releases/download/v0.4.9/goss-linux-amd64"
fi

mkdir -p "${WORKDIR}" "${WORKISO}"
sudo mkdir -p "${WORKMNT}"

echo "Checked."

# -----------------------------------------------------------------------------
# ISO REBRANDING
# -----------------------------------------------------------------------------

echo "Rebranding ISO file..."

if [[ ! -f "${WORKISO}/images/eltorito.img" ]]; then
    # Copy ISO contents
    echo "Copying ISO contents..."
    sudo mount -o loop "${ORIGINAL_ISO}" "${WORKMNT}"
    sudo rsync -a "${WORKMNT}"/ "${WORKISO}"/
    sudo umount "${WORKMNT}"
    sudo rm -Rf "${WORKMNT}"
fi

# Rebrand boot menus
echo "Rebranding boot menu..."
for cfg in \
    "${WORKISO}/isolinux/isolinux.cfg" \
    "${WORKISO}/isolinux/grub.conf" \
    "${WORKISO}/boot/grub2/grub.cfg" \
    "${WORKISO}/EFI/BOOT/grub.cfg" \
  ; do
  if [[ -f "$cfg" ]]; then
    sudo sed -i \
        -e "s/$ORIGINAL_VOLID/$BOZKAROS_VOLID/g" \
        -e "s/$ORIGINAL_VOLID_MINI/$BOZKAROS_VOLID/g" \
        -e 's/Rocky Linux 10.1/Siperal Bozkaros Server/g' \
        -e 's/Rocky Linux/Siperal Bozkaros Server/g' \
        "$cfg"
  fi
done

# Tighten GRUB timeout for “no visible menu”
echo "Tightening GRUB timeout..."
if [[ -f "$WORKISO/EFI/BOOT/grub.cfg" ]]; then
    sudo sed -i \
        -e 's/^set default=.*/set default="0"/' \
        "$WORKISO/EFI/BOOT/grub.cfg"
    sudo sed -i \
        -e 's/^set timeout=.*/set timeout=0.1/' \
        "$WORKISO/EFI/BOOT/grub.cfg"
fi
if [[ -f "$WORKISO/boot/grub2/grub.cfg" ]]; then
    sudo sed -i \
        -e 's/^set default=.*/set default="0"/' \
        "$WORKISO/boot/grub2/grub.cfg"
    sudo sed -i \
        -e 's/^set timeout=.*/set timeout=0.1/' \
        "$WORKISO/boot/grub2/grub.cfg"
fi


# Remove images
echo "Removing images..."
# Common paths on Rocky/RHEL boot ISOs: isolinux/splash.png and any *rocky*.png/jpg
find "$WORKISO" -type f \
  \( -iname '*rocky*png' -o -iname '*rocky*jpg' -o -path '*/isolinux/splash.png' \) \
  -print -delete
# If you want to keep a neutral background instead of none, copy in your own:
# cp /path/to/bozkaros-splash.png "$WORKISO/isolinux/splash.png"
# TODO copy bozkaros logo
# Remove the Rocky Linux logo from the EFI partition, if present
rm -f "${WORKISO}/EFI/BOOT/Rocky-*.png"


# -----------------------------------------------------------------------------
# IMG
# -----------------------------------------------------------------------------
# This is just a one line apperance seen on the installation screen - so quick, may not be even visible
# Skip this for now - not worth the time

# if [[ ! -f "$WORKIMG/rootfs/.buildstamp" ]]; then
#     mkdir -p "$WORKIMG/rootfs" "$WORKIMG/squash"
#     unsquashfs -no-xattrs -d "$WORKIMG/rootfs/" "$WORKISO/images/install.img"
#     \cp ./branding/.buildstamp "$WORKIMG/rootfs/.buildstamp"
#     mksquashfs "$WORKIMG/rootfs" ./iso/install.img -comp xz -no-xattrs -noappend
#     mv ./iso/install.img "$WORKISO/images/install.img"
# fi


# -----------------------------------------------------------------------------
# REBUILD
# -----------------------------------------------------------------------------

if [[ ! -f $WORKDIR/$RBRANDED_ISO ]]; then
    echo "Rebuilding ISO..."

    # The layout (isolinux + EFI/BOOT + images/efiboot.img or grubx64.efi)
    # matches what RHEL/Rocky use for BIOS/UEFI hybrid media.
    sudo xorriso -as mkisofs \
    -b images/eltorito.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
    -eltorito-alt-boot \
    -e images/efiboot.img \
        -no-emul-boot \
    --protective-msdos-label \
    -V "$BOZKAROS_VOLID" \
    -o "$WORKDIR/$RBRANDED_ISO" \
    "$WORKISO"
fi


# -----------------------------------------------------------------------------
# REBRANDING
# -----------------------------------------------------------------------------

echo "Rebranding..."

# Preps
mkdir -p ./rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $PWD)/rpmbuild' > ~/.rpmmacros

# Copy release info
echo "Copying release info..."
\cp ./branding/os-release ./rpmbuild/SOURCES/os-release.bozkaros
\cp ./branding/release.txt ./rpmbuild/SOURCES/bozkaros-release.txt
\cp ./branding/release.spec ./rpmbuild/SPECS/bozkaros-release.spec
\cp ./branding/logos.spec ./rpmbuild/SPECS/bozkaros-logos.spec

# Build from the spec
echo "Building from the spec file..."
rpmbuild -bb ./rpmbuild/SPECS/bozkaros-release.spec
ls ./rpmbuild/RPMS/noarch

# Copy images
echo "Copying images..."
\cp ./branding/splash.png ./rpmbuild/SOURCES/bozkaros-splash.png
\cp ./branding/progress.png ./rpmbuild/SOURCES/bozkaros-progress.png
\cp ./branding/syslinux-splash.png ./rpmbuild/SOURCES/bozkaros-syslinux-splash.png
\cp ./branding/grub-splash.xpm.gz ./rpmbuild/SOURCES/bozkaros-grub-splash.xpm.gz

# Build logos
echo "Building logos..."
rpmbuild -bb ./rpmbuild/SPECS/bozkaros-logos.spec


# -----------------------------------------------------------------------------
# ACCESS
# -----------------------------------------------------------------------------

# Creating temporary environment
\cp .env "$WORKDIR/.env"

echo "Creating access keys..."

. ./var/auth.sh

if [[ -z $BOZKAROS_PASS ]]; then
    echo "error: empty security admin password"
    exit 1
fi

# Cleanup
rm -f "$WORKDIR/id_bozkaros" "$WORKDIR/id_bozkaros.pub"

# SSH keys
ssh-keygen -t ed25519 \
    -C "bozkaros@bozkaros" \
    -f "$WORKDIR/id_bozkaros" \
    -N "$BOZKAROS_PASS"

# Public keys
BOZKAROS_PUBLIC_KEY=$(tr -d '\n' < "$WORKDIR/id_bozkaros.pub" | sed 's/[\\&|]/\\&/g')
sudo sed -i -e "s|^BOZKAROS_PUBLIC_KEY=.*|BOZKAROS_PUBLIC_KEY='${BOZKAROS_PUBLIC_KEY}'|" "${WORKDIR}/.env"

echo "Access keys ready"


# -----------------------------------------------------------------------------
# ANSIBLE RULES
# -----------------------------------------------------------------------------

# Compress CIS repo
if [[ ! -f ./cis/bozkarcis.tar.gz ]]; then
    mkdir -p ./cis
    tar -czf "./cis/bozkarcis.tar.gz" bozkarcis
fi

# Collections
if [[ ! -f ./cis/collections/community-general-9.5.11.tar.gz ]]; then
    ansible-galaxy collection download community.general:9.5.11 community.crypto:2.26.1 ansible.posix:1.6.2
    mv ./collections/ ./cis/
fi


# -----------------------------------------------------------------------------
# RPMs & POOLING
# -----------------------------------------------------------------------------

echo "Transfer RPMs..."
cp ./rpmbuild/RPMS/noarch/bozkaros-release-*.rpm ./pkgs/
cp ./rpmbuild/RPMS/noarch/bozkaros-logos-*.rpm   ./pkgs/

# Pool RPMs
createrepo_c ./pkgs/
createrepo_c ./branding/
createrepo_c ./conf/
createrepo_c ./cis/

# -----------------------------------------------------------------------------
# KICKSTART
# -----------------------------------------------------------------------------

echo "Preparing Kickstart file..."

set -a
. ./var/locale.sh
. ./var/network.sh
echo "Exchange secret values..."
KS_FILE="$WORKDIR/bozkaros-server.ks"
. "${WORKDIR}/.env"
echo "Environment variables are loaded."
set +a

VARS='${LOCALE}${KEYMAP}${TIMEZONE}${NETWORK}${IP}${GATEWAY}${DEVICE}${HOSTNAME}${DISK}${GRUB2_PASS}${GRUB2_HASH}${BOZKAROS_PASS}${BOZKAROS_HASH}${BOZKAROS_PUBLIC_KEY}'
#export $(grep -v '^#' "$WORKDIR/.env" | xargs)
envsubst "$VARS" < "cis-level2.ks" > "$KS_FILE"

echo "Validating KS file..."
ksvalidator -v RHEL10 "$KS_FILE"

# Build with mkksiso
#   -V      : set new ISO volume ID (rebranding and used by inst.stage2=hd:LABEL=...)
#   -c      : append kernel cmdline options (non-interactive, no UI)
#   --ks    : embed kickstart into ISO and wire inst.ks automatically
echo "Building new ISO..."
rm -f "$WORKDIR/$BOZKAROS_ISO"
sudo mkksiso \
  --ks "$KS_FILE" \
  --add ./pkgs \
  --add ./branding \
  --add ./conf \
  --add ./cis \
  -V "$BOZKAROS_VOLID" \
  "$WORKDIR/$RBRANDED_ISO" \
  "$WORKDIR/$BOZKAROS_ISO"

echo "Bozkaros ISO created: ./build/$BOZKAROS_ISO"

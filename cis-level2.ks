#version=RHEL10
# =============================================================================
# Bozkaros Server unattended minimal install (Rocky 10 derivative)
# Bozkaros — CIS Server Level 2 Kickstart
# Based on: siperal/bozkarcis
# Target:   CIS Level 2 Server
# Author:   Murat AYDIN <a@siperal.com>
# Date:     2026-07-13
# =============================================================================

# -----------------------------------------------------------------------------
# INSTALLATION METHOD
# -----------------------------------------------------------------------------
cmdline
text
cdrom
reboot
firstboot --disable
skipx
eula --agreed

# -----------------------------------------------------------------------------
# REPOS
# -----------------------------------------------------------------------------
repo --name=baseos --baseurl=file:///run/install/repo/server --install
repo --name=rpms --baseurl=file:///run/install/repo/rpms/ --install
repo --name=branding --baseurl=file:///run/install/repo/branding/ --install
repo --name=conf --baseurl=file:///run/install/repo/conf/ --install
repo --name=cis --baseurl=file:///run/install/repo/cis/ --install
repo --name=collections --baseurl=file:///run/install/repo/collections/ --install
repo --name=bin --baseurl=file:///run/install/repo/bin/ --install

# -----------------------------------------------------------------------------
# LANGUAGE, KEYBOARD, TIMEZONE
# CIS: Use UTC to avoid log correlation issues
# -----------------------------------------------------------------------------
lang ${LOCALE}
keyboard --vckeymap=${KEYMAP} --xlayouts='${KEYMAP}'
timezone ${TIMEZONE} --utc

# -----------------------------------------------------------------------------
# NETWORK
# CIS 3.1: Disable IPv6 if not required (set via kernel args below)
# Adjust interface name and IP for your environment
# -----------------------------------------------------------------------------
network --bootproto=${NETWORK} --ip=${IP} --netmask=255.255.255.0 --gateway=${GATEWAY} --nameserver=${GATEWAY} --hostname=${HOSTNAME} --device=${DEVICE} --activate --noipv6

# -----------------------------------------------------------------------------
# OSCAP ANACONDA ADD-ON
# Runs the CIS Level 2 Server profile natively inside Anaconda during install.
# This is NOT a post-install step — it runs in the installer environment with
# full knowledge of the partition layout, before the first boot.
# Handles: kernel params, services, sysctl, PAM, SSH, audit rules, etc.
# -----------------------------------------------------------------------------
%addon com_redhat_oscap
    content-type = scap-security-guide
    profile      = xccdf_org.ssgproject.content_profile_cis_server_l2
%end

# -----------------------------------------------------------------------------
# BOOTLOADER
# CIS 1.4.1 / 1.4.2: GRUB2 password and restricted permissions
# Hash generated with: grub2-mkpasswd-pbkdf2
# -----------------------------------------------------------------------------
bootloader --location=mbr --boot-drive=${DISK} --iscrypted --password=grub.pbkdf2.sha512.10000.${GRUB2_HASH} --append="fips=1 audit=1 audit_backlog_limit=8192 ipv6.disable=1 page_alloc.shuffle=1 randomize_kstack_offset=on vsyscall=none"
# init=/usr/lib/systemd/systemd

# -----------------------------------------------------------------------------
# PARTITIONING
# CIS 1.1.x: Separate partitions with hardened mount options
#
# Disk assumptions: /dev/${DISK}, 60GB+ recommended for server
# Adjust sizes to your requirements.
#
# CIS Controls addressed here:
#  1.1.2.1 - /tmp separate partition, nodev/nosuid/noexec
#  1.1.3.1 - /var separate partition
#  1.1.4.1 - /var/tmp separate, nodev/nosuid/noexec
#  1.1.5.1 - /var/log separate partition
#  1.1.6.1 - /var/log/audit separate partition
#  1.1.7.1 - /home separate partition, nodev
#  1.1.8.1 - /dev/shm nodev/nosuid/noexec (tmpfs, handled post-install)
# -----------------------------------------------------------------------------
zerombr
clearpart --all --initlabel --drives=${DISK}

# ---------------------------------------------------------------
# Required for BIOS + GPT: 1 MiB biosboot partition (EF02 type)
# No file system, no formatting — only for GRUB2 kernel
# CIS: This partition is required for GRUB2 installation, no security risk
# ---------------------------------------------------------------
part biosboot --fstype=biosboot --size=1 --ondisk=${DISK}
# Bios boot replaces efi.
# /boot/efi  (UEFI)
# part /boot/efi --fstype=vfat --size=600 --ondisk=${DISK} --fsoptions="umask=0027,fmask=0077"

# /boot  (CIS: nodev, nosuid)
part /boot --fstype=xfs --size=1024 --ondisk=${DISK} --fsoptions="nodev,nosuid"

# LVM Physical Volume (remainder of disk)
part pv.01 --size=1024 --grow --asprimary --ondisk=${DISK}

# LVM Volume Group
volgroup rl_vg pv.01

# / root (16 GB)
logvol / --fstype=xfs --size=4096 --name=root --vgname=rl_vg

# swap (TODO match RAM or use formula; 4GB shown)
logvol swap --fstype=swap --size=4096 --name=swap --vgname=rl_vg

# /tmp (CIS 1.1.2.x: separate, nodev/nosuid/noexec)
logvol /tmp --fstype=xfs --size=2048 --name=tmp --vgname=rl_vg --fsoptions="nodev,nosuid,noexec"

# /var (CIS 1.1.3.x: separate partition)
logvol /var --fstype=xfs --size=16384 --name=var --vgname=rl_vg --fsoptions="nodev"

# /var/tmp (CIS 1.1.4.x: separate, nodev/nosuid/noexec)
logvol /var/tmp --fstype=xfs --size=2048 --name=var_tmp --vgname=rl_vg --fsoptions="nodev,nosuid,noexec"

# /var/log (CIS 1.1.5.x: separate partition)
logvol /var/log --fstype=xfs --size=4096 --name=var_log --vgname=rl_vg --fsoptions="nodev,nosuid,noexec"

# /var/log/audit (CIS 1.1.6.x: separate partition)
logvol /var/log/audit --fstype=xfs --size=2048 --name=var_log_audit --vgname=rl_vg --fsoptions="nodev,nosuid,noexec"

# /home (CIS 1.1.7.x: separate, nodev)
logvol /home --fstype=xfs --size=4096 --name=home --vgname=rl_vg --fsoptions="nodev,nosuid"

# -----------------------------------------------------------------------------
# SELINUX
# CIS 1.6.1: Enforcing mode mandatory for Level 2
# -----------------------------------------------------------------------------
selinux --enforcing

# -----------------------------------------------------------------------------
# FIREWALL
# CIS 3.4.x: Enable firewalld; allow SSH only
# -----------------------------------------------------------------------------
firewall --enabled --ssh

# -----------------------------------------------------------------------------
# AUTHENTICATION
# CIS 5.x: Lock root, configure shadow passwords
# -----------------------------------------------------------------------------
# Lock root account (access via sudo only)
rootpw --lock

# Create an admin user
# Generate hash: python3 -c "import crypt; print(crypt.crypt('YourPass', crypt.mksalt(crypt.METHOD_SHA512)))"
# Password hash is generated in ./auth.sh
user --name=bozkaros --groups=wheel --iscrypted --password=${BOZKAROS_HASH} --gecos="Security Admin"
sshkey --username=bozkaros  "${BOZKAROS_PUBLIC_KEY}"

# SSH group for CIS access control (CIS 5.2.2)
group --name=sshallowed --gid=1500


# -----------------------------------------------------------------------------
# SERVICES
# -----------------------------------------------------------------------------
services --enabled=sshd,chronyd


# =============================================================================
# =============================================================================


# -----------------------------------------------------------------------------
# PACKAGE SELECTION
# CIS 2.x: Minimal install, remove unnecessary packages
# Level 2 requires specific packages for auditing
# -----------------------------------------------------------------------------
%packages
@^minimal-environment

# Derivative
-rocky-release
-rocky-logos
-rocky-logos-httpd
bozkaros-release
bozkaros-logos

# Base packages
ansible-core
git
openssh
python3
python3-pip
tar

# Required by OSCAP Anaconda Add-on
openscap-scanner
scap-security-guide

# CIS 4.x: Auditing and logging
audit
audit-libs
rsyslog

# CIS 3.x: Networking tools
firewalld
nftables

# CIS 1.x: Crypto and integrity
aide
openssl
libselinux
libselinux-utils
policycoreutils
policycoreutils-python-utils

# PAM and authentication
pam
libpwquality
authselect
sssd-common

# Time synchronization (CIS 2.1.1)
chrony

# Process accounting (CIS 4.1.x)
psacct

# Required for crypto-policy enforcement (CIS 1.7.x)
crypto-policies
crypto-policies-scripts

# FIPS-related
dracut
dracut-config-generic

# Explicitly remove - CIS 2.2.x / 2.3.x
-avahi
-avahi-autoipd
-cups
-dhcp-server
-bind
-vsftpd
-httpd
-nginx
-dovecot
-samba
-squid
-net-snmp
-telnet
-telnet-server
-rsh
-rsh-server
-ypbind
-ypserv
-tftp
-tftp-server
-talk
-talk-server
-xinetd
-xorg-x11-server-common
-setroubleshoot
-mcstrans
%end


# =============================================================================
# =============================================================================


# -----------------------------------------------------------------------------
# PRE-INSTALL SCRIPT
# -----------------------------------------------------------------------------
%pre
#!/bin/bash
echo "Starting CIS Level 2 Pre-Install configuration..."
%end


# =============================================================================
# =============================================================================


# -----------------------------------------------------------------------------
# NOCHROOT
# -----------------------------------------------------------------------------
%post --nochroot --log=/root/ks-post-nochroot.log
#!/bin/bash
set -euo pipefail

SYSROOT=/mnt/sysimage
BRANDING=/run/install/repo/branding
CONF=/run/install/repo/conf
CIS=/run/install/repo/cis
COLLECTIONS=/run/install/repo/collections
BIN=/run/install/repo/bin

# -----------------------------------------------------------------------------
# 1. BANNER / MOTD (CIS 1.7.x: Warning banners)
# -----------------------------------------------------------------------------
echo "[CIS] Configuring login banners..."
\cp ${BRANDING}/motd ${SYSROOT}/etc/motd
\cp ${BRANDING}/issue ${SYSROOT}/etc/issue
\cp ${BRANDING}/issue ${SYSROOT}/etc/issue.net
\cp ${BRANDING}/lsb-release ${SYSROOT}/etc/lsb-release

# -----------------------------------------------------------------------------
# 2. CHRONY / NTP (CIS 2.1.1)
# -----------------------------------------------------------------------------
echo "[CIS] Configuring chrony NTP..."
\cp ${CONF}/chrony.conf ${SYSROOT}/etc/chrony.conf

# -----------------------------------------------------------------------------
# 3. ANSIBLE
# -----------------------------------------------------------------------------
echo "Copying Ansible rules..."
mkdir -p ${SYSROOT}/etc/ansible/roles/
tar -xzf ${CIS}/bozkarcis.tar.gz -C ${SYSROOT}/etc/ansible/roles/
mv ${SYSROOT}/etc/ansible/roles/audit ${SYSROOT}/opt
\cp ${CONF}/ansible.cfg ${SYSROOT}/etc/ansible/ansible.cfg
\cp ${CONF}/cis_inventory.ini ${SYSROOT}/etc/ansible/cis_inventory.ini
\cp ${CONF}/cis_vars_delta.yml ${SYSROOT}/etc/ansible/cis_vars_delta.yml
\cp ${CONF}/run_cis_delta.yml ${SYSROOT}/etc/ansible/run_cis_delta.yml
\cp -r ${COLLECTIONS}/. ${SYSROOT}/etc/ansible/collections

# -----------------------------------------------------------------------------
# 4. AIDE
# -----------------------------------------------------------------------------
echo "AIDE daily check..."
\cp ${CONF}/aide-check ${SYSROOT}/etc/cron.daily/aide-check

# -----------------------------------------------------------------------------
# 5. BINARIES
# -----------------------------------------------------------------------------
echo "Copying binaries..."
\cp ${BIN}/goss-linux-amd64 ${SYSROOT}/usr/local/bin/goss

%end

# =============================================================================
# =============================================================================


# =============================================================================
# POST-INSTALL SCRIPT (chroot=no for network access)
# Runs the siperal/bozkarcis role for Level 2 hardening
# The OSCAP addon already applied CIS Level 2 during install.
# This %post handles ONLY the controls that scap-security-guide does NOT cover:
#   - FIPS mode enablement (requires initramfs rebuild)
#   - /dev/shm fstab hardening
#   - Login banners
#   - Chrony config
#   - GRUB config file permissions
#   - Ansible delta run for siperal/bozkarcis controls beyond SSG
#   - AIDE database initialization
# =============================================================================
%post --log=/root/ks-post-cis.log
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "  Siperal Bozkaros - CIS Level 2 Post-Install Hardening"
echo "============================================================"

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# -----------------------------------------------------------------------------
# 0. INSTALL ANSIBLE
#python3 -m pip install --user pipx
#python3 -m pipx ensurepath
#pipx install ansible-core

# -----------------------------------------------------------------------------
# 1. FIPS MODE (CIS 1.3.x / Level 2 requirement)
# FIPS Step 1: Get UUID of /boot partition (required alongside fips=1)
# FIPS Step 2: Add fips=1 + boot=UUID to all installed kernels
# -----------------------------------------------------------------------------
echo "[CIS] Enabling FIPS mode (Rocky 10 method: fips=1 kernel parameter)..."

BOOT_UUID=$(findmnt /boot -no UUID)
if [ -z "${BOOT_UUID}" ]; then
    echo "WARN: Could not determine /boot UUID — FIPS kernel arg may be incomplete"
else
    echo "[CIS] /boot UUID: ${BOOT_UUID}"
fi

grubby --update-kernel=ALL --args="fips=1 boot=UUID=${BOOT_UUID}"

# -----------------------------------------------------------------------------
# 2. CRYPTO POLICY (CIS 1.7.x: FIPS or FUTURE policy for Level 2)
# FIPS Step 3: Set crypto policy to FIPS
# FIPS Step 4: Touch /etc/system-fips (signals userspace FIPS state)
# FIPS Step 5: Rebuild initramfs with FIPS support
# -----------------------------------------------------------------------------
echo "[CIS] Setting system-wide crypto policy to FIPS..."
update-crypto-policies --set FIPS

touch /etc/system-fips

# dracut in Rocky 10 has the FIPS module built-in — no extra package needed
dracut --force --kver "$(ls /lib/modules | tail -1)"

echo "[CIS] FIPS mode configured. Verify after reboot: cat /proc/sys/crypto/fips_enabled"

# -----------------------------------------------------------------------------
# 3. /dev/shm hardening (CIS 1.1.8.x)
# Ansible role handles /etc/fstab but this ensures it at install time
# -----------------------------------------------------------------------------
echo "[CIS] Hardening /dev/shm in /etc/fstab..."
grep -q "/dev/shm" /etc/fstab || echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" >> /etc/fstab

# -----------------------------------------------------------------------------
# 4. GRUB config permissions (CIS 1.4.1)
# -----------------------------------------------------------------------------
echo "[CIS] Setting GRUB config permissions..."
[ -f /boot/grub2/grub.cfg ]      && chmod og-rwx /boot/grub2/grub.cfg
[ -f /boot/grub2/grubenv ]       && chmod og-rwx /boot/grub2/grubenv
[ -f /boot/efi/EFI/bozkaros/grub.cfg ] && chmod og-rwx /boot/efi/EFI/bozkaros/grub.cfg

# -----------------------------------------------------------------------------
# 5. BANNER / MOTD (CIS 1.7.x: Warning banners)
# -----------------------------------------------------------------------------
# Already copied in nochroot
chown root:root /etc/issue /etc/issue.net /etc/motd
chmod 644 /etc/issue /etc/issue.net /etc/motd

# -----------------------------------------------------------------------------
# 6. CHRONY / NTP (CIS 2.1.1)
# -----------------------------------------------------------------------------
# Already copied in nochroot
# Use organization's NTP servers if possible
chown root:root /etc/chrony.conf
chmod 640 /etc/chrony.conf

# -----------------------------------------------------------------------------
# 7. CIS HARDENING
# ANSIBLE DELTA RUN — controls in RHEL10-CIS role beyond scap-security-guide
# Runs in the installed system chroot using the locally cloned role.
# Since OSCAP already applied the base profile, this targets only the delta:
#   - usb-storage disable (Level 2 specific)
#   - sudo timestamp_timeout=0
#   - SSH LogLevel VERBOSE, AllowTcpForwarding no
#   - auditd disk_full/error actions
#   - firewalld default-zone drop
# -----------------------------------------------------------------------------

ANSIBLE_ROLES="/etc/ansible/roles/bozkarcis"
if [ -d "${ANSIBLE_ROLES}/tasks" ]; then
    echo "[CIS] Running Bozkarcis Ansible delta for Level 2 controls..."

    ansible-playbook -i /etc/ansible/cis_inventory.ini /etc/ansible/run_cis_delta.yml --tags "level1_server,level2_server" --skip-tags "mount_option,tmp_mount,vartmp_mount,rule_1.1.2.1,rule_1.1.3.1,rule_1.1.4.1,rule_1.1.5.1,rule_1.1.6.1,rule_1.1.7.1" -v 2>&1 | tee /root/ansible-cis-delta.log

    echo "[CIS] Ansible delta run complete."
    rm -f /etc/ansible/cis_inventory.ini /etc/ansible/cis_vars_delta.yml /etc/ansible/run_cis_delta.yml
else
    echo "[CIS] bozkarcis role not found — OSCAP-only hardening applied."
fi

# -----------------------------------------------------------------------------
# 8. AIDE Initialization (CIS 6.3.x: File integrity baseline)
# Must be done AFTER all hardening is applied
# -----------------------------------------------------------------------------
echo "[CIS] Initializing AIDE database (file integrity baseline)..."
aide --init && mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
chmod 750 /etc/cron.daily/aide-check
echo "[CIS] AIDE database initialized."

# -----------------------------------------------------------------------------
# 9. CLEANUP
# -----------------------------------------------------------------------------
echo "[CIS] All post-install hardening complete. Review /root/ks-post-cis.log"
echo "[CIS] Cleaning up..."
echo "[CIS] Post-install hardening complete."
%end
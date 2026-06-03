#version=RHEL10
# =============================================================================
# Siperal Bozkaros Server unattended minimal install (Rocky 10 derivative)
# Bozkaros — CIS Server Level 2 Kickstart
# Based on: siperal/bozkarcis
# Target:   CIS Level 2 RHEL10 Server
# Author:   Siperal Limited - www.siperal.com, Murat AYDIN <a@siperal.com>
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
repo --name=pkgs --baseurl=file:///run/install/repo/pkgs/ --install
repo --name=branding --baseurl=file:///run/install/repo/branding/ --install
repo --name=conf --baseurl=file:///run/install/repo/conf/ --install
repo --name=cis --baseurl=file:///run/install/repo/cis/ --install

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

# CIS requires strong password policies; PAM/Authselect tuned in Ansible post
authselect --enableshadow --passalgo=sha512

# Lock root account (access via sudo only)
rootpw --lock

# Create an admin user
# Password hash is generated in ./auth.sh
user --name=bozkaros --groups=wheel --iscrypted --password=${BOZKAROS_HASH} --gecos="Security Admin"
sshkey --username=bozkaros  "${BOZKAROS_PUBLIC_KEY}"

# SSH group for CIS access control (CIS 5.2.2)
group --name=sshallowed --gid=1500


# -----------------------------------------------------------------------------
# SERVICES
# -----------------------------------------------------------------------------
services --enabled=sshd,auditd,chronyd,firewalld,rsyslog,fail2ban


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
openssh
openssl
python3
tar

# SCAP / Hardening
ansible-core
git
openscap-scanner
scap-security-guide

# Security & Audit
acl
aide
audit
audit-libs
audit-rules
authselect
chrony
cronie
crypto-policies
crypto-policies-scripts
fail2ban
firewalld
libpwquality
libselinux
libselinux-utils
nftables
pam
policycoreutils
policycoreutils-python-utils
psacct
rsyslog
sssd-common
sudo

# FIPS-related
dracut
dracut-fips
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
%pre --log=/tmp/ks-pre.log
#!/bin/bash
# Verify FIPS boot flag is present before proceeding
if ! cat /proc/cmdline | grep -q "fips=1"; then
    echo "WARNING: fips=1 not detected on kernel command line." >&2
    echo "For RHEL 10 / RL 10, FIPS mode MUST be enabled at install time." >&2
fi
%end


# =============================================================================
# =============================================================================


# -----------------------------------------------------------------------------
# NOCHROOT
# -----------------------------------------------------------------------------
%post --nochroot --log=/root/ks-post-nochroot.log
#!/bin/bash
SYSROOT=/mnt/sysimage
BRANDING=/run/install/repo/branding
CONF=/run/install/repo/conf
CIS=/run/install/repo/cis

# -----------------------------------------------------------------------------
# BANNER / MOTD (CIS 1.7.x: Warning banners)
# -----------------------------------------------------------------------------
echo "[BRANDING] Configuring login banners..."
cp ${BRANDING}/motd ${SYSROOT}/etc/motd
cp ${BRANDING}/issue ${SYSROOT}/etc/issue
cp ${BRANDING}/issue ${SYSROOT}/etc/issue.net
cp ${BRANDING}/lsb-release ${SYSROOT}/etc/lsb-release

# -----------------------------------------------------------------------------
# CHRONY / NTP (CIS 2.1.1)
# -----------------------------------------------------------------------------
echo "[CHRONY] Configuring chrony NTP..."
cp ${CONF}/chrony.conf ${SYSROOT}/etc/chrony.conf

# -----------------------------------------------------------------------------
# ANSIBLE
# -----------------------------------------------------------------------------
echo "[HARDEN] Copying Ansible rules..."
mkdir -p ${SYSROOT}/etc/ansible/roles/
cp -a ${CIS} ${SYSROOT}/etc/ansible/
tar -xzf ${SYSROOT}/etc/ansible/cis/bozkarcis.tar.gz -C ${SYSROOT}/etc/ansible/roles/ && rm ${SYSROOT}/etc/ansible/cis/bozkarcis.tar.gz
mv ${SYSROOT}/etc/ansible/cis/goss-linux-amd64 ${SYSROOT}/usr/local/bin/goss
mv ${SYSROOT}/etc/ansible/roles/bozkarcis/audit ${SYSROOT}/opt/bozkarcis-audit
cp ${CONF}/ansible.cfg ${SYSROOT}/etc/ansible/ansible.cfg
cp ${CONF}/cis_inventory.ini ${SYSROOT}/etc/ansible/cis_inventory.ini

# -----------------------------------------------------------------------------
# AIDE
# -----------------------------------------------------------------------------
echo "[HARDEN] AIDE daily check..."
cp ${CONF}/aide-check ${SYSROOT}/etc/cron.daily/aide-check

%end


# =============================================================================
# =============================================================================


# =============================================================================
# POST-INSTALL SCRIPT (chroot=no for network access)
# =============================================================================
%post --interpreter=/bin/bash
#!/bin/bash
#set -euo pipefail
exec < /dev/tty3 > /dev/tty3 2>&1
chvt 3
exec > >(tee -a /root/ks-post-chroot.log) 2>&1

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export ANSIBLE_STDOUT_CALLBACK=yaml
export ANSIBLE_FORCE_COLOR=0        # disable ANSI colors in installer TTY
export PYTHONUNBUFFERED=1           # prevent Python output buffering

# -----------------------------------------------------------------------------
# FIPS MODE (CIS 1.3.x / Level 2 requirement)
# -----------------------------------------------------------------------------

# Boot UUID
BOOT_UUID=$(findmnt /boot -no UUID)
if [ -z "${BOOT_UUID}" ]; then
    echo "WARN: Could not determine /boot UUID — FIPS kernel arg may be incomplete"
else
    echo "[HARDEN] /boot UUID: ${BOOT_UUID}"
fi
grubby --update-kernel=ALL --args="fips=1 boot=UUID=${BOOT_UUID}"
touch /etc/system-fips
dracut --force --kver "$(ls /lib/modules | tail -1)"

# Harden crypto policy
echo "[HARDEN] Updating crypto policies"
update-crypto-policies --set FUTURE

# -----------------------------------------------------------------------------
# BANNER / MOTD (CIS 1.7.x: Warning banners)
# -----------------------------------------------------------------------------
# Already copied in nochroot
echo "[HARDEN] Banner permissions"
chown root:root /etc/issue /etc/issue.net /etc/motd
chmod 644 /etc/issue /etc/issue.net /etc/motd

# -----------------------------------------------------------------------------
# CHRONY / NTP (CIS 2.1.1)
# -----------------------------------------------------------------------------
# Already copied in nochroot
# Use organization's NTP servers if possible
echo "[HARDEN] Chrony permissions"
chown root:root /etc/chrony.conf
chmod 640 /etc/chrony.conf

# -----------------------------------------------------------------------------
# SSH HOST KEYS
# -----------------------------------------------------------------------------
# Generate SSH host keys so sshd -t validation works during hardening
echo "[HARDEN] Generating SSH host keys..."
ssh-keygen -t rsa     -b 4096 -f /etc/ssh/ssh_host_rsa_key     -N "" -q
ssh-keygen -t ecdsa   -b 521  -f /etc/ssh/ssh_host_ecdsa_key   -N "" -q
ssh-keygen -t ed25519         -f /etc/ssh/ssh_host_ed25519_key  -N "" -q
# Set correct permissions (CIS 5.1.x also audits these)
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
chown root:root /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# -----------------------------------------------------------------------------
# AUDIT
# -----------------------------------------------------------------------------
echo "[HARDEN] Pre-creating audit log file for CIS 6.3.4.x compliance..."
AUDIT_LOG_DIR=$(awk -F= '/^\s*log_file\s*=/ {gsub(/ /,"",$2); print $2}' /etc/audit/auditd.conf | xargs dirname)
mkdir -p "${AUDIT_LOG_DIR}"
touch "${AUDIT_LOG_DIR}/audit.log"
# Pre-set correct ownership and permissions (CIS 6.3.4.2/3/4)
chmod 600 "${AUDIT_LOG_DIR}/audit.log"
chown root:root "${AUDIT_LOG_DIR}/audit.log"
chmod 700 "${AUDIT_LOG_DIR}"
chown root:root "${AUDIT_LOG_DIR}"

# -----------------------------------------------------------------------------
# ANSIBLE SETUP
# -----------------------------------------------------------------------------

# Collections
echo "[HARDEN] Installing ansible collections"
ansible-galaxy collection install -p /etc/ansible/collections --force /etc/ansible/cis/collections/community-general-9.5.11.tar.gz && rm /etc/ansible/cis/collections/community-general-9.5.11.tar.gz
ansible-galaxy collection install -p /etc/ansible/collections --force /etc/ansible/cis/collections/community-crypto-2.26.1.tar.gz && rm /etc/ansible/cis/collections/community-crypto-2.26.1.tar.gz
ansible-galaxy collection install -p /etc/ansible/collections --force /etc/ansible/cis/collections/ansible-posix-1.6.2.tar.gz && rm /etc/ansible/cis/collections/ansible-posix-1.6.2.tar.gz

# Goss permissions
echo "[HARDEN] Set Goss permission"
chmod +x /usr/local/bin/goss

# Playbook
echo "[HARDEN] Run ansible playbook"
ansible-playbook -i /etc/ansible/cis_inventory.ini -e "@/etc/ansible/roles/bozkarcis/vars/bozkaros.yml" /etc/ansible/roles/bozkarcis/site.yml -v 2>&1 | tee -a /root/ansible.log

# -----------------------------------------------------------------------------
# AIDE INIT
# CIS 6.3.x: File integrity baseline
# Must be done AFTER all hardening is applied
# -----------------------------------------------------------------------------
echo "[HARDEN] Initializing AIDE database (file integrity baseline)"
chmod 750 /etc/cron.daily/aide-check
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------
echo "[CLEANUP] Cleaning up..."
# TODO

touch /.autorelabel
%end
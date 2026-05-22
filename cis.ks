#version=RHEL10
# =============================================================================
# Bozkaros Server unattended minimal install (Rocky 10 derivative)
# Bozkaros — CIS Server Level 2 Kickstart
# Based on: siperal/CIS-RHEL10
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
repo --name=rpms --baseurl=file:///run/install/repo/rpms/ --install
repo --name=branding --baseurl=file:///run/install/repo/branding/ --install
repo --name=conf --baseurl=file:///run/install/repo/conf/ --install

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
network --bootproto=${NETWORK} --ip=${IP} --netmask=255.255.255.0 \
        --gateway=${GATEWAY} --nameserver=${GATEWAY} \
        --hostname=${HOSTNAME} --device=${DEVICE} --activate --noipv6

# -----------------------------------------------------------------------------
# SECURITY POLICY
# CIS Level 2 Server — apply OpenSCAP profile during install as supplementary
# -----------------------------------------------------------------------------
%addon org_fedora_oscap
    content-type = scap-security-guide
    profile = xccdf_org.ssgproject.content_profile_cis_server_l2
%end

# -----------------------------------------------------------------------------
# BOOTLOADER
# CIS 1.4.1 / 1.4.2: GRUB2 password and restricted permissions
# Hash generated with: grub2-mkpasswd-pbkdf2
# -----------------------------------------------------------------------------
bootloader --location=mbr \
           --boot-drive=sda \
           --iscrypted \
           --password=grub.pbkdf2.sha512.10000.${GRUB2_HASH} \
           --append="audit=1 audit_backlog_limit=8192 ipv6.disable=1 \
                     init=/usr/lib/systemd/systemd \
                     page_alloc.shuffle=1 randomize_kstack_offset=on \
                     vsyscall=none"

# -----------------------------------------------------------------------------
# PARTITIONING
# CIS 1.1.x: Separate partitions with hardened mount options
#
# Disk assumptions: /dev/sda, 60GB+ recommended for server
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
clearpart --all --initlabel --drives=sda

# /boot/efi  (UEFI)
part /boot/efi --fstype=vfat \
               --size=600 \
               --ondisk=sda \
               --fsoptions="umask=0027,fmask=0077"

# /boot  (CIS: nodev, nosuid)
part /boot --fstype=xfs \
           --size=1024 \
           --ondisk=sda \
           --fsoptions="nodev,nosuid"

# LVM Physical Volume (remainder of disk)
part pv.01 --size=1024 --grow --asprimary --ondisk=sda

# LVM Volume Group
volgroup rl_vg pv.01

# / root (16 GB)
logvol / \
    --fstype=xfs \
    --size=16384 \
    --name=root \
    --vgname=rl_vg

# swap (match RAM or use formula; 4GB shown)
logvol swap \
    --fstype=swap \
    --size=4096 \
    --name=swap \
    --vgname=rl_vg

# /tmp (CIS 1.1.2.x: separate, nodev/nosuid/noexec)
logvol /tmp \
    --fstype=xfs \
    --size=2048 \
    --name=tmp \
    --vgname=rl_vg \
    --fsoptions="nodev,nosuid,noexec"

# /var (CIS 1.1.3.x: separate partition)
logvol /var \
    --fstype=xfs \
    --size=10240 \
    --name=var \
    --vgname=rl_vg \
    --fsoptions="nodev"

# /var/tmp (CIS 1.1.4.x: separate, nodev/nosuid/noexec)
logvol /var/tmp \
    --fstype=xfs \
    --size=2048 \
    --name=var_tmp \
    --vgname=rl_vg \
    --fsoptions="nodev,nosuid,noexec"

# /var/log (CIS 1.1.5.x: separate partition)
logvol /var/log \
    --fstype=xfs \
    --size=4096 \
    --name=var_log \
    --vgname=rl_vg \
    --fsoptions="nodev,nosuid,noexec"

# /var/log/audit (CIS 1.1.6.x: separate partition)
logvol /var/log/audit \
    --fstype=xfs \
    --size=2048 \
    --name=var_log_audit \
    --vgname=rl_vg \
    --fsoptions="nodev,nosuid,noexec"

# /home (CIS 1.1.7.x: separate, nodev)
logvol /home \
    --fstype=xfs \
    --size=4096 \
    --name=home \
    --vgname=rl_vg \
    --fsoptions="nodev,nosuid"

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
user --name=bozkaros \
     --groups=wheel \
     --iscrypted \
     --password=${BOZKAROS_HASH} \
     --gecos="Security Admin"
sshkey --username=bozkaros  "${BOZKAROS_PUBLIC_KEY}"

# SSH group for CIS access control (CIS 5.2.2)
group --name=sshallowed --gid=1500


# =============================================================================
# =============================================================================


# -----------------------------------------------------------------------------
# PACKAGE SELECTION
# CIS 2.x: Minimal install, remove unnecessary packages
# Level 2 requires specific packages for auditing
# -----------------------------------------------------------------------------
%packages --ignoremissing
@^minimal-environment

# Derivative
-rocky-release
-rocky-logos
-rocky-logos-httpd
bozkaros-release
bozkaros-logos

# Required for Ansible post-install
ansible-core
python3
python3-pip
git

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
setools-console

# PAM and authentication
pam
pam_pwquality
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
dracut-fips
dracut-fips-aesni

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
SYSROOT=/mnt/sysimage
BRANDING=/run/install/repo/branding
CONF=/run/install/repo/conf

# -----------------------------------------------------------------------------
# 1. BANNER / MOTD (CIS 1.7.x: Warning banners)
# -----------------------------------------------------------------------------
echo "[CIS] Configuring login banners..."
\cp ${BRANDING}/motd ${SYSROOT}/etc/motd
\cp ${BRANDING}/issue ${SYSROOT}/etc/issue
\cp ${BRANDING}/issue ${SYSROOT}/etc/issue.net

# -----------------------------------------------------------------------------
# 2. CHRONY / NTP (CIS 2.1.1)
# -----------------------------------------------------------------------------
echo "[CIS] Configuring chrony NTP..."
\cp ${CONF}/chrony.conf /etc/chrony.conf

%end


# =============================================================================
# =============================================================================


# =============================================================================
# POST-INSTALL SCRIPT (chroot=no for network access)
# Runs the siperal/CIS-RHEL10 role for Level 2 hardening
# =============================================================================
%post --log=/root/ks-post-cis.log
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "  Siperal Bozkaros - CIS Level 2 Post-Install Hardening"
echo "============================================================"

# -----------------------------------------------------------------------------
# 1. FIPS MODE (CIS 1.3.x / Level 2 requirement)
# Must be enabled before first boot; fips-mode-setup handles initramfs rebuild
# -----------------------------------------------------------------------------
echo "[CIS] Enabling FIPS 140-3 mode..."
fips-mode-setup --enable || echo "WARN: fips-mode-setup failed, check dracut-fips"

# -----------------------------------------------------------------------------
# 2. CRYPTO POLICY (CIS 1.7.x: FIPS or FUTURE policy for Level 2)
# -----------------------------------------------------------------------------
echo "[CIS] Setting system-wide crypto policy to FIPS..."
update-crypto-policies --set FIPS

# -----------------------------------------------------------------------------
# 3. /dev/shm hardening (CIS 1.1.8.x)
# Ansible role handles /etc/fstab but this ensures it at install time
# -----------------------------------------------------------------------------
echo "[CIS] Hardening /dev/shm in /etc/fstab..."
echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0" >> /etc/fstab

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
# 7. INSTALL & RUN siperal/CIS-RHEL10 (Level 2)
# -----------------------------------------------------------------------------
echo "[CIS] Installing Ansible Galaxy role: siperal/CIS-RHEL10..."
pip3 install --quiet ansible-core

# Install role from Galaxy
ansible-galaxy role install siperal.cis_rhel10 \
    --roles-path /etc/ansible/roles/

# Create inventory
cat > /tmp/cis_inventory.ini << 'INV'
[local]
localhost ansible_connection=local
INV

# Create Level 2 variable overrides
mkdir -p /tmp/cis_vars
cat > /tmp/cis_vars/level2_overrides.yml << 'VARS'
# ===========================================================================
# siperal/CIS-RHEL10 — Level 2 Server Variable Overrides
# Reference: https://github.com/siperal/CIS-RHEL10 -> /defaults/main.yml
# ===========================================================================

rhel10cis_level: 2
rhel10cis_install_type: server

# Audit settings
run_audit: true

# --- Section 1: Initial Setup ---
rhel10cis_rule_1_1_1_1: true    # cramfs disabled
rhel10cis_rule_1_1_1_2: true    # freevxfs disabled
rhel10cis_rule_1_1_1_3: true    # hfs disabled
rhel10cis_rule_1_1_1_4: true    # hfsplus disabled
rhel10cis_rule_1_1_1_5: true    # jffs2 disabled
rhel10cis_rule_1_1_1_6: true    # squashfs disabled
rhel10cis_rule_1_1_1_7: true    # udf disabled
rhel10cis_rule_1_1_1_8: true    # usb-storage disabled (Level 2)

# Partition mount option enforcement (already set via Kickstart)
rhel10cis_rule_1_1_2_1: true    # /tmp separate
rhel10cis_rule_1_1_2_2: true    # /tmp nodev
rhel10cis_rule_1_1_2_3: true    # /tmp nosuid
rhel10cis_rule_1_1_2_4: true    # /tmp noexec
rhel10cis_rule_1_1_8_1: true    # /dev/shm nodev
rhel10cis_rule_1_1_8_2: true    # /dev/shm nosuid
rhel10cis_rule_1_1_8_3: true    # /dev/shm noexec

# Bootloader
rhel10cis_set_boot_pass: true
rhel10cis_bootloader_password_hash: "grub.pbkdf2.sha512.10000.${GRUB2_HASH}"

# FIPS (already enabled above, role will validate)
rhel10cis_fips_enabled: true

# Crypto policy
rhel10cis_crypto_policy: "FIPS"

# --- Section 2: Services ---
rhel10cis_avahi_server: false
rhel10cis_cups_server: false
rhel10cis_dhcp_server: false
rhel10cis_ldap_server: false
rhel10cis_nfs_server: false
rhel10cis_dns_server: false
rhel10cis_ftp_server: false
rhel10cis_http_server: false
rhel10cis_imap_pop3_server: false
rhel10cis_samba_server: false
rhel10cis_squid_proxy_server: false
rhel10cis_snmp_server: false
rhel10cis_rsync_server: false
rhel10cis_nis_server: false
rhel10cis_telnet_server: false
rhel10cis_tftp_server: false
rhel10cis_xinetd_server: false

# --- Section 3: Network ---
rhel10cis_ipv6_required: false    # Disable IPv6 (Level 2)
rhel10cis_firewall: firewalld
rhel10cis_firewall_default_zone: "drop"  # Level 2: default drop
rhel10cis_allow_manager_access: true
rhel10cis_sshd_limited_access_group: "sshallowed"

# Wireless disabled on servers (Level 2)
rhel10cis_wireless_disable: true

# --- Section 4: Auditing ---
rhel10cis_auditd_max_log_file: 32
rhel10cis_auditd_max_log_file_action: keep_logs
rhel10cis_auditd_space_left_action: email
rhel10cis_auditd_admin_space_left_action: halt
rhel10cis_auditd_action_mail_acct: root
rhel10cis_auditd_disk_full_action: halt
rhel10cis_auditd_disk_error_action: halt

# --- Section 5: Access, Auth, Privilege ---
rhel10cis_set_password_expiry: true
rhel10cis_pass_max_days: 365
rhel10cis_pass_min_days: 1
rhel10cis_pass_warn_age: 7
rhel10cis_pass_inactive_days: 30   # Level 2

rhel10cis_password_complexity:
  minlen: 14
  minclass: 4
  dcredit: -1
  ucredit: -1
  ocredit: -1
  lcredit: -1
  maxrepeat: 3
  maxsequence: 3    # Level 2
  dictcheck: 1

rhel10cis_lock_out_after_n_attempts: 5
rhel10cis_fail_lock_unlock_time: 900   # Level 2: 15 minutes

# sudo settings (Level 2)
rhel10cis_sudo_log: true
rhel10cis_sudo_logfile: "/var/log/sudo.log"
rhel10cis_sudo_reauthentication: true   # Level 2: timestamp_timeout
rhel10cis_sudo_timestamp_timeout: 0     # Level 2: re-auth every time

# SSH hardening
rhel10cis_sshd:
  ClientAliveInterval: 300
  ClientAliveCountMax: 3         # Level 2
  LoginGraceTime: 60
  MaxAuthTries: 4
  MaxSessions: 10
  PermitRootLogin: "no"
  PermitEmptyPasswords: "no"
  PermitUserEnvironment: "no"
  UsePAM: "yes"
  IgnoreRhosts: "yes"
  HostbasedAuthentication: "no"
  X11Forwarding: "no"            # Level 2
  AllowTcpForwarding: "no"       # Level 2
  Banner: "/etc/issue.net"
  Protocol: 2
  Ciphers: "aes256-ctr,aes192-ctr,aes128-ctr"
  MACs: "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com"
  KexAlgorithms: "ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256"
  LogLevel: VERBOSE              # Level 2

# --- Section 6: System Maintenance ---
rhel10cis_passwd_perms: true
rhel10cis_shadow_perms: true
rhel10cis_group_perms: true
VARS

# Create the Ansible playbook
cat > /tmp/run_cis_level2.yml << 'PLAY'
---
- name: "Bozkaros Linux 1 - CIS Level 2 Server Hardening"
  hosts: local
  become: true
  gather_facts: true
  vars_files:
    - /tmp/cis_vars/level2_overrides.yml
  roles:
    - role: siperal.cis_rhel10
  tags:
    - level1_server
    - level2_server
PLAY

echo "[CIS] Running siperal/CIS-RHEL10 with Level 2 tags..."
ansible-playbook \
    -i /tmp/cis_inventory.ini \
    /tmp/run_cis_level2.yml \
    --tags "level1_server,level2_server" \
    --skip-tags "mount_option" \
    -v \
    2>&1 | tee /root/ansible-cis-level2.log

echo "[CIS] Ansible hardening run complete. Check /root/ansible-cis-level2.log"

# -----------------------------------------------------------------------------
# 8. AIDE Initialization (CIS 6.3.x: File integrity baseline)
# Must be done AFTER all hardening is applied
# -----------------------------------------------------------------------------
echo "[CIS] Initializing AIDE database (file integrity baseline)..."
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
echo "[CIS] AIDE database initialized."

# -----------------------------------------------------------------------------
# 9. CLEANUP
# -----------------------------------------------------------------------------
echo "[CIS] Cleaning up temporary files..."
rm -f /tmp/cis_inventory.ini
rm -rf /tmp/cis_vars
rm -f /tmp/run_cis_level2.yml
# Retain logs for audit trail
echo "[CIS] Post-install hardening complete."
echo "[CIS] Review /root/ks-post-cis.log and /root/ansible-cis-level2.log"

# Schedule first-boot AIDE check
cat > /etc/cron.daily/aide-check << 'AIDE'
#!/bin/bash
/usr/sbin/aide --check 2>&1 | mail -s "AIDE Integrity Report - $(hostname)" root
AIDE
chmod 750 /etc/cron.daily/aide-check

%end
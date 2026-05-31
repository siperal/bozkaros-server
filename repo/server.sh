#!/bin/bash
set -euo pipefail

# Install podman on your Rocky build VM if not already present
sudo dnf install -y podman createrepo_c yum-utils

# Pull a minimal Rocky 10 image
podman pull rockylinux:10-minimal

# Run the download inside the clean container
# Nothing is pre-installed, so --resolve catches ALL real dependencies
podman run --rm \
  -v $(pwd)/server:/output:z \
  rockylinux:10-minimal \
  bash -c "
    set -euo pipefail

    # DNF and download plugin
    microdnf install -y dnf
    dnf makecache
    dnf install -y 'dnf-command(download)' yum-utils createrepo_c
    
    # Enable all standard repos explicitly
    #dnf config-manager --enable baseos appstream extras crb 2>/dev/null || true
    #dnf makecache --refresh
    # Install dnf-plugins-core for 'download' subcommand
    #dnf install -y dnf-plugins-core
    # dnf install -y epel-release
    # dnf reposync -p /output --download-metadata --repo=baseos --repo=appstream --repo=epel
    # --setopt=install_weak_deps=False

    dnf download --resolve --alldeps --destdir=/output \
        aide \
        ansible-core \
        audit \
        audit-libs \
        authselect \
        chrony \
        crypto-policies \
        crypto-policies-scripts \
        dracut \
        dracut-config-generic \
        firewalld \
        git \
        libpwquality \
        libselinux \
        libselinux-utils \
        nftables \
        openscap-scanner \
        openssl \
        pam \
        policycoreutils \
        policycoreutils-python-utils \
        psacct \
        python3 \
        python3-pip \
        rsyslog \
        scap-security-guide \
        sssd-common \
        sudo \
        tar \
        vim-minimal
  "
# rocky-repos

# Remove conflicting dependencies
rm -f ./server/openssh-clients-9.9p1-14.el10_1.rocky.0.1.x86_64.rpm
rm -f ./server/openssh-9.9p1-14.el10_1.rocky.0.1.x86_64.rpm

# Regenerate repo metadata after clean download
createrepo_c ./server

echo "Total packages: $(ls ./server/*.rpm | wc -l)"
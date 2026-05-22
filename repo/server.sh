#!/bin/bash

# Install podman on your Rocky build VM if not already present
sudo dnf install -y podman

# Pull a minimal Rocky 10 image
podman pull rockylinux:10-minimal

# Run the download inside the clean container
# Nothing is pre-installed, so --resolve catches ALL real dependencies
podman run --rm \
  -v $(pwd)/server:/output:z \
  rockylinux:10-minimal \
  bash -c "
    microdnf install -y dnf
    dnf makecache
    dnf install -y 'dnf-command(download)'
    dnf download --resolve --alldeps --destdir=/output \
        aide \
        ansible-core \
        audit \
        audit-libs \
        authselect \
        chrony \
        crypto-policies \
        crypto-policies-scripts \
        dracut-fips \
        dracut-fips-aesni \
        firewalld \
        git \
        libpwquality \
        libselinux \
        libselinux-utils \
        nftables \
        openssl \
        pam \
        policycoreutils \
        policycoreutils-python-utils \
        psacct \
        python3 \
        python3-pip \
        rsyslog \
        setools-console \
        sssd-common
  "
# rocky-repos

# Regenerate repo metadata after clean download
createrepo_c ./server

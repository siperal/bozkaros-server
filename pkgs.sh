#!/bin/bash
set -euo pipefail

# Run the download inside the clean container
# Nothing is pre-installed, so --resolve catches ALL real dependencies
mkdir -p ./pkgs
podman run --rm \
  -v $(pwd)/pkgs:/output:z \
  rockylinux:10.1.20251123-ubi \
  bash -c "
    set -euo pipefail

    # DNF and download plugin
    dnf install -y 'dnf-command(download)' yum-utils createrepo_c
    dnf install -y epel-release
    dnf update -y

    dnf download --resolve --destdir=/output \
        ansible-core \
        audit \
        audit-libs \
        audit-rules \
        fail2ban \
        fail2ban-selinux \
        git \
        libselinux \
        libsemanage \
        libsepol \
        ncurses-base \
        ncurses-libs
  "

# Remove conflicting dependencies
rm -f ./pkgs/openssh*

# Regenerate repo metadata after clean download
createrepo_c ./pkgs

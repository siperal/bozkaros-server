#!/bin/bash
set -euo pipefail

# Run the download inside the clean container
# Nothing is pre-installed, so --resolve catches ALL real dependencies
podman run --rm \
  -v $(pwd)/server:/output:z \
  rockylinux:10.1.20251123-ubi \
  bash -c "
    set -euo pipefail

    # DNF and download plugin
    #dnf makecache
    dnf install -y 'dnf-command(download)' yum-utils createrepo_c

    dnf download --resolve --destdir=/output \
        ansible-core \
        git
  "

# Remove conflicting dependencies
rm -f ./server/openssh*

# Regenerate repo metadata after clean download
createrepo_c ./server

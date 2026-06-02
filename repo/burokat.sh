#!/bin/bash

# Install podman on your Rocky build VM if not already present
sudo dnf install -y podman

# Run the download inside the clean container
# Nothing is pre-installed, so --resolve catches ALL real dependencies
podman run --rm \
  -v $(pwd)/burokat:/output:z \
  rockylinux:10-minimal \
  bash -c "
    microdnf install -y dnf
    dnf install -y epel-release
    dnf config-manager --set-enabled crb
    dnf makecache
    dnf download --resolve --destdir=/output \
        aide \
        ansible-core \
        ant \
        argon2 \
        atk-devel \
        audit \
        audit-libs \
        authselect
        autoconf \
        automake \
        bison \
        cairo-devel \
        chrony \
        cmake \
        composer \
        cppunit \
        cppunit-devel \
        createrepo_c \
        crypto-policies \
        crypto-policies-scripts \
        cups-devel \
        dnf-utils \
        dracut-fips \
        dracut-fips-aesni \
        fontconfig-devel \
        firewalld \
        flex \
        gcc \
        gcc-c++ \
        gdb \
        gdk-pixbuf2-devel \
        git \
        glib2-devel \
        gperf \
        gstreamer1-devel \
        gstreamer1-plugins-bad-free \
        gstreamer1-plugins-bad-free-devel \
        gstreamer1-plugins-base-devel \
        gtk3-devel \
        harfbuzz-devel \
        httpd \
        httpd-core \
        java-21-openjdk-devel \
        junit \
        libcap \
        libcap-ng-utils \
        libICE-devel \
        libpng \
        libpng-devel \
        libselinux \
        libselinux-utils \
        libSM-devel \
        libsodium \
        libtool \
        libX11-devel \
        libXcursor-devel \
        libXext-devel \
        libXi-devel \
        libXinerama-devel \
        libXrandr-devel \
        libXrender-devel \
        libXt-devel \
        libXtst-devel \
        libzstd-devel \
        make \
        meson \
        mod_ssl \
        nano \
        nasm \
        NetworkManager \
        NetworkManager-tui \
        nftables \
        ninja-build \
        nss-devel \
        openssl \
        openssl-devel \
        pam \
        pam-devel \
        pam_pwquality \
        pango-devel \
        patch \
        perl-FindBin \
        perl-Time-Piece \
        php \
        php-bcmath \
        php-common \
        php-ctype \
        php-curl \
        php-dom \
        php-fileinfo \
        php-intl \
        php-gd \
        php-gmp \
        php-json \
        php-mbstring \
        php-openssl \
        php-pdo \
        php-pecl-redis \
        php-pgsql \
        php-posix \
        php-session \
        php-sodium \
        php-xml \
        php-zip \
        php-zlib \
        pkg-config \
        policycoreutils \
        policycoreutils-python-utils \
        postgresql \
        postgresql-devel \
        postgresql-server \
        psacct \
        python3-devel \
        python3-pip \
        rng-tools\
        rsyslog \
        setools-console \
        sqlite-devel \
        sssd-common \
        valkey \
        vim
  "
# rocky-repos

# Regenerate repo metadata after clean download
createrepo_c ./burokat/

Name:           bozkaros-logos
Version:        1.0
Release:        1.0el1
Summary:        Bozkaros Linux artwork
License:        BSD-3-Clause
Group:          System Environment/Base
BuildArch:      noarch

Source0:        bozkaros-splash.png
Source1:        bozkaros-progress.png
Source2:        bozkaros-syslinux-splash.png
Source3:        bozkaros-grub-splash.xpm.gz

Provides:       system-logos
Obsoletes:      rocky-logos

%description
Bozkaros Linux artwork for the installer and bootloader.

%prep
# nothing

%build
# nothing

%install
rm -rf %{buildroot}

# Anaconda installer graphics
install -d %{buildroot}/usr/share/anaconda/pixmaps
install -m 0644 %{SOURCE0} %{buildroot}/usr/share/anaconda/pixmaps/splash.png
install -m 0644 %{SOURCE1} %{buildroot}/usr/share/anaconda/pixmaps/progress_first.png

# Syslinux splash images for text/BIOS boots
install -d %{buildroot}/usr/lib/anaconda-runtime
install -m 0644 %{SOURCE2} %{buildroot}/usr/lib/anaconda-runtime/syslinux-splash.png

# GRUB background (if you use graphical GRUB)
install -d %{buildroot}/boot/grub
install -m 0644 %{SOURCE3} %{buildroot}/boot/grub/splash.xpm.gz

%files
/usr/share/anaconda/pixmaps/splash.png
/usr/share/anaconda/pixmaps/progress_first.png
/usr/lib/anaconda-runtime/syslinux-splash.png
/boot/grub/splash.xpm.gz

%changelog
- Initial Bozkaros logos package
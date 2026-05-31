Name:           bozkaros-release
Version:        1.0
Release:        1.0el1
Summary:        Siperal Bozkaros release files
License:        BSD-3-Clause
Group:          System Environment/Base
BuildArch:      noarch

Source0:        os-release.bozkaros
Source1:        bozkaros-release.txt

# Generic system-release for compatibility
Provides:       system-release
Obsoletes:      rocky-release

%description
Siperal Bozkaros Linux Server release files and basic OS identification,
including /etc/os-release and /etc/bozkaros-release.

%prep
# nothing

%build
# nothing

%install
rm -rf %{buildroot}

# os-release: installed as /usr/lib/os-release (recommended)
install -d %{buildroot}/usr/lib
install -m 0644 %{SOURCE0} %{buildroot}/usr/lib/os-release

# traditional release file
install -d %{buildroot}/etc
install -m 0644 %{SOURCE1} %{buildroot}/etc/bozkaros-release

# compatibility symlinks
ln -s ../usr/lib/os-release %{buildroot}/etc/os-release
ln -s bozkaros-release %{buildroot}/etc/redhat-release
ln -s bozkaros-release %{buildroot}/etc/system-release

%files
%license
/usr/lib/os-release
/etc/os-release
/etc/bozkaros-release
/etc/redhat-release
/etc/system-release

%changelog
* Mon Jul 13 2026 CIS Server Level 2
- Tue May 05 2026 Bozkaros server builder
- Initial Siperal Bozkaros server release package
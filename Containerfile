# 44
FROM quay.io/fedora/fedora-silverblue@sha256:de8acd3770a3f342672abc72bf504ea04f5b0f443d5c02f1f0d8eb9df3780f48

COPY repos/*.repo /etc/yum.repos.d/
COPY packages/base.txt /tmp/packages/base.txt
COPY packages/remove.txt /tmp/packages/remove.txt

RUN set -euxo pipefail; \
    if [ -L /opt ]; then rm /opt; fi; \
    mkdir -p /opt; \
    dnf -y install \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm; \
    dnf -y group install multimedia \
        --setopt=install_weak_deps=False \
        --exclude=PackageKit-gstreamer-plugin \
        --allowerasing; \
    xargs -r dnf -y remove < /tmp/packages/remove.txt; \
    xargs -r dnf -y install --allowerasing < /tmp/packages/base.txt; \
    dnf clean all; \
    rm -rf \
        /run/dnf \
        /tmp/packages \
        /var/cache/dnf \
        /var/cache/ibus \
        /var/cache/ldconfig \
        /var/cache/libdnf5 \
        /var/lib/dnf \
        /var/log/dnf5.log*

COPY flatpaks/flathub.txt /tmp/flatpaks/flathub.txt
COPY systemd/*.service /usr/lib/systemd/system/

RUN set -euxo pipefail; \
    mkdir -p /usr/share/flatpak/remotes.d; \
    curl -fsSL https://flathub.org/repo/flathub.flatpakrepo \
        -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo; \
    flatpak_refs="$(awk 'NF && $1 !~ /^#/ { print $1 }' /tmp/flatpaks/flathub.txt | paste -sd ' ' -)"; \
    test -n "${flatpak_refs}"; \
    sed -i "s|@FLATPAK_REFS@|${flatpak_refs}|" /usr/lib/systemd/system/flatpak-preinstall.service; \
    rm -rf \
        /tmp/flatpaks

COPY sysusers/*.conf /usr/lib/sysusers.d/
COPY tmpfiles/*.conf /usr/lib/tmpfiles.d/
COPY systemd/*.mount /usr/lib/systemd/system/
COPY dconf/ /etc/dconf/

RUN set -euxo pipefail; \
    mkdir -p /nix /var/nix; \
    dconf update; \
    systemctl --root=/ enable flatpak-preinstall.service; \
    systemctl --root=/ enable nix.mount

COPY fish/vendor_functions.d/*.fish /usr/share/fish/vendor_functions.d/

RUN bootc container lint

# 44
FROM quay.io/fedora/fedora-silverblue@sha256:4e0eb2fbd03f1b592df4545a57ad49f1085f67418e082b015c6296fb55301d19

COPY repos/*.repo /etc/yum.repos.d/
COPY packages/base.txt /tmp/packages/base.txt
COPY flatpaks/flathub.txt /tmp/flatpaks/flathub.txt

COPY fish/vendor_functions.d/*.fish /usr/share/fish/vendor_functions.d/
COPY systemd/*.service /usr/lib/systemd/system/
COPY sysusers/*.conf /usr/lib/sysusers.d/

RUN set -eux; \
    if [ -L /opt ]; then rm /opt; fi; \
    mkdir -p /opt; \
    dnf -y install \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm; \
    dnf -y group install multimedia \
        --setopt=install_weak_deps=False \
        --exclude=PackageKit-gstreamer-plugin \
        --allowerasing; \
    xargs -r dnf -y install --allowerasing < /tmp/packages/base.txt; \
    mkdir -p /usr/share/flatpak/remotes.d /usr/share/flatpak/preinstall.d; \
    curl -fsSL https://flathub.org/repo/flathub.flatpakrepo \
        -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo; \
    awk 'NF && $1 !~ /^#/ { \
        print "[Flatpak Preinstall " $1 "]"; \
        print "Branch=stable"; \
        print "IsRuntime=false"; \
        print ""; \
    }' /tmp/flatpaks/flathub.txt > /usr/share/flatpak/preinstall.d/10-flathub.preinstall; \
    systemctl enable --root=/ flatpak-preinstall.service; \
    dnf clean all; \
    find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} +; \
    rm -rf \
        /run/dnf \
        /var/cache/dnf \
        /var/cache/ibus \
        /var/cache/ldconfig \
        /var/cache/libdnf5 \
        /var/lib/dnf \
        /var/log/dnf5.log

COPY tmpfiles/*.conf /usr/lib/tmpfiles.d/
COPY systemd/*.mount /usr/lib/systemd/system/

RUN set -eux; \
    mkdir -p /nix /var/nix; \
    systemctl --root=/ enable nix.mount

RUN bootc container lint

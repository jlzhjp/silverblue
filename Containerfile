# renovate: datasource=docker depName=quay.io/fedora/fedora-silverblue versioning=redhat
FROM quay.io/fedora/fedora-silverblue:44

COPY repos/*.repo /etc/yum.repos.d/
COPY packages/bootstrap.txt /tmp/packages/bootstrap.txt
COPY packages/base.txt /tmp/packages/base.txt
COPY flatpaks/flathub.txt /tmp/flatpaks/flathub.txt

RUN set -eux; \
    if [ -L /opt ]; then rm /opt; fi; \
    mkdir -p /opt; \
    xargs -r dnf -y install < /tmp/packages/bootstrap.txt

COPY fish/vendor_functions.d/*.fish /usr/share/fish/vendor_functions.d/

SHELL ["/usr/bin/env", "HOME=/tmp", "XDG_CONFIG_HOME=/tmp/fish-config", "XDG_DATA_HOME=/tmp/fish-data", "/usr/bin/fish", "--no-config", "-c"]

RUN dnf -y install \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm; \
    and dnf -y group install multimedia \
        --setopt=install_weak_deps=False \
        --exclude=PackageKit-gstreamer-plugin \
        --allowerasing; \
    and xargs -r dnf -y install --allowerasing < /tmp/packages/base.txt; \
    and mkdir -p /usr/share/flatpak/remotes.d /usr/share/flatpak/preinstall.d; \
    and curl -fsSL https://flathub.org/repo/flathub.flatpakrepo \
        -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo; \
    and awk 'NF && $1 !~ /^#/ { \
        print "[Flatpak Preinstall " $1 "]"; \
        print "Branch=stable"; \
        print "IsRuntime=false"; \
        print ""; \
    }' /tmp/flatpaks/flathub.txt > /usr/share/flatpak/preinstall.d/10-flathub.preinstall; \
    and dnf clean all; \
    and rm -rf \
        /tmp/fish-config \
        /tmp/fish-data \
        /tmp/packages \
        /tmp/flatpaks \
        /var/cache/dnf \
        /var/cache/ibus \
        /var/cache/ldconfig \
        /var/cache/libdnf5 \
        /var/lib/dnf \
        /var/log/dnf5.log

COPY systemd/flatpak-preinstall.service /usr/lib/systemd/system/flatpak-preinstall.service
COPY tmpfiles/*.conf /usr/lib/tmpfiles.d/

RUN mkdir -p /usr/lib/systemd/system/multi-user.target.wants; \
    and ln -s ../flatpak-preinstall.service /usr/lib/systemd/system/multi-user.target.wants/flatpak-preinstall.service; \
    and bootc container lint

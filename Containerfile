ARG CHUNKAH_CONFIG_STR

FROM quay.io/fedora/fedora-silverblue:44@sha256:732ec6145b041ff4bb7cc10ba08152b33072bdc3841bebe6a01dbd09adc1672f AS builder

COPY repos/*.repo /etc/yum.repos.d/
COPY coprs/enabled.txt /tmp/coprs/enabled.txt
COPY packages/base.txt /tmp/packages/base.txt
COPY packages/remove.txt /tmp/packages/remove.txt

RUN set -euxo pipefail; \
    if [ -L /opt ]; then rm /opt; fi; \
    mkdir -p /opt; \
    dnf -y install \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm; \
    awk 'NF && $1 !~ /^#/ { print $1 }' /tmp/coprs/enabled.txt | xargs -r -n1 dnf -y copr enable; \
    dnf -y group install multimedia \
        --setopt=install_weak_deps=False \
        --exclude=PackageKit-gstreamer-plugin \
        --allowerasing; \
    xargs -r dnf -y remove < /tmp/packages/remove.txt; \
    xargs -r dnf -y install \
        --setopt=install_weak_deps=False \
        --allowerasing < /tmp/packages/base.txt; \
    install -Dm0644 /usr/share/containers/storage.conf /etc/containers/storage.conf; \
    sed -i 's|^# enable_partial_images = "false"$|enable_partial_images = "true"|' /etc/containers/storage.conf; \
    grep -Fx 'enable_partial_images = "true"' /etc/containers/storage.conf; \
    dnf clean all; \
    rm -rf \
        /tmp/coprs \
        /run/dnf \
        /tmp/packages \
        /var/cache/dnf \
        /var/cache/ibus \
        /var/cache/ldconfig \
        /var/cache/libdnf5 \
        /var/lib/dnf \
        /var/log/dnf5.log*

COPY flatpaks/flathub.txt /tmp/flatpaks/flathub.txt
COPY systemd/system/*.service /usr/lib/systemd/system/
COPY systemd/system/*.timer /usr/lib/systemd/system/
COPY systemd/user/*.service /usr/lib/systemd/user/
COPY --chmod=0755 libexec/* /usr/libexec/

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
COPY systemd/system/*.mount /usr/lib/systemd/system/
COPY dconf/ /etc/dconf/

RUN set -euxo pipefail; \
    mkdir -p /nix /var/nix; \
    dconf update; \
    systemctl --root=/ enable bootc-upgrade.timer; \
    systemctl --root=/ enable flatpak-preinstall.service; \
    systemctl --root=/ enable nix.mount

COPY fish/vendor_functions.d/*.fish /usr/share/fish/vendor_functions.d/

RUN bootc container lint

FROM quay.io/coreos/chunkah@sha256:352097f3d32186ac11082f8b74cd544678b00388b50c96ba5c8e79503a454fe3 AS chunkah
ARG CHUNKAH_CONFIG_STR

RUN --mount=from=builder,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
    chunkah build \
        --prune /sysroot/ \
        --max-layers 128 \
        --label ostree.commit- \
        --label ostree.final-diffid- \
        > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

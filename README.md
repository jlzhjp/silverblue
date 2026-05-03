# Fedora Silverblue bootc image

This repository builds a Fedora Silverblue-derived bootc image and publishes it to GitHub Container Registry.

## Image

- Base: `quay.io/fedora/fedora-silverblue:<version>@sha256:...`
- Published image: `ghcr.io/${{ github.repository }}`
- Architecture: `amd64` / `x86_64`

The image adds Docker Engine, Distrobox, Wireshark, Google Chrome, Visual Studio Code, Ghostty, Fish, BusyBox, Racket, Tailscale, sing-box, clash-meta, Nix, Japanese input engines, adw-gtk3, RPM Fusion multimedia support, and VAAPI drivers. Google Chrome is x86_64-only, so CI publishes only `amd64`.

## Layout

- `Containerfile`: image build definition
- `packages/base.txt`: DNF packages to install
- `packages/remove.txt`: base-image packages to remove
- `coprs/enabled.txt`: Fedora Copr projects to enable
- `repos/*.repo`: non-Copr RPM repositories
- `flatpaks/flathub.txt`: Flathub application IDs
- `dconf/`: GNOME system defaults copied into `/etc/dconf/`
- `fish/vendor_functions.d/`: Fish helper functions
- `libexec/`: helper scripts installed into `/usr/libexec/`
- `systemd/system/`: system units, mounts, and timers
- `systemd/user/`: user units
- `sysusers/`, `tmpfiles/`: system users, groups, directories, and state paths
- `.github/workflows/build.yml`: CI build and publish workflow
- `.github/renovate.json`: Renovate update policy

Keep list files plain: one item per line.

## Included Services

- `nix.mount` bind-mounts `/var/nix` at `/nix`.
- `flatpak-preinstall.service` enables system Flathub and installs refs from `flatpaks/flathub.txt` on boot.
- `bootc-upgrade.timer` runs `bootc upgrade` 10 minutes after boot and then daily. Missed runs are triggered after the next boot.
- `setup-home-manager.service` is a user unit that clones and applies a flake-based Home Manager config.

Enable the Nix daemon and Home Manager setup after install:

```bash
sudo systemctl enable --now nix-daemon.service
systemctl --user enable --now setup-home-manager.service
```

Override the default Home Manager source with a user drop-in:

```bash
systemctl --user edit setup-home-manager.service
```

```ini
[Service]
Environment=HOME_MANAGER_CONFIG_URL=https://github.com/example/home-manager.git
Environment=HOME_MANAGER_CONFIG_REF=main
```

## User Helpers

Run `setup_fish_shell` as the target user to change that user's login shell to `/usr/bin/fish`.

Run `setup_package_groups` after install to add the current user to package-specific groups such as `docker` and `wireshark`. Pass a username explicitly if needed:

```bash
setup_package_groups akari
```

## Build And Validate

```bash
podman build --arch amd64 -t fedora-silverblue-bootc:test .
podman run --rm fedora-silverblue-bootc:test bootc container lint
just lint
```

Use `just format` to format JSON, YAML, Bash, and Fish files.

## CI And Updates

CI builds pull requests unless they are labeled `skip-ci`. Pushes to `main` and manual runs publish:

- the Fedora version from `Containerfile`
- `latest`
- `sha-<short-sha>`

CI runs inside `quay.io/fedora/fedora-bootc:latest`, rechunks the built image with `rpm-ostree compose build-chunked-oci --bootc --format-version=2`, pushes the rechunked SHA tag with `zstd:chunked` compression, retags that manifest for the version and `latest`, and keeps only the 5 most recent GHCR image versions.

Renovate tracks the Fedora Silverblue base tag and digest, plus GitHub Actions. Digest-only base updates may automerge after CI passes. Major Fedora updates open PRs with `skip-ci`.

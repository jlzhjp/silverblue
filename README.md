# Fedora Silverblue bootc image

This repository builds a Fedora 44 Silverblue-derived bootc image and publishes it to GitHub Container Registry.

## Image

- Base image: `quay.io/fedora/fedora-silverblue@sha256:...`, tracking tag `44`
- Published image: `ghcr.io/${{ github.repository }}`
- Architecture: `amd64` / `x86_64`
- Initial custom packages: Docker Engine, Distrobox, Wireshark, Google Chrome, Visual Studio Code, Ghostty, Fish, Tailscale, sing-box, clash-meta, Nix, ibus-mozc, ibus-rime, libgda with SQLite support, adw-gtk3, RPM Fusion multimedia codecs, and VAAPI userspace drivers for AMD/Intel hardware acceleration

Google Chrome is currently x86_64-only, so the build intentionally publishes only an `amd64` image.

## Repository layout

```text
.
├── Containerfile
├── packages/
│   ├── base.txt
│   └── remove.txt
├── flatpaks/
│   └── flathub.txt
├── dconf/
│   ├── db/
│   │   └── local.d/
│   │       └── 00-gtk3-theme
├── fish/
│   └── vendor_functions.d/
│       ├── setup_fish_shell.fish
│       ├── setup_home_manager.fish
│       └── setup_package_groups.fish
├── repos/
│   ├── docker-ce.repo
│   ├── ghostty-scottames.repo
│   ├── google-chrome.repo
│   ├── sing-box.repo
│   ├── tailscale.repo
│   └── vscode.repo
├── systemd/
│   └── flatpak-preinstall.service
├── sysusers/
│   └── docker.conf
├── tmpfiles/
│   ├── clash-meta.conf
│   ├── docker.conf
│   └── tailscale.conf
├── .github/
│   └── workflows/
│       └── build.yml
└── renovate.json
```

Add future DNF packages to `packages/base.txt`, one package per line. Add base-image packages to remove to `packages/remove.txt`, one package per line. Add third-party RPM repositories under `repos/`; `Containerfile` copies all `*.repo` files into `/etc/yum.repos.d/`.

Fish, Git, Racket, Distrobox, libgda with SQLite support, and adw-gtk3 are installed from Fedora's native repositories. Docker Engine is installed from Docker's official Fedora RPM repository using `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`. Wireshark is installed from Fedora's native repositories. Visual Studio Code is installed from Microsoft's official RPM repository using the `code` package. Ghostty is installed from the `scottames/ghostty` Fedora Copr. Nix uses Fedora's native `nix` and `nix-daemon` packages. Fedora Toolbox is removed from the base image through `packages/remove.txt`.

The image installs the adw-gtk3 GTK3 theme for system applications and the matching light and dark Flathub GTK3 theme extensions for Flatpak applications. System dconf defaults in the existing local database set `org.gnome.desktop.interface gtk-theme` to `adw-gtk3` for users who have not overridden the setting.

Run `setup_fish_shell` as the target user to set that user's login shell to `/usr/bin/fish`. The function uses `sudo chsh`, so it may prompt for authentication. The image does not change global `useradd` defaults because that can affect package-created service accounts.

Run `setup_package_groups` after installing the system to add the current user to package-specific groups. The function currently adds the target user to `docker` and `wireshark` when those groups exist. Pass a username explicitly if needed: `setup_package_groups akari`.

The image bind-mounts `/var/nix` at `/nix` with `nix.mount`, which is enabled during the image build.

Run `setup_home_manager <git-url>` as the target user to clone a flake-based Home Manager config into `~/.config/home-manager` and apply it with `nix run home-manager/master -- switch --flake ~/.config/home-manager`. Useful options include `--ref <branch>`, `--directory <path>`, and `--no-switch`.

```bash
sudo systemctl enable --now nix-daemon.service
setup_home_manager git@github.com:example/home-manager.git
setup_home_manager --ref main https://github.com/example/home-manager.git
```

Flatpak is provided by the Fedora Silverblue base image. Add Flatpak applications to `flatpaks/flathub.txt`, one Flathub application ID per line. The build installs the Flathub remote definition into `/usr/share/flatpak/remotes.d/` and generates the enabled `flatpak-preinstall.service` command from that list. On boot, the service enables the system Flathub remote, runs `flatpak install --system --noninteractive -y flathub ...`, and retries failed attempts with systemd restart limits.

RPM Fusion free and nonfree release packages are installed during the build before the package list is resolved. The package install uses `--allowerasing` so codec packages such as RPM Fusion `ffmpeg` can replace Fedora split/free variants when needed.

Multimedia support is installed with RPM Fusion's `multimedia` group using `install_weak_deps=False` and excluding `PackageKit-gstreamer-plugin`. The package list keeps only `ffmpeg` explicit so the image gets the full RPM Fusion FFmpeg build rather than relying only on Fedora's codec-limited FFmpeg libraries.

Hardware video acceleration support includes `mesa-va-drivers-freeworld` for AMD VAAPI codec support, `intel-media-driver` for modern Intel GPUs, and `libva-utils` for diagnostics such as `vainfo`.

## Local build

```bash
podman build --arch amd64 -t fedora-silverblue-bootc:test .
```

The build removes packages listed in `packages/remove.txt`, installs packages listed in `packages/base.txt` with DNF, cleans package caches, and runs `bootc container lint`.

## CI publishing

The GitHub Actions workflow builds on pull requests, pushes to `main`, and manual runs. Pull requests build only. Pushes and manual runs publish to GHCR with these tags:

- `44`
- `latest`
- `sha-<short-sha>`

The workflow uses `GITHUB_TOKEN` with `packages: write`, so no extra registry secret is required for GHCR in the same repository.
After each publish, the workflow deletes older GHCR container package versions and keeps only the 5 most recent images.

## Updates

Renovate is configured to track the Fedora Silverblue tag named in the `Containerfile` comment, keep its immutable digest pinned, and automerge digest-only updates after CI passes. GitHub Actions updates are grouped separately. DNF packages are intentionally unpinned for now; base image digest refreshes arrive through Renovate PRs, while push and manual rebuilds pick up package repository updates between digest changes. If strict package version tracking is needed later, pin package versions in `packages/base.txt` and add a Renovate RPM custom manager.

Packages are removed and installed from plain list files instead of one package per layer. That keeps dependency resolution consistent, reduces image metadata churn, and avoids repeating repository metadata downloads. Split package install layers only when there is a concrete cache boundary, such as a rarely changed large third-party application set versus frequently edited local content.

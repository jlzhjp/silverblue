# Fedora Silverblue bootc image

This repository builds a Fedora 44 Silverblue-derived bootc image and publishes it to GitHub Container Registry.

## Image

- Base image: `quay.io/fedora/fedora-silverblue:44`
- Published image: `ghcr.io/${{ github.repository }}`
- Architecture: `amd64` / `x86_64`
- Initial custom packages: Docker Engine, Wireshark, Google Chrome, Visual Studio Code, Ghostty, Fish, Tailscale, sing-box, clash-meta, Nix, ibus-mozc, ibus-rime, RPM Fusion multimedia codecs, and VAAPI userspace drivers for AMD/Intel hardware acceleration

Google Chrome is currently x86_64-only, so the build intentionally publishes only an `amd64` image.

## Repository layout

```text
.
├── Containerfile
├── packages/
│   ├── bootstrap.txt
│   └── base.txt
├── flatpaks/
│   └── flathub.txt
├── fish/
│   └── vendor_functions.d/
│       ├── setup_fish_shell.fish
│       ├── setup_home_manager.fish
│       ├── setup_nix.fish
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
├── tmpfiles/
│   ├── clash-meta.conf
│   ├── docker.conf
│   └── tailscale.conf
├── .github/
│   └── workflows/
│       └── build.yml
└── renovate.json
```

Add future DNF packages to `packages/base.txt`, one package per line. `packages/bootstrap.txt` is only for packages required before the main build shell is available; currently it installs Fish so later `RUN` steps can use `/usr/bin/fish`. Add third-party RPM repositories under `repos/`; `Containerfile` copies all `*.repo` files into `/etc/yum.repos.d/`.

Fish, Git, and `btrfs-progs` are installed from Fedora's native repositories. Docker Engine is installed from Docker's official Fedora RPM repository using `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, and `docker-compose-plugin`. Wireshark is installed from Fedora's native repositories. Visual Studio Code is installed from Microsoft's official RPM repository using the `code` package. Ghostty is installed from the `scottames/ghostty` Fedora Copr. Nix uses Fedora's native `nix` and `nix-daemon` packages.

Run `setup_fish_shell` as the target user to set that user's login shell to `/usr/bin/fish`. The function uses `chsh`, so it may prompt for the user's password. The image does not change global `useradd` defaults because that can affect package-created service accounts.

Run `sudo fish -c setup_package_groups` after installing the system to add the current sudo user to package-specific groups. The function currently adds the target user to `docker` and `wireshark` when those groups exist. Pass a username explicitly if needed: `sudo fish -c 'setup_package_groups akari'`.

Run `sudo fish -c setup_nix` once before using Nix. Fedora Silverblue's root is immutable, so the function creates a top-level Btrfs subvolume named `nix`, appends an idempotent `/etc/fstab` entry for `/nix`, and mounts it. It refuses to mount over a non-empty `/nix` directory.

Run `setup_home_manager <git-url>` as the target user to clone a flake-based Home Manager config into `~/.config/home-manager` and apply it with `nix run home-manager/master -- switch --flake ~/.config/home-manager`. Useful options include `--ref <branch>`, `--directory <path>`, and `--no-switch`.

```bash
sudo systemctl enable --now nix-daemon.service
setup_home_manager git@github.com:example/home-manager.git
setup_home_manager --ref main https://github.com/example/home-manager.git
```

Flatpak is provided by the Fedora Silverblue base image. Add Flatpak applications to `flatpaks/flathub.txt`, one Flathub application ID per line. The build installs the Flathub remote definition into `/usr/share/flatpak/remotes.d/` and generates `/usr/share/flatpak/preinstall.d/10-flathub.preinstall`. On boot, `flatpak-preinstall.service` runs `flatpak preinstall -y` after networking so configured Flatpak apps are installed system-wide into the host's Flatpak installation.

RPM Fusion free and nonfree release packages are installed during the build before the package list is resolved. The package install uses `--allowerasing` so codec packages such as RPM Fusion `ffmpeg` can replace Fedora split/free variants when needed.

Multimedia support is installed with RPM Fusion's `multimedia` group using `install_weak_deps=False` and excluding `PackageKit-gstreamer-plugin`. The package list keeps only `ffmpeg` explicit so the image gets the full RPM Fusion FFmpeg build rather than relying only on Fedora's codec-limited FFmpeg libraries.

Hardware video acceleration support includes `mesa-va-drivers-freeworld` for AMD VAAPI codec support, `intel-media-driver` for modern Intel GPUs, and `libva-utils` for diagnostics such as `vainfo`.

## Local build

```bash
podman build --arch amd64 -t fedora-silverblue-bootc:test .
```

The build installs packages with DNF, cleans package caches, and runs `bootc container lint`.

## CI publishing

The GitHub Actions workflow builds on pull requests, pushes to `main`, manual runs, and a weekly schedule. Pull requests build only. Pushes, scheduled runs, and manual runs publish to GHCR with these tags:

- `44`
- `latest`
- `sha-<short-sha>`

The workflow uses `GITHUB_TOKEN` with `packages: write`, so no extra registry secret is required for GHCR in the same repository.

Non-PR builds enable Buildah layer caching with `--cache-from` and `--cache-to` against `ghcr.io/${{ github.repository }}-build-cache`. This reuses cached build layers when the Fedora Silverblue base image digest and build instructions have not changed. Pull requests build without writing cache.

## Updates

Renovate is configured to pin and update the Fedora Silverblue base image digest in `Containerfile`, and to group GitHub Actions updates. DNF packages are intentionally unpinned for now; the scheduled weekly rebuild picks up package repository changes. If strict package version tracking is needed later, pin package versions in `packages/base.txt` and add a Renovate RPM custom manager.

Packages are installed in one DNF transaction instead of one package per layer. That keeps dependency resolution consistent, reduces image metadata churn, and avoids repeating repository metadata downloads. Split package install layers only when there is a concrete cache boundary, such as a rarely changed large third-party application set versus frequently edited local content.

# Fedora Silverblue bootc image

This repository builds a Fedora 44 Silverblue-derived bootc image and publishes it to GitHub Container Registry.

## Image

- Base image: `quay.io/fedora/fedora-silverblue:44`
- Published image: `ghcr.io/${{ github.repository }}`
- Architecture: `amd64` / `x86_64`
- Initial custom packages: Google Chrome, Visual Studio Code, Ghostty, Fish, Tailscale, sing-box, clash-meta, Nix, ibus-mozc, ibus-rime, RPM Fusion multimedia codecs, and VAAPI userspace drivers for AMD/Intel hardware acceleration

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
├── repos/
│   ├── ghostty-scottames.repo
│   ├── google-chrome.repo
│   ├── sing-box.repo
│   ├── tailscale.repo
│   └── vscode.repo
├── systemd/
│   └── flatpak-preinstall.service
├── .github/
│   └── workflows/
│       └── build.yml
└── renovate.json
```

Add future DNF packages to `packages/base.txt`, one package per line. `packages/bootstrap.txt` is only for packages required before the main build shell is available; currently it installs Fish so later `RUN` steps can use `/usr/bin/fish`. Add third-party RPM repositories under `repos/`; `Containerfile` copies all `*.repo` files into `/etc/yum.repos.d/`.

Fish is installed from Fedora's native repositories. Visual Studio Code is installed from Microsoft's official RPM repository using the `code` package. Ghostty is installed from the `scottames/ghostty` Fedora Copr. Nix uses Fedora's native `nix` and `nix-daemon` packages.

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

## Updates

Renovate is configured to pin and update the Fedora Silverblue base image digest in `Containerfile`, and to group GitHub Actions updates. DNF packages are intentionally unpinned for now; the scheduled weekly rebuild picks up package repository changes. If strict package version tracking is needed later, pin package versions in `packages/base.txt` and add a Renovate RPM custom manager.

Packages are installed in one DNF transaction instead of one package per layer. That keeps dependency resolution consistent, reduces image metadata churn, and avoids repeating repository metadata downloads. Split package install layers only when there is a concrete cache boundary, such as a rarely changed large third-party application set versus frequently edited local content.

# Repository Guidelines

## Project Structure & Module Organization

This repository builds a Fedora Silverblue-derived bootc image. The main build definition is `Containerfile`. Package install inputs live in `packages/base.txt`; base-image package removals live in `packages/remove.txt`. Fedora Copr projects live in `coprs/enabled.txt`, one `owner/project` per line. Flatpak IDs belong in `flatpaks/flathub.txt`, one per line. GNOME system defaults live under `dconf/` and are copied into `/etc/dconf/`. Non-Copr RPM repos live in `repos/*.repo`. Fish helpers are installed from `fish/vendor_functions.d/`. Systemd system units and mounts live under `systemd/system/`; systemd user units live under `systemd/user/`; sysusers rules live under `sysusers/`; tmpfiles rules live under `tmpfiles/`. CI is in `.github/workflows/build.yml`; Renovate config is in `.github/renovate.json`.

## Build, Test, and Development Commands

- `podman build --arch amd64 -t fedora-silverblue-bootc:test .`: builds locally for the supported architecture.
- `podman run --rm fedora-silverblue-bootc:test bootc container lint`: reruns bootc lint against a built image.
- `just format`: formats JSON and YAML files with Prettier, Bash helpers with `shfmt`, and Fish files with `fish_indent`.
- `just lint`: runs formatting checks, GitHub Actions validation, YAML parsing, ShellCheck, and Fish syntax checks.
- `fish --no-config -n fish/vendor_functions.d/*.fish`: syntax-checks Fish helper functions.

CI builds pull requests without publishing, except PRs labeled `skip-ci`. Pushes to `main` and manual runs publish the Fedora version tag from `Containerfile`, `latest`, and `sha-<short-sha>` tags. CI builds OCI image metadata, pushes only `sha-<short-sha>` with `zstd:chunked` compression, then retags that manifest as the Fedora version tag and `latest` with `skopeo copy` so layers are not recompressed per tag. After publishing, CI deletes older GHCR container package versions and keeps only the 5 most recent images.

## Coding Style & Naming Conventions

Keep package and Flatpak lists plain: one item per line, no inline comments unless supported. Name repository files after the upstream or product, for example `google-chrome.repo`. Fish functions should use snake_case names matching their file, such as `setup_fish_shell.fish`. Containerfile changes should preserve grouped DNF operations and cleanup, including rotated DNF logs such as `/var/log/dnf5.log.1`.

## Testing Guidelines

There is no separate unit test suite. Treat a successful local build plus `bootc container lint` as primary validation. For Fish helper changes, run the syntax check and, when practical, test in a disposable Silverblue or bootc environment. For package, repo, or Flatpak changes, verify dependency resolution with a build.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, for example `Add fish shell setup helper`. Follow that style: capitalize the first word, keep the subject concise, and describe the user-visible change. Pull requests should include purpose, package or repo changes, validation results, and operational impact such as new services.

## Security & Configuration Tips

Do not commit secrets, personal tokens, or machine-specific configuration. Prefer upstream RPM repository files in `repos/` and pinned GitHub Actions by full commit SHA. Helpers that alter host state must state privileges and refusal conditions.

## Agent Notes & Lessons Learned

Before changing this repository, inspect the tree, `README.md`, `Containerfile`, CI workflow, and recent commits. Keep generated docs within the requested length and verify with `wc -w`. After editing, check `git status --short` so only intended files changed. Prefer repo-specific commands and paths over boilerplate.

At the end of every change turn, update this file when project descriptions, workflows, validation expectations, or agent lessons have changed. Record mistakes and their fixes here so future agents avoid repeating them.

When editing GitHub Actions workflows, validate with `actionlint .github/workflows/build.yml`; it is available in this workspace. `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/build.yml"))'` is useful as a basic YAML parse check. For Bash helpers under `libexec/`, run `shellcheck` and keep `shfmt` wired into `just format` and `just lint`. For paginated GitHub API cleanup, use `gh api --paginate --slurp` before sorting so retention decisions see the full version list, not one page at a time. Do not combine `gh api --slurp` with `--jq` or `--template`; GitHub CLI rejects that combination, so pipe slurped output to `jq -r` instead.

When publishing compressed images, keep the expensive `zstd:chunked` upload to a single content tag and move additional tags by manifest copy. Do not pass a fully qualified `ghcr.io/...` image name together with `registry: ghcr.io` to `redhat-actions/push-to-registry`, because that produces duplicated destinations such as `ghcr.io/ghcr.io/...`.

Renovate config lives at `.github/renovate.json` and is intentionally limited to `dockerfile` and `github-actions` managers. The Fedora Silverblue `Containerfile` base image must stay in tagged digest form, such as `quay.io/fedora/fedora-silverblue:<version>@sha256:...`, so Renovate's Dockerfile manager can update Fedora major tags while `docker:pinDigests` keeps the reference immutable. Fedora Silverblue digest updates for the current major version may automerge, but major version updates must open PRs without automerge and with the `skip-ci` label. Keep package rules scoped with `matchManagers` plus `matchPackageNames`. Avoid unnecessary Renovate overrides such as `platformAutomerge` unless the repo needs non-default merge timing.

Flatpak boot installation intentionally enables the system Flathub remote before running `flatpak install --system --noninteractive -y flathub ...` generated from `flatpaks/flathub.txt`; do not reintroduce `flatpak preinstall` or `/usr/share/flatpak/preinstall.d/` generation, because the preinstall path can try to autolaunch a session D-Bus without `$DISPLAY` during the system service.

GNOME defaults are provided through keyfiles in `dconf/db/local.d/`; keep `dconf update` in the image build so `/etc/dconf/db/local` is compiled. Fedora already provides `/etc/dconf/profile/user` with `system-db:local`, so do not copy a replacement profile unless the base image stops providing one.

Home Manager setup is handled by the systemd user unit `systemd/user/home-manager-maintenance.service`, installed to `/usr/lib/systemd/user/`, and the noninteractive helper `libexec/apply-home-manager-configuration`, installed to `/usr/libexec/apply-home-manager-configuration`. Do not reintroduce the old `setup_home_manager` Fish function. Users should configure the default dotfiles URL, ref, or directory with `systemctl --user edit home-manager-maintenance.service`, which creates a user drop-in under `~/.config/systemd/user/`; keep configuration outside `~/.config/home-manager` so it does not block the first clone.

The main package install from `packages/base.txt` intentionally uses `--setopt=install_weak_deps=False`; preserve that unless explicitly changing image size/dependency policy.

RPM Fusion release RPM URLs in `Containerfile` intentionally use `$(rpm -E %fedora)` so they follow the Fedora version provided by the base image. Do not hard-code the Fedora major version in those URLs.

Ghostty is installed from a Fedora Copr listed in `coprs/enabled.txt`. Keep Copr projects in that list and enable them in `Containerfile` with `dnf copr enable` before resolving `packages/base.txt`; do not add checked-in generated Copr `.repo` files under `repos/`.

Automatic bootc updates are handled by `systemd/system/bootc-upgrade.timer`, which runs `systemd/system/bootc-upgrade.service` 10 minutes after boot and then daily. Keep the timer enabled in `Containerfile`; do not enable the service directly, because it is a oneshot unit intended to be timer-triggered.

The `nix-gpu-driver.service` unit is opt-in, requires and runs after `nix-daemon.service`, then runs `libexec/link-nix-gpu-driver`. Keep the `/nix/store/*-non-nixos-gpu/lib/*.so` discovery and `/run/opengl-driver` link update logic in that helper, keep it covered by `justfile` Bash formatting/linting, and do not enable the unit by default in `Containerfile`.

When shortening README package summaries, cross-check `packages/base.txt` so installed tools such as Racket are not accidentally omitted.

The Containerfile uses chunkah's Buildah/Podman-only `FROM oci-archive:` workflow to repack the completed bootc rootfs into content-based layers. Keep the main image edits in the `builder` stage, run `bootc container lint` before repacking, pass `CHUNKAH_CONFIG_STR` from `podman inspect` of the pinned Fedora Silverblue base image, and build with `--skip-unused-stages=false`, `--volume "$(pwd):/run/src"`, and `--security-opt=label=disable` so the final `FROM oci-archive:out.ociarchive` can read chunkah's output. For this OSTree-derived bootc base, keep `chunkah build --prune /sysroot/ --max-layers 128 --label ostree.commit- --label ostree.final-diffid-` so bootc metadata is preserved while stale ostree labels and `/sysroot` content are removed.

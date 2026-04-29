# Repository Guidelines

## Project Structure & Module Organization

This repository builds a Fedora 44 Silverblue-derived bootc image. The main build definition is `Containerfile`. Package install inputs live in `packages/base.txt`; base-image package removals live in `packages/remove.txt`. Flatpak IDs belong in `flatpaks/flathub.txt`, one per line. GNOME system defaults live under `dconf/` and are copied into `/etc/dconf/`. RPM repos live in `repos/*.repo`. Fish helpers are installed from `fish/vendor_functions.d/`. Systemd units and mounts live under `systemd/`; sysusers rules live under `sysusers/`; tmpfiles rules live under `tmpfiles/`. CI is in `.github/workflows/build.yml`.

## Build, Test, and Development Commands

- `podman build --arch amd64 -t fedora-silverblue-bootc:test .`: builds locally for the supported architecture.
- `podman run --rm fedora-silverblue-bootc:test bootc container lint`: reruns bootc lint against a built image.
- `fish --no-config -n fish/vendor_functions.d/*.fish`: syntax-checks Fish helper functions.

CI builds pull requests without publishing. Pushes to `main` and manual runs publish `44`, `latest`, and `sha-<short-sha>` tags. After publishing, CI deletes older GHCR container package versions and keeps only the 5 most recent images.

## Coding Style & Naming Conventions

Keep package and Flatpak lists plain: one item per line, no inline comments unless supported. Name repository files after the upstream or product, for example `google-chrome.repo`. Fish functions should use snake_case names matching their file, such as `setup_home_manager.fish`. Containerfile changes should preserve grouped DNF operations and cleanup, including rotated DNF logs such as `/var/log/dnf5.log.1`.

## Testing Guidelines

There is no separate unit test suite. Treat a successful local build plus `bootc container lint` as primary validation. For Fish helper changes, run the syntax check and, when practical, test in a disposable Silverblue or bootc environment. For package, repo, or Flatpak changes, verify dependency resolution with a build.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, for example `Add fish shell setup helper`. Follow that style: capitalize the first word, keep the subject concise, and describe the user-visible change. Pull requests should include purpose, package or repo changes, validation results, and operational impact such as new services.

## Security & Configuration Tips

Do not commit secrets, personal tokens, or machine-specific configuration. Prefer upstream RPM repository files in `repos/` and pinned GitHub Actions by full commit SHA. Helpers that alter host state must state privileges and refusal conditions.

## Agent Notes & Lessons Learned

Before changing this repository, inspect the tree, `README.md`, `Containerfile`, CI workflow, and recent commits. Keep generated docs within the requested length and verify with `wc -w`. After editing, check `git status --short` so only intended files changed. Prefer repo-specific commands and paths over boilerplate.

At the end of every change turn, update this file when project descriptions, workflows, validation expectations, or agent lessons have changed. Record mistakes and their fixes here so future agents avoid repeating them.

When editing GitHub Actions workflows, validate with `actionlint .github/workflows/build.yml`; it is available in this workspace. `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/build.yml"))'` is useful as a basic YAML parse check. For paginated GitHub API cleanup, use `gh api --paginate --slurp` before sorting so retention decisions see the full version list, not one page at a time. Do not combine `gh api --slurp` with `--jq` or `--template`; GitHub CLI rejects that combination, so pipe slurped output to `jq -r` instead.

Renovate is intentionally limited to `custom.regex` and `github-actions` managers. The custom regex manager owns the digest-pinned Fedora Silverblue `Containerfile` base image; leaving the built-in `dockerfile` manager enabled creates noisy duplicate detection with an undefined version for the digest-only `FROM`. Renovate does not currently support naming individual regex custom managers, so keep Fedora package rules straightforward with `matchManagers: ["custom.regex"]` plus `matchPackageNames`. Do not keep Dockerfile-specific package rules while `dockerfile` is absent from `enabledManagers`; they are dead config. Keep `dependencyDashboardApproval` explicitly `false` so inherited Renovate presets do not require manual approval before digest PRs are created. Avoid unnecessary Renovate overrides such as `platformAutomerge` unless the repo needs non-default merge timing.

Flatpak boot installation intentionally enables the system Flathub remote before running `flatpak install --system --noninteractive -y flathub ...` generated from `flatpaks/flathub.txt`; do not reintroduce `flatpak preinstall` or `/usr/share/flatpak/preinstall.d/` generation, because the preinstall path can try to autolaunch a session D-Bus without `$DISPLAY` during the system service.

GNOME defaults are provided through keyfiles in `dconf/db/local.d/`; keep `dconf update` in the image build so `/etc/dconf/db/local` is compiled. Fedora already provides `/etc/dconf/profile/user` with `system-db:local`, so do not copy a replacement profile unless the base image stops providing one.

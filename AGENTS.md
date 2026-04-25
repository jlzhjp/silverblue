# Repository Guidelines

## Project Structure & Module Organization

This repository builds a Fedora 44 Silverblue-derived bootc image. The main build definition is `Containerfile`. Package inputs live in `packages/`: use `base.txt` for normal packages and `bootstrap.txt` only for tools needed before Fish is available. Flatpak IDs belong in `flatpaks/flathub.txt`, one per line. RPM repos live in `repos/*.repo`. Fish helpers are installed from `fish/vendor_functions.d/`. Tmpfiles rules are under `tmpfiles/`; CI is in `.github/workflows/build.yml`.

## Build, Test, and Development Commands

- `podman build --arch amd64 -t fedora-silverblue-bootc:test .`: builds locally for the supported architecture.
- `podman run --rm fedora-silverblue-bootc:test bootc container lint`: reruns bootc lint against a built image.
- `fish --no-config -n fish/vendor_functions.d/*.fish`: syntax-checks Fish helper functions.

CI builds pull requests without publishing. Pushes to `main`, schedules, and manual runs publish `44`, `latest`, and `sha-<short-sha>` tags.

## Coding Style & Naming Conventions

Keep package and Flatpak lists plain: one item per line, no inline comments unless supported. Name repository files after the upstream or product, for example `google-chrome.repo`. Fish functions should use snake_case names matching their file, such as `setup_nix.fish`. Containerfile changes should preserve grouped DNF operations and cleanup.

## Testing Guidelines

There is no separate unit test suite. Treat a successful local build plus `bootc container lint` as primary validation. For Fish helper changes, run the syntax check and, when practical, test in a disposable Silverblue or bootc environment. For package, repo, or Flatpak changes, verify dependency resolution with a build.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, for example `Add fish shell setup helper`. Follow that style: capitalize the first word, keep the subject concise, and describe the user-visible change. Pull requests should include purpose, package or repo changes, validation results, and operational impact such as new services.

## Security & Configuration Tips

Do not commit secrets, personal tokens, or machine-specific configuration. Prefer upstream RPM repository files in `repos/` and pinned GitHub Actions by full commit SHA. Helpers that alter host state must state privileges and refusal conditions.

## Agent Notes & Lessons Learned

Before changing this repository, inspect the tree, `README.md`, `Containerfile`, CI workflow, and recent commits. Keep generated docs within the requested length and verify with `wc -w`. After editing, check `git status --short` so only intended files changed. Prefer repo-specific commands and paths over boilerplate.

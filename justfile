set shell := ["bash", "-cu"]

fish_files := "fish/vendor_functions.d/*.fish fish/vendor_conf.d/*.fish"
workflow := ".github/workflows/build.yml"

default:
    just --list

format:
    find .github -type f \( -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -0 prettier --write
    find bin profile.d -type f -print0 | xargs -0 shfmt -w
    fish_indent -w {{fish_files}}

format-check:
    find .github -type f \( -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -0 prettier --check
    find bin profile.d -type f -print0 | xargs -0 shfmt -d
    fish_indent --check {{fish_files}}

lint: format-check lint-workflow lint-bash lint-fish

lint-workflow:
    actionlint {{workflow}}
    python3 -c 'import yaml; yaml.safe_load(open("{{workflow}}"))'

lint-bash:
    find bin profile.d -type f -print0 | xargs -0 shellcheck

lint-fish:
    fish --no-config -n {{fish_files}}

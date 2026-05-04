set shell := ["bash", "-cu"]

bash_files := "libexec/*"
fish_files := "fish/vendor_functions.d/*.fish"
workflow := ".github/workflows/build.yml"

default:
    just --list

format:
    find .github -type f \( -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -0 prettier --write
    shfmt -w {{bash_files}}
    fish_indent -w {{fish_files}}

format-check:
    find .github -type f \( -name '*.json' -o -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -0 prettier --check
    shfmt -d {{bash_files}}
    fish_indent --check {{fish_files}}

lint: format-check lint-workflow lint-bash lint-fish

lint-workflow:
    actionlint {{workflow}}
    python3 -c 'import yaml; yaml.safe_load(open("{{workflow}}"))'

lint-bash:
    shellcheck {{bash_files}}

lint-fish:
    fish --no-config -n {{fish_files}}

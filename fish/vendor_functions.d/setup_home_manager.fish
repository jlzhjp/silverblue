function setup_home_manager --description "Install Home Manager and optionally clone a configuration repository"
    set -l config_url
    set -l config_dir "$HOME/.config/home-manager"
    set -l branch_or_ref
    set -l skip_switch 0

    argparse 'd/directory=' 'r/ref=' 'no-switch' 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: setup_home_manager [--directory PATH] [--ref BRANCH] [--no-switch] [CONFIG_GIT_URL]"
        return 0
    end

    if set -q _flag_directory
        set config_dir $_flag_directory
    end

    if set -q _flag_ref
        set branch_or_ref $_flag_ref
    end

    if set -q _flag_no_switch
        set skip_switch 1
    end

    if test (count $argv) -gt 0
        set config_url $argv[1]
    end

    if test (id -u) -eq 0
        echo "Run setup_home_manager as the target user, not root." >&2
        return 1
    end

    for command_name in git nix
        if not command -q $command_name
            echo "Missing required command: $command_name" >&2
            return 1
        end
    end

    if not test -d /nix
        echo "/nix is missing. Run 'sudo fish -c setup_nix' first." >&2
        return 1
    end

    if not findmnt /nix >/dev/null
        echo "/nix is not mounted. Run 'sudo fish -c setup_nix' first." >&2
        return 1
    end

    if not pgrep -x nix-daemon >/dev/null
        echo "nix-daemon does not appear to be running. Start it with: sudo systemctl enable --now nix-daemon.service" >&2
        return 1
    end

    mkdir -p (dirname $config_dir)

    if test -n "$config_url"
        if test -d "$config_dir/.git"
            git -C $config_dir fetch --all --prune
            or return 1

            if test -n "$branch_or_ref"
                git -C $config_dir checkout $branch_or_ref
                or return 1
                git -C $config_dir pull --ff-only
                or return 1
            else
                git -C $config_dir pull --ff-only
                or return 1
            end
        else if test -e "$config_dir"
            echo "$config_dir already exists and is not a Git repository." >&2
            return 1
        else
            if test -n "$branch_or_ref"
                git clone --branch $branch_or_ref $config_url $config_dir
            else
                git clone $config_url $config_dir
            end
            or return 1
        end
    else if not test -e "$config_dir"
        mkdir -p $config_dir
    end

    if test $skip_switch -eq 1
        echo "Home Manager config is ready at $config_dir. Skipping switch."
        return 0
    end

    if not test -e "$config_dir/flake.nix"
        echo "Missing flake config: $config_dir/flake.nix" >&2
        return 1
    end

    nix run home-manager/master -- switch --flake $config_dir
end

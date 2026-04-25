function setup_fish_shell --description "Set the current user's login shell to fish"
    if not command -q chsh
        echo "Missing required command: chsh" >&2
        return 1
    end

    if not command -q sudo
        echo "Missing required command: sudo" >&2
        return 1
    end

    if not test -x /usr/bin/fish
        echo "Fish is not installed at /usr/bin/fish" >&2
        return 1
    end

    if test (id -u) -eq 0
        echo "Run setup_fish_shell as the target user, not root." >&2
        return 1
    end

    set -l current_shell (getent passwd (id -un) | cut -d: -f7)
    if test "$current_shell" = /usr/bin/fish
        echo "Login shell is already /usr/bin/fish"
        return 0
    end

    sudo chsh -s /usr/bin/fish (id -un)
end

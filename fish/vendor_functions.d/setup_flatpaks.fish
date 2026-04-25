function setup_flatpaks --description "Install configured Flathub applications for the current user"
    set -l preinstall_config /usr/share/flatpak/preinstall.d/10-flathub.preinstall

    if test (id -u) -eq 0
        echo "Run setup_flatpaks as the target user, not root." >&2
        return 1
    end

    if not command -q flatpak
        echo "Missing required command: flatpak" >&2
        return 1
    end

    if not test -r $preinstall_config
        echo "Missing Flatpak preinstall configuration: $preinstall_config" >&2
        return 1
    end

    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    or return 1

    flatpak preinstall --user --noninteractive -y
end

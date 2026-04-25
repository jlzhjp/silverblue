function setup_package_groups --description "Add a user to groups needed by image-provided packages"
    set -l sudo
    if test (id -u) -ne 0
        if not command -q sudo
            echo "Missing required command: sudo" >&2
            return 1
        end
        set sudo sudo
    end

    set -l target_user

    if test (count $argv) -gt 0
        set target_user $argv[1]
    else if test -n "$SUDO_USER"; and test "$SUDO_USER" != root
        set target_user $SUDO_USER
    else
        set target_user $USER
    end

    if test -z "$target_user"
        echo "Unable to determine target user. Pass a username explicitly." >&2
        return 2
    end

    set -l groups docker wireshark
    for group_name in $groups
        if getent group $group_name >/dev/null
            $sudo usermod -aG $group_name $target_user
            or return 1
        else
            echo "Skipping missing group: $group_name" >&2
        end
    end

    echo "Updated groups for $target_user. Log out and back in for membership changes to apply."
end

function setup_nix --description "Create and mount a Btrfs /nix subvolume on immutable Fedora systems"
    set -l sudo
    if test (id -u) -ne 0
        if not command -q sudo
            echo "Missing required command: sudo" >&2
            return 1
        end
        set sudo sudo
    end

    for command_name in btrfs findmnt mount umount awk
        if not command -q $command_name
            echo "Missing required command: $command_name" >&2
            return 1
        end
    end

    set -l mount_probe /sysroot
    if not findmnt -T $mount_probe >/dev/null
        set mount_probe /
    end

    set -l fstype (findmnt -T $mount_probe -no FSTYPE)
    if test "$fstype" != btrfs
        echo "Expected $mount_probe to be on Btrfs, found: $fstype" >&2
        return 1
    end

    set -l uuid (findmnt -T $mount_probe -no UUID)
    if test -z "$uuid"
        echo "Unable to determine Btrfs UUID for $mount_probe" >&2
        return 1
    end

    if findmnt /nix >/dev/null
        echo "/nix is already mounted."
        return 0
    end

    if test -e /nix; and not test -d /nix
        echo "/nix exists and is not a directory." >&2
        return 1
    end

    if test -d /nix
        set -l nix_non_directory_contents ($sudo find /nix -mindepth 1 ! -type d -print -quit 2>/dev/null)
        if test -n "$nix_non_directory_contents"
            echo "/nix contains non-directory content. Refusing to mount over existing content." >&2
            return 1
        end
    end

    set -l tmp_mount (mktemp -d /tmp/setup-nix.XXXXXX)
    if test -z "$tmp_mount"
        echo "Unable to create temporary mount directory." >&2
        return 1
    end

    $sudo mount -t btrfs -o subvolid=5 UUID=$uuid $tmp_mount
    or begin
        rmdir $tmp_mount
        echo "Unable to mount Btrfs top-level subvolume." >&2
        return 1
    end

    if not test -e $tmp_mount/nix
        $sudo btrfs subvolume create $tmp_mount/nix
        or begin
            $sudo umount $tmp_mount
            rmdir $tmp_mount
            echo "Unable to create Btrfs subvolume: nix" >&2
            return 1
        end
    else if not $sudo btrfs subvolume show $tmp_mount/nix >/dev/null 2>&1
        $sudo umount $tmp_mount
        rmdir $tmp_mount
        echo "Top-level Btrfs path 'nix' exists but is not a subvolume." >&2
        return 1
    end

    $sudo umount $tmp_mount
    and rmdir $tmp_mount
    or begin
        echo "Warning: unable to clean temporary mount $tmp_mount" >&2
    end

    $sudo mkdir -p /nix

    set -l fstab_line "UUID=$uuid /nix btrfs subvol=nix,compress=zstd:1 0 0"
    if test -e /etc/fstab
        if not awk '$2 == "/nix" { found=1 } END { exit !found }' /etc/fstab
            printf "\n%s\n" $fstab_line | $sudo tee -a /etc/fstab >/dev/null
        end
    else
        printf "%s\n" $fstab_line | $sudo tee /etc/fstab >/dev/null
    end

    $sudo mount /nix
    or begin
        echo "Created nix subvolume and fstab entry, but mounting /nix failed." >&2
        return 1
    end

    echo "/nix is ready. Enable/start nix-daemon after this if needed."
end

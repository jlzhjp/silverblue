if test -d /var/nix-system/prefix/bin
    fish_add_path --global --prepend /var/nix-system/prefix/bin
end

if test -d /var/nix-system/prefix/share
    set --local xdg_data_dirs (string split : -- "$XDG_DATA_DIRS")

    if test (count $xdg_data_dirs) -eq 0
        set xdg_data_dirs /usr/local/share /usr/share
    end

    if not contains /var/nix-system/prefix/share $xdg_data_dirs
        set --global --export XDG_DATA_DIRS (string join : /var/nix-system/prefix/share $xdg_data_dirs)
    end
end

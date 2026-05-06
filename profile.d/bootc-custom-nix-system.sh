# shellcheck shell=sh

if [ -d /var/nix-system/prefix/bin ]; then
	case ":${PATH:-}:" in
	*:/var/nix-system/prefix/bin:*) ;;
	*) PATH="${PATH:+${PATH}:}/var/nix-system/prefix/bin" ;;
	esac
	export PATH
fi

if [ -d /var/nix-system/prefix/share ]; then
	if [ -z "${XDG_DATA_DIRS:-}" ]; then
		XDG_DATA_DIRS="/usr/local/share:/usr/share"
	fi

	case ":${XDG_DATA_DIRS}:" in
	*:/var/nix-system/prefix/share:*) ;;
	*) XDG_DATA_DIRS="${XDG_DATA_DIRS}:/var/nix-system/prefix/share" ;;
	esac
	export XDG_DATA_DIRS
fi

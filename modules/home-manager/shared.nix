# Shared shell configuration for both Fish and Zsh
# This module defines common aliases and PATH settings
{
  # Shared PATH directories
  sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
    "/opt/homebrew/share/google-cloud-sdk/bin"
  ];

  # Shared shell aliases (work in both Fish and Zsh)
  aliases = {
    grep = "rg";
    cat = "bat";
    awk = "gawk";
    cp = "cp --reflink=auto"; # Use copy-on-write (CoW) when possible
    ls = "ls --color=auto"; # Enable colors for GNU ls
    ll = "ls -lah --color=auto"; # Long listing with colors
    iftop = "bandwhich";
    ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
    whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
    k = "kubectl";
    rebuild = "sudo darwin-rebuild switch --flake ~/.nixpkgs";
    update-all = "nix flake update --flake ~/.nixpkgs && sudo darwin-rebuild switch --flake ~/.nixpkgs";
    check-updates = "nix flake update --flake ~/.nixpkgs && nix build --dry-run --no-link ~/.nixpkgs#darwinConfigurations.uber-mac.system 2>&1 | awk '/^these.*derivations will be built:/ { flag=\"build\"; next } /^these.*paths will be fetched:/ { flag=\"fetch\"; next } flag==\"build\" && /^  \\// { gsub(/.*\\//, \"\"); gsub(/\\.drv$/, \"\"); build[NR]=$0; build_count++; next } flag==\"fetch\" && /^  \\// { gsub(/.*\\//, \"\"); fetch[NR]=$0; fetch_count++; next } /MiB download.*MiB unpacked/ { match($0, /\\(([0-9.]+) MiB download, ([0-9.]+) MiB unpacked\\)/, sizes); download=sizes[1]; unpacked=sizes[2]; } END { if (build_count > 0) { print \"\\n=== Packages to Build (\" build_count \") ===\"; for (i in build) print build[i]; } if (fetch_count > 0) { print \"\\n=== Packages to Fetch (\" fetch_count \") ===\"; for (i in fetch) print fetch[i]; } print \"\\n=== Summary ===\"; print \"Total:\", build_count + fetch_count, \"packages (\" build_count, \"to build,\", fetch_count, \"to fetch)\"; if (download) print \"Download:\", download, \"MiB\"; if (unpacked) print \"Unpacked:\", unpacked, \"MiB\"; }'";
    nixgc = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2 && nix-env -p /nix/var/nix/profiles/per-user/$USER/home-manager --delete-generations +2 && nix-collect-garbage -d";
    python = "python-wrapper";
    python3 = "python3-wrapper";
    spotless = "./gradlew spotlessApply && git add . && git commit -m 'Apply spotless formatting'";
  };
}

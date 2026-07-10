{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./zsh
    ./git
    ./fish
    ./pre-commit.nix
  ];

  programs = {
    home-manager = {
      enable = true;
      path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
    };

    # CLI tools with declarative configuration
    ripgrep.enable = true;
    jq.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    tmux = {
      enable = true;
      clock24 = true;
      mouse = true;
      terminal = "screen-256color";
      baseIndex = 1;
      escapeTime = 0;
      historyLimit = 50000;

      plugins = with pkgs; [
        tmuxPlugins.cpu
        tmuxPlugins.resurrect
        tmuxPlugins.sensible
        tmuxPlugins.yank
      ];

      extraConfig = ''
        # Vim-like pane navigation
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Better splits
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # Reload config
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"
      '';
    };

    htop = {
      enable = true;
      settings = {
        tree_view = false;
        show_cpu_frequency = true;
      };
    };

    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        pager = "less -FR";
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          ControlMaster = "auto";
          ControlPersist = "10m";
          Compression = true;
        };
      };
    };

    # Command-not-found suggestions using nix-index
    # Uses pre-built database from nix-index-database flake (no manual nix-index needed)
    # The nix-index-database module is imported at the flake level
    nix-index = {
      enable = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };

  xdg.configFile = {
    # Add completion paths that home-manager doesn't include by default
    # Note: generateCompletions is disabled in fish/default.nix because generated
    # completions shadow real ones (which define helper functions like __fish_brew_args).
    # Do NOT run fish_update_completions - it regenerates the cache and breaks completions.
    "fish/conf.d/zzz_completion_paths.fish".text = ''
      # Add Fish's built-in completions directory (1000+ commands: git, npm, etc.)
      set -l builtin_completions $__fish_data_dir/completions
      if test -d $builtin_completions; and not contains $builtin_completions $fish_complete_path
        set -ga fish_complete_path $builtin_completions
      end

      # PREPEND Homebrew completions so they take priority over Fish's placeholder files
      # (Fish's built-in brew.fish is just a comment pointing to Homebrew's upstream)
      if test -d /opt/homebrew/share/fish/vendor_completions.d
        and not contains /opt/homebrew/share/fish/vendor_completions.d $fish_complete_path
        set -p fish_complete_path /opt/homebrew/share/fish/vendor_completions.d
      end

      # Eagerly load Gradle completions so they work for ./gradlew immediately
      # Fish's lazy loading only triggers for command names (gradlew), not paths (./gradlew)
      # After typing 'gradle' once, './gradlew' works because gradle.fish is already loaded
      # This ensures ./gradlew completions work from the first tab press in a fresh shell
      set -l gradle_completion $__fish_data_dir/completions/gradle.fish
      if test -f $gradle_completion
        source $gradle_completion
      end
    '';

    # gradlew.fish - Load gradle.fish which provides completions for both gradle and gradlew
    "fish/completions/gradlew.fish".text = ''
      # gradle.fish defines completions for both 'gradle' and 'gradlew' commands
      # But Fish's lazy loading doesn't know this - it only looks for gradlew.fish when you type gradlew
      # So we explicitly source gradle.fish to make both sets of completions available
      set -l gradle_completion $__fish_data_dir/completions/gradle.fish
      test -f $gradle_completion; and source $gradle_completion
    '';

    "k9s/config.yml".text = ''
      k9s:
        liveViewAutoRefresh: true
        refreshRate: 2
    '';

    "pgcli/config".text = ''
      [main]
      multi_line = True
      vi = True
      auto_expand = True
    '';
  };

  home = with pkgs; {
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    stateVersion = "25.11";

    sessionVariables = {
      EDITOR = "zed --wait";
      VISUAL = "zed --wait";
      # See launchd.user.envVariables.NPM_CONFIG_PREFIX in darwin/default.nix
      # for why this is needed. The directory is created by the
      # ensureNpmPrefix activation below.
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    };

    activation = {
      # Skip the app management permission check (known issue on macOS)
      checkAppManagementPermission = lib.mkForce "";

      aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/Applications/Home Manager Applications" ]; then
          ln -sfn $genProfilePath/home-path/Applications "$HOME/Applications/Home Manager Applications"
        fi
      '';

      # npm ENOENTs on $PREFIX/lib if it doesn't exist — create it.
      ensureNpmPrefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "$HOME/.npm-global/lib"
      '';

      # home-manager dereferences symlinks when copying .app bundles into
      # ~/Applications, which breaks Ghidra's launcher: the bundled
      # MacOS/Ghidra is a symlink to lib/ghidra/ghidraRun whose readlink-derived
      # SCRIPT_DIR is used to locate support/launch.sh. After copy, SCRIPT_DIR
      # points to ~/Applications/.../MacOS and support/ is nowhere near.
      # Overwrite the launcher with one that execs ghidraRun by absolute path
      # so readlink -f resolves it under the nix-store install.
      fixGhidraAppLauncher = lib.hm.dag.entryAfter [ "aliasApplications" ] ''
        ghidraApp="$HOME/Applications/Home Manager Apps/Ghidra.app/Contents/MacOS/Ghidra"
        ghidraDir="$(dirname "$ghidraApp")"
        if [ -e "$ghidraApp" ]; then
          run chmod +w "$ghidraDir" "$ghidraApp" 2>/dev/null || true
          run install -m 0755 ${pkgs.writeShellScript "Ghidra" ''exec ${pkgs.ghidra}/lib/ghidra/ghidraRun "$@"''} "$ghidraApp"
        fi
      '';
    };

    # Symlink claude to ~/.local/bin for native installation detection.
    # force = true overrides any stale symlink left by claude's self-updater
    # (the wrapper sets DISABLE_AUTOUPDATER=1, but pre-Nix installs may persist).
    file.".local/bin/claude" = {
      source = "${pkgs.callPackage ../../pkgs/claude-code-native/default.nix { }}/bin/claude";
      force = true;
    };

    packages = with pkgs; [
      # Languages/Runtimes
      (python314.withPackages (
        ps: with ps; [
          ipython
          asyncpg
          requests
        ]
      ))

      # Python3 wrapper to fix symlink issue
      (pkgs.writeShellScriptBin "python3-wrapper" ''
        exec ${
          pkgs.python314.withPackages (
            ps: with ps; [
              ipython
              asyncpg
              requests
            ]
          )
        }/bin/python3.14 "$@"
      '')
      (pkgs.writeShellScriptBin "python-wrapper" ''
        exec ${
          pkgs.python314.withPackages (
            ps: with ps; [
              ipython
              asyncpg
              requests
            ]
          )
        }/bin/python3.14 "$@"
      '')

      uv # Fast Python package installer and resolver
      poetry

      # Rust toolchain (managed via rustup)
      rustup

      # Terminal & CLI tools
      wget
      yadm
      bandwhich
      postgresql_14
      gawk
      rsync
      tree
      yq
      yamllint
      pgcli
      man-db
      jwt-cli
      openvpn
      nodejs
      yarn
      tig
      glab # GitLab CLI
      # Bridge GitLab Container Registry auth into Docker / crane via glab's built-in
      # `glab auth docker-helper`. `glab auth configure-docker` tries to install this
      # to /etc/profiles/per-user/<u>/bin (read-only Nix profile) and fails; declaring
      # the shim here puts it on PATH the proper way. Registered as the credHelper
      # for registry.gitlab.com in ~/.docker/config.json.
      (pkgs.writeShellScriptBin "docker-credential-glab" ''
        exec ${pkgs.glab}/bin/glab auth docker-helper "$@"
      '')
      ffmpeg
      cmake
      stripe-cli
      k9s
      kubectl
      kubernetes-helm
      argocd
      openssl
      jdk21_headless
      async-profiler
      gradle
      terraform
      (pkgs.callPackage ../../pkgs/claude-code-native/default.nix { })
      (pkgs.callPackage ../../pkgs/kotlin-lsp/default.nix { })
      cloc
      auth0-cli
      nixfmt
      nixfmt-tree # Official Nix formatter using treefmt
      nixd
      ncdu
      grpcurl
      ghidra
      protobuf
      gh # GitHub CLI
      # gt completion emits empty output in the build sandbox in 1.8.6, so installShellCompletion aborts; drop postInstall until nixpkgs fixes darwin completion generation.
      (graphite-cli.overrideAttrs { postInstall = ""; }) # Stacked PRs on top of GitHub
      cf-terraforming
      flarectl # Official Cloudflare CLI
      rtk
      codex
      inputs.herdr.packages.${pkgs.system}.default # Terminal multiplexer for AI coding agents
    ];
  };
}

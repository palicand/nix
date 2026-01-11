{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./zsh
    ./git
    ./fish
  ];

  programs = {
    home-manager = {
      enable = true;
      path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
    };

    # CLI tools with declarative configuration
    ripgrep.enable = true;
    jq.enable = true;
    poetry.enable = true;
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
      matchBlocks = {
        "*" = {
          controlMaster = "auto";
          controlPersist = "10m";
          compression = true;
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

    activation = {
      # Skip the app management permission check (known issue on macOS)
      checkAppManagementPermission = lib.mkForce "";

      aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/Applications/Home Manager Applications" ]; then
          ln -sfn $genProfilePath/home-path/Applications "$HOME/Applications/Home Manager Applications"
        fi
      '';
    };

    packages = with pkgs; [
      # Languages/Runtimes
      (python3.withPackages (
        ps: with ps; [
          ipython
          asyncpg
          requests
        ]
      ))

      # Python3 wrapper to fix symlink issue
      (pkgs.writeShellScriptBin "python3-wrapper" ''
        exec ${
          pkgs.python3.withPackages (
            ps: with ps; [
              ipython
              asyncpg
              requests
            ]
          )
        }/bin/python3.13 "$@"
      '')
      (pkgs.writeShellScriptBin "python-wrapper" ''
        exec ${
          pkgs.python3.withPackages (
            ps: with ps; [
              ipython
              asyncpg
              requests
            ]
          )
        }/bin/python3.13 "$@"
      '')

      uv # Fast Python package installer and resolver
      ruby

      # Terminal & CLI tools
      wget
      yadm
      bandwhich
      postgresql_14
      gawk
      rsync
      tree
      yq
      pgcli
      man-db
      jwt-cli
      openvpn
      nodejs
      (yarn.override {
        nodejs = null;
      })
      tig
      glab # GitLab CLI
      ffmpeg
      cmake
      stripe-cli
      k9s
      kubernetes-helm
      openssl
      jdk21_headless
      gradle
      terraform
      claude-code
      cloc
      auth0-cli
      nixfmt
      nixfmt-tree # Official Nix formatter using treefmt
      nixd
      ncdu
    ];
  };
}

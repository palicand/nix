{ config, pkgs, lib, ... }:

{
  imports = [
    ./cli
    ./git
  ];
  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };

  programs.tmux = {
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

  programs.htop = {
    enable = true;
    settings = {
      tree_view = true;
      show_cpu_frequency = true;
    };
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      pager = "less -FR";
    };
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        controlMaster = "auto";
        controlPersist = "10m";
        compression = true;
      };
    };
  };

  xdg.configFile = {
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
      (python3.withPackages (ps: with ps; [
        ipython
        asyncpg
      ]))
      ruby

      # Terminal & CLI tools
      wget
      yadm
      ripgrep
      bandwhich
      postgresql_14
      poetry
      jq
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
      ffmpeg
      cmake
      stripe-cli
      k9s
      kubernetes-helm
      openssl
      jdk21_headless
      (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
      terraform
      claude-code
      cloc
    ];
};
}

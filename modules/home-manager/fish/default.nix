{ config, pkgs, ... }:
{
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.cargo/bin"
  ];

  programs = {
    fish = {
      enable = true;

      shellAliases = {
        grep = "rg";
        cat = "bat";
        iftop = "bandwhich";
        ua = "sudo apt update && sudo apt dist-upgrade -y && sudo apt autoremove -y";
        whatismyip = "dig +short myip.opendns.com @resolver1.opendns.com";
        k = "kubectl";
        rebuild = "darwin-rebuild switch --flake ~/.nixpkgs";
      };

      shellInit = ''
        # Environment variables
        set -gx LANG en_US.UTF-8
        set -gx CLICOLOR 1
        set -gx LS_COLORS "ExFxBxDxCxegedabagacad"
        set -gx TERM xterm-256color

        # Homebrew shell environment (macOS)
        if test -d /opt/homebrew
          eval (/opt/homebrew/bin/brew shellenv)
        end

        # GPG agent for SSH
        set -gx GPG_TTY (tty)
        set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
      '';

      interactiveShellInit = ''
        # Kubectl completion
        kubectl completion fish | source

        # Git worktree wrapper - creates worktree and cds into it
        # Usage: gwt <dir-suffix> <branch-name>
        # Example: gwt feature-123 feat/my-feature
        function gwt
          if test (count $argv) -ne 2
            echo "Usage: gwt <dir-suffix> <branch-name>"
            echo "Example: gwt feature-123 feat/my-feature"
            return 1
          end

          set worktree_dir (git wt $argv[1] $argv[2] | tail -n 1)
          if test -d "$worktree_dir"
            cd "$worktree_dir"
          end
        end
      '';

      plugins = [
        {
          name = "z";
          src = pkgs.fishPlugins.z.src;
        }
        {
          name = "fzf-fish";
          src = pkgs.fishPlugins.fzf-fish.src;
        }
        {
          name = "done";
          src = pkgs.fishPlugins.done.src;
        }
        {
          name = "autopair";
          src = pkgs.fishPlugins.autopair.src;
        }
      ];
    };
  };
}

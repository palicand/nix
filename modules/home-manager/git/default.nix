{
  programs = {
    git = {
      enable = true;
      # signing = {
      #   key = "7E2DD79792CEC919";
      #   signByDefault = true;
      # };
      ignores = [
        ".vscode"
        ".mypy_cache"
        ".pytest_cache"
        "docker-compose.dev.yaml"
        ".env"
        "docs/README.md"
        "*.~lock*"
        "*.egg-info/"
        ".idea/"
        ".metals/"
        ".bloop/"
        "target/"
      ];
      settings = {
        user = {
          name = "Andrej Palicka";
          email = "andrej.palicka@gmail.com";
        };
        alias = {
          lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          fap = "fetch -ap";
          co = "checkout";
          cob = "checkout -b";
          unstage = "reset HEAD --";
          ci = "commit";
          ciam = "commit -am";
          st = "status";
          br = "branch";
          type = "cat-file -t";
          dump = "cat-file -p";
          ff = "merge --ff";
          cleanup = "!git fetch -p && git branch -vv | awk '/: gone]/{print $1}' | xargs git branch -D";
        };
        rerere = {
          enabled = true;
        };
        pull = {
          rebase = true;
        };
        push = {
          autoSetupRemote = true;
        };
      };
      includes = [{
        contents = {
          core = {
            editor = "vim";
          };
          push = {
            default = "simple";
          };
        };
      }];
    };
  };
}

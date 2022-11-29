{
  programs = {
    git = {
      enable = true;
      userName = "Andrej Palicka";
      userEmail = "andrej.palicka@gmail.com";
      aliases = {
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
      };
      signing = {
        key = "7E2DD79792CEC919";
        signByDefault = true;
      };
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
      extraConfig = {
        rerere = {
          enabled = true;
        };
        pull = {
          rebase = true;
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
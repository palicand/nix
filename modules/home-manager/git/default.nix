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
          wt = "!f() { base=$(git rev-parse --show-toplevel); parent=$(dirname \"$base\"); repo_name=$(basename \"$base\"); if git rev-parse --verify origin/main >/dev/null 2>&1; then remote_branch=origin/main; else remote_branch=origin/master; fi; worktree_dir=\"$parent/$repo_name-$1\"; git worktree add --no-track -b \"$2\" \"$worktree_dir\" \"$remote_branch\"; echo 'Copying ignored files to new worktree...'; cd \"$base\"; git ls-files --others --ignored --exclude-standard | while read -r file; do if [ -f \"$file\" ]; then target_dir=\"$worktree_dir/$(dirname \"$file\")\"; mkdir -p \"$target_dir\"; cp \"$file\" \"$worktree_dir/$file\"; fi; done; echo \"$worktree_dir\"; }; f";
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
        init = {
          defaultBranch = "main";
        };
        commit = {
          verbose = true;
        };
        diff = {
          algorithm = "histogram";
          colorMoved = "default";
        };
        merge = {
          conflictstyle = "zdiff3";
        };
        fetch = {
          prune = true;
        };
        rebase = {
          autoStash = true;
          autoSquash = true;
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

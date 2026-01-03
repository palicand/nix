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
          wt = "worktree";
          cwt = "!f() { base=$(git rev-parse --show-toplevel); parent=$(dirname \"$base\"); repo_name=$(basename \"$base\"); if git rev-parse --verify origin/main >/dev/null 2>&1; then remote_branch=origin/main; else remote_branch=origin/master; fi; worktree_dir=\"$parent/$repo_name-$1\"; git worktree add --no-track -b \"$2\" \"$worktree_dir\" \"$remote_branch\"; echo 'Copying ignored files/directories to new worktree...'; cd \"$base\"; copy_exts=$(git config --get worktree.copyExtensions || echo 'env|properties|yaml|yml|json'); copy_dirs=$(git config --get worktree.copyDirectories || echo '\\.vscode|\\.idea|\\.gradle'); all_files=$(git ls-files --others --ignored --exclude-standard); files_by_ext=$(echo \"$all_files\" | grep -E \"\\.($copy_exts)$\"); dirs_by_name=$(echo \"$all_files\" | grep -E \"^($copy_dirs)/\"); combined=$(printf \"%s\\n%s\" \"$files_by_ext\" \"$dirs_by_name\" | grep -v '^$'); file_count=$(echo \"$combined\" | grep -c . || echo 0); if [ $file_count -gt 0 ]; then echo \"Found $file_count file(s)/dir(s) to copy\"; echo \"$combined\" | rsync -a --files-from=- --info=progress2 --no-inc-recursive . \"$worktree_dir/\"; echo 'Copy complete'; else echo 'No ignored files/directories to copy'; fi; echo \"$worktree_dir\"; }; f";
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
        worktree = {
          # File extensions to copy when using 'git cwt' (pipe-separated regex)
          # Default: env|properties|yaml|yml|json
          # Customize per repo: git config worktree.copyExtensions "env|properties|json|xml"
          copyExtensions = "env|properties|yaml|yml|json";

          # Directory names to copy when using 'git cwt' (pipe-separated regex with escaped dots)
          # Default: \.vscode|\.idea|\.gradle
          # Customize per repo: git config worktree.copyDirectories "\.vscode|\.idea"
          # Note: Dots must be escaped as \. for regex matching
          copyDirectories = "\\.vscode|\\.idea|\\.gradle";
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

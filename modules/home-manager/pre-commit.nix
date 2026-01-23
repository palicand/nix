{
  config,
  pkgs,
  lib,
  ...
}:

{
  home = {
    packages = with pkgs; [
      pre-commit
      statix
    ];

    # Generate .pre-commit-config.yaml for ~/.nixpkgs
    file.".nixpkgs/.pre-commit-config.yaml".text = ''
      repos:
        - repo: local
          hooks:
            - id: nixfmt
              name: nixfmt
              entry: nixfmt
              language: system
              files: \.nix$
            - id: statix
              name: statix
              entry: statix check
              language: system
              files: \.nix$
              pass_filenames: false
    '';

    # Install pre-commit hooks during darwin-rebuild switch
    activation.installPreCommitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "$HOME/.nixpkgs/.git" ]; then
        cd "$HOME/.nixpkgs"
        # Unset core.hooksPath if set (pre-commit refuses to install otherwise)
        ${pkgs.git}/bin/git config --unset core.hooksPath 2>/dev/null || true
        ${pkgs.pre-commit}/bin/pre-commit install --install-hooks 2>/dev/null || true
      fi
    '';
  };
}

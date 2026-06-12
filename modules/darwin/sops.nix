{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/tokens.yaml;
    defaultSopsFormat = "yaml";

    # Activation-time decryption uses the host SSH key as an age identity.
    # sops-nix calls ssh-to-age internally; no key material is duplicated.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Each `secrets.<name> = { };` decrypts to /run/secrets/<name> at activation.
    # User-owned so interactive shells can read it to export HOMEBREW_GITHUB_API_TOKEN
    # (mirrors gitlab_pat). The nix-daemon uses the rendered template below, not this file.
    secrets.github_token = {
      owner = config.system.primaryUser;
      mode = "0400";
    };

    # glab OAuth races under concurrent calls; a static PAT avoids it. Owned by the user so shells export GITLAB_TOKEN.
    secrets.gitlab_pat = {
      owner = config.system.primaryUser;
      mode = "0400";
    };

    # Render a Nix config fragment with the token interpolated at activation
    # time. The rendered file lives under /run/secrets/rendered/, so the token
    # value never enters the Nix store — only the path-reference does.
    # User-owned because flake fetching happens in the user's nix client
    # process, not the daemon, and `!include` silently skips unreadable files.
    templates."nix-access-tokens.conf" = {
      owner = config.system.primaryUser;
      mode = "0400";
      content = ''
        access-tokens = github.com=${config.sops.placeholder.github_token}
      '';
    };
  };

  # The path is build-time-known (it's a derivation of the template name);
  # the contents are not.
  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';
}

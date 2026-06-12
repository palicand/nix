{ config, ... }:
let
  # Decrypts to /run/secrets/<name> at activation. User-owned so interactive
  # shells can read it and export the matching env var; the nix-daemon uses the
  # rendered template below, not these files.
  userSecret = {
    owner = config.system.primaryUser;
    mode = "0400";
  };
in
{
  sops = {
    defaultSopsFile = ../../secrets/tokens.yaml;
    defaultSopsFormat = "yaml";

    # Activation-time decryption uses the host SSH key as an age identity.
    # sops-nix calls ssh-to-age internally; no key material is duplicated.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      github_token = userSecret; # HOMEBREW_GITHUB_API_TOKEN
      gitlab_pat = userSecret; # GITLAB_TOKEN; static PAT avoids the glab OAuth race
      gitlab_deploy_token = userSecret; # GITLAB_DEPLOY_TOKEN (bot_bkbn registry/package pulls)
      gitlab_deploy_user = userSecret; # GITLAB_DEPLOY_USER
      notion_api_key = userSecret; # NOTION_API_KEY
      slack_bot_token = userSecret; # SLACK_BOT_TOKEN
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

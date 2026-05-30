{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/tokens.yaml;
    defaultSopsFormat = "yaml";

    # Activation-time decryption uses the host SSH key as an age identity.
    # sops-nix calls ssh-to-age internally; no key material is duplicated.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Each `secrets.<name> = { };` decrypts to /run/secrets/<name> at activation.
    secrets.github_token = { };

    # glab OAuth races under concurrent calls; a static PAT avoids it. Owned by the user so shells export GITLAB_TOKEN.
    secrets.gitlab_pat = {
      owner = config.system.primaryUser;
      mode = "0400";
    };

    # Render a Nix config fragment with the token interpolated at activation
    # time. The rendered file lives under /run/secrets-rendered/, so the token
    # value never enters the Nix store — only the path-reference does.
    templates."nix-access-tokens.conf".content = ''
      access-tokens = github.com=${config.sops.placeholder.github_token}
    '';
  };

  # `!include` makes nix-daemon read the rendered template on each invocation.
  # The path is build-time-known (it's a derivation of the template name);
  # the contents are not.
  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';
}

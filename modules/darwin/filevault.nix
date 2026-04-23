{ config, lib, ... }:

with lib;

let
  cfg = config.system.fileVault;
in
{
  options.system.fileVault = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to assert that FileVault is enabled on the boot volume
        during darwin-rebuild activation. If FileVault is off, activation
        aborts with a remediation message.

        This is an assertion, not an enabler: nix-darwin cannot turn
        FileVault on for you because macOS requires an interactive
        admin password and displays the personal recovery key on screen.
        Enable FileVault once via
          System Settings -> Privacy & Security -> FileVault
        then keep this option true to prevent accidental regressions.

        FileVault on APFS is per-volume. `fdesetup status` reports the
        boot volume's state, which in practice tracks the user Data volume
        alongside it (the two volumes Apple enrolls together when FileVault
        is turned on). Other volumes in the same container -- Preboot,
        Recovery, VM, and the Nix Store volume created by the Nix installer
        -- are intentionally left off FileVault so they can mount before
        login. On Apple Silicon those volumes are still encrypted at rest
        via a hardware key in the Secure Enclave; FileVault adds a second
        layer that binds the key to the user password.
      '';
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts.assertFileVault.text = ''
      echo "Checking FileVault status..."
      if ! /usr/bin/fdesetup status | /usr/bin/grep -q "FileVault is On"; then
        echo >&2 ""
        echo >&2 "ERROR: system.fileVault.enable = true but FileVault is off."
        echo >&2 ""
        echo >&2 "Enable it at:"
        echo >&2 "  System Settings -> Privacy & Security -> FileVault -> Turn On"
        echo >&2 ""
        echo >&2 "Or disable the assertion by setting"
        echo >&2 "  system.fileVault.enable = false;"
        echo >&2 "in modules/darwin/default.nix."
        exit 1
      fi
      echo "FileVault: on."
    '';
  };
}

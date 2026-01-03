{ config, lib, ... }:

with lib;

{
  options = {
    system.chargingChime.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable the charging chime sound when plugging in the power adapter.
        Set to false to disable the charging alert sound.
      '';
    };
  };

  config = {
    system.activationScripts.configureChargingChime.text = ''
      if [ "${toString config.system.chargingChime.enable}" = "1" ]; then
        echo "Enabling charging chime..."
        defaults write com.apple.PowerChime ChimeOnNoHardware -bool false
        open /System/Library/CoreServices/PowerChime.app 2>/dev/null || true
      else
        echo "Disabling charging chime..."
        defaults write com.apple.PowerChime ChimeOnNoHardware -bool true
        killall PowerChime 2>/dev/null || true
      fi
    '';
  };
}

{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = "Iosevka Nerd Font";
        };
        bold = {
          family = "Iosevka Nerd Font";
        };
        italic = {
          family = "Iosevka Nerd Font";
        };
        size = 20;
      };
    };
  };

}

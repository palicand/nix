{ config, lib, pkgs, ... }: {
  programs.git = {
    userEmail = "andrej.palicka@gmail.com";
    userName = "Andrej Palicka";
    signing = {
      key = "andrej.palicka@gmail.com";
      signByDefault = true;
    };
  };
}

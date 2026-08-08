nixpkgs:
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ./options.nix
  ];

  config = {
    # zfs / kernelParams / config.txt firmware handling live in
    # kernels/common.nix so they apply to every kernel variant.

    system.stateVersion = "23.11";

    sdImage.compressImage = false;

    networking.networkmanager.enable = true;
    networking.modemmanager.enable = true;
    powerManagement.cpuFreqGovernor = "ondemand";
    services.openssh.enable = true;

    # ---- Some extra stuff, this should be removed or make it configurable
    # TODO make this configurable
    users.mutableUsers = false;
    users.users.nixos = {
      password = "nixos";
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
      ];
      shell = pkgs.bashInteractive;
    };

    programs.git.enable = true;
    nix.extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };
}

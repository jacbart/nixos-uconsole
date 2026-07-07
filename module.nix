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
    # The sd-image profile enables ZFS, but the ZFS kernel module does not
    # (yet) build against the rpi-7.x kernels.
    boot.supportedFilesystems.zfs = lib.mkForce false;

    boot.kernelParams = [
      "console=serial0,115200"
      "console=tty1"
      # LTE module on USB: autosuspend often causes reconnect glitches / flaky DSI power.
      "usbcore.autosuspend=-1"
    ];

    system.stateVersion = "23.11";

    sdImage.compressImage = false;
    sdImage.populateFirmwareCommands =
      let
        configTxt = pkgs.writeText "config.txt" config.uconsole.boot.configTxt;
      in
      ''
        # Add the config
        rm -f firmware/config.txt
        cp ${configTxt} firmware/config.txt
      '';

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

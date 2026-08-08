{ pkgs, lib, config, ... }:
{
  imports = [ ../options.nix ];

  # Kernel module names can drift between releases; don't fail the initrd
  # closure on a module that no longer exists.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # The sd-image profile enables ZFS, but the ZFS kernel module does not
  # (yet) build against the rpi vendor kernels.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  boot.kernelParams = [
    "console=serial0,115200"
    "console=tty1"
    # LTE module on USB: autosuspend often causes reconnect glitches / flaky DSI power.
    "usbcore.autosuspend=-1"
  ];

  # Feed the variant's uconsole.boot.configTxt into nixos-hardware's firmware
  # installer (raspberry-pi/common/firmware.nix), which owns
  # sdImage.populateFirmwareCommands and runtime firmware updates.
  hardware.raspberry-pi.configtxt.file = pkgs.writeText "uconsole-config.txt" config.uconsole.boot.configTxt;
}

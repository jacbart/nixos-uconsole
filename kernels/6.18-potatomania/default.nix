nixpkgs: nixos-hardware:
{ config, pkgs, lib, ... }:
{
  imports = [
    "${nixos-hardware}/raspberry-pi/4"
    ../common.nix
    (import ./kernel.nix nixpkgs nixos-hardware)
  ];

  # Boot chain: GPU firmware -> U-Boot -> extlinux -> kernel.
  # nixos-hardware's firmware installer populates the firmware partition
  # (GPU boot code, vendor dtbs/overlays, U-Boot, config.txt) both at image
  # build time and, with firmware.enable, on a running system.
  hardware.raspberry-pi.firmware.uboot = {
    enable = true;
    package = pkgs.ubootRaspberryPi4_64bit;
  };

  # The uconsole/vc4/audio overlays are merged into the kernel dtbs at build
  # time (dtmerge below), so U-Boot must load the generation's dtbs via
  # FDTDIR. nixos-hardware's uboot.enable defaults this to false (firmware
  # dtb passthrough); override it.
  boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = true;

  # Rendered into /boot/firmware/config.txt (see kernels/common.nix).
  # Follows the official clockworkpi CM4 image (Code/patch/cm4/20260414),
  # minus the dtoverlay lines that are baked into the dtb by dtmerge.
  uconsole.boot.configTxt = ''
    [all]
    # Boot in 64-bit mode; U-Boot needs the UART regardless of console usage.
    arm_64bit=1
    enable_uart=1

    # Chainload U-Boot (installed as u-boot.bin by nixos-hardware).
    kernel=u-boot.bin

    # Otherwise the resolution will be weird in most cases.
    disable_overscan=1
    max_framebuffers=2

    # Supported in newer board revisions
    arm_boost=1

    # Prevent the firmware from smashing the framebuffer setup done by the
    # mainline kernel when attempting to show low-voltage or overtemperature
    # warnings.
    avoid_warnings=1

    # ------------------------
    ignore_lcd=1
    disable_fw_kms_setup=1
    disable_audio_dither
    pwm_sample_bits=20

    # setup headphone detect pin
    gpio=10=ip,np
    # backlight on as early as possible (GPIO9)
    gpio=9=op,dh

    dtparam=audio=on
    dtparam=ant2
    # dtparam=spi=on
    # ------------------------
  '';

  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
  hardware.raspberry-pi."4".dwc2.enable = true;
  hardware.raspberry-pi."4".dwc2.dr_mode = "host";
  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [
    {
      name = "uconsole,cm4";
      dtsFile = ./uconsole-overlay.dts;
      filter = "bcm2711-rpi-cm4.dtb";
    }
    {
      name = "vc4-kms-v3d-pi4,cma-384";
      dtboFile = "${config.boot.kernelPackages.kernel}/dtbs/overlays/vc4-kms-v3d-pi4.dtbo";
      filter = "bcm2711-rpi-cm4.dtb";
    }
    {
      name = "audremap,pins_12_13";
      dtboFile = "${config.boot.kernelPackages.kernel}/dtbs/overlays/audremap.dtbo";
      filter = "bcm2711-rpi-cm4.dtb";
    }
  ];
}

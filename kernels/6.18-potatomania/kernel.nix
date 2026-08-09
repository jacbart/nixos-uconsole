# uConsole kernel: nixos-hardware's Raspberry Pi 4 kernel (rpi-6.18.y LTS)
# plus the uConsole driver patch set.
#
# IMPORTANT: the kernel is built via nixos-hardware's
# raspberry-pi/common/kernel.nix, whose result goes through `.overrideAttrs`.
# That makes NixOS' `boot.kernelPatches` a SILENT NO-OP for this kernel (the
# `boot.kernelPackages` apply in nixpkgs extends via `.override`, which is
# dropped after overrideAttrs). So patches/config must NOT be added with
# `boot.kernelPatches`; they go through `argsOverride` below, which
# nixos-hardware's kernel.nix splices into the buildLinux call *before*
# overrideAttrs. Note argsOverride.kernelPatches REPLACES the list
# nixos-hardware passes (bridge_stp_helper, request_key_helper), so those are
# re-included here.
nixpkgs: nixos-hardware:
{ pkgs, lib, ... }:
let
  # Patch set: PotatoMania/uconsole-cm3 (dev @ 5d51d1ef), verified to apply
  # cleanly against raspberrypi/linux stable_20260609 (6.18.34).
  patches = [
    ./patches/001-video-backlight-add-ocp8178.patch
    ./patches/002-drm-panel-add-clockwork-cwu50.patch
    ./patches/003-driver-staging-add-uconsole-simple-amplifier-switch.patch
    ./patches/004-drivers-power-axp20x-customize-pmu.patch
    ./patches/005-drm-panel-cwu50-expose-dsi-error-status.patch
  ];

  uconsoleConfig = {
    name = "uconsole-config";
    patch = null;
    structuredExtraConfig = {
      BACKLIGHT_CLASS_DEVICE = lib.kernel.yes;
      DRM_PANEL_CLOCKWORK_CWU50 = lib.kernel.module;
      SIMPLE_AMPLIFIER_SWITCH = lib.kernel.module;
      BACKLIGHT_OCP8178 = lib.kernel.module;

      # The CM4's WiFi power sequencer (wifi-pwrseq) drives WL_REG_ON via the
      # firmware GPIO expander (expgpio 1). bcm2711_defconfig does NOT build
      # the expander driver, so pwrseq_simple stays in deferred probe forever
      # ("reset control not ready") and mmc3 (SDIO WiFi) never enumerates.
      GPIO_RASPBERRYPI_EXP = lib.kernel.yes;

      REGMAP_I2C = lib.kernel.yes;
      INPUT_AXP20X_PEK = lib.kernel.yes;
      CHARGER_AXP20X = lib.kernel.module;
      BATTERY_AXP20X = lib.kernel.module;
      AXP20X_POWER = lib.kernel.module;
      MFD_AXP20X = lib.kernel.yes;
      MFD_AXP20X_I2C = lib.kernel.yes;
      REGULATOR_AXP20X = lib.kernel.yes;
      AXP20X_ADC = lib.kernel.module;
      TI_ADC081C = lib.kernel.module;
      CRYPTO_LIB_ARC4 = lib.kernel.yes; # FIXME
      CRC_CCITT = lib.kernel.yes;

      # 4G/LTE extension (SIM7600G-H on USB). bcm2711_defconfig already
      # builds qmi_wwan / option / cdc-ether as modules; assert them so a
      # defconfig change is loud instead of silently dropping the modem.
      USB_SERIAL_OPTION = lib.kernel.module;
      USB_WDM = lib.kernel.module;
      USB_NET_QMI_WWAN = lib.kernel.module;
      USB_NET_CDCETHER = lib.kernel.module;

      # Parallel pahole BTF-encoding of modules (amdgpu alone needs ~10G)
      # OOMs small aarch64 builders, and module BTF is useless on this
      # device. vmlinux BTF stays on.
      DEBUG_INFO_BTF_MODULES = lib.kernel.no;

      # DWARF debug info for every module more than doubles build time and
      # disk usage (amdgpu.ko alone grows to hundreds of MB); not useful on
      # this device. DEBUG_INFO is a promptless bool driven by a Kconfig
      # choice, so select NONE and force off nixpkgs common-config's
      # DWARF_TOOLCHAIN_DEFAULT. Also drops BTF (depends on DEBUG_INFO).
      DEBUG_INFO_NONE = lib.kernel.yes;
      DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT = lib.mkForce lib.kernel.no;
    };
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.callPackage "${nixos-hardware}/raspberry-pi/common/kernel.nix" {
      rpiVersion = 4;
      argsOverride = {
        kernelPatches = [
          pkgs.kernelPatches.bridge_stp_helper
          pkgs.kernelPatches.request_key_helper
        ]
        ++ (builtins.map (patch: {
          name = patch + "";
          patch = patch;
        }) patches)
        ++ [ uconsoleConfig ];
      };
    }
  );

  boot.initrd.kernelModules = [
    "ocp8178-bl"
    "panel-clockwork-cwu50"
    "simple-amplifier-switch"
    "vc4"
  ];

  systemd.services."serial-getty@ttyS0".enable = false;
}

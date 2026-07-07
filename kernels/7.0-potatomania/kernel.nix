nixpkgs:
{
  pkgs,
  config,
  ...
}:
let
  cfg = config.uconsole.boot.kernel;

  localLib = import ../../lib.nix { inherit nixpkgs; };
  inherit (localLib) callPackagesCrossAarch64;

  kernelPackagesCfg =
    {
      linuxPackagesFor,
      linux_rpi4,
      fetchFromGitHub,
    }:
    let
      # Raspberry Pi fork: branch rpi-7.0.y @ 42d9bb9081f1c55e11abb5cbf4d7bede01d7bdde (Linux 7.0.14).
      # Update `rev` + `hash` together; use `nix flake prefetch github:raspberrypi/linux/<rev>` or the
      # hash-mismatch hint from `nix build`. Requires recent nixpkgs (linux_rpi4 recipe).
      modDirVersion = "7.0.14";
      rev = "42d9bb9081f1c55e11abb5cbf4d7bede01d7bdde";
    in
    linuxPackagesFor (
      linux_rpi4.override {
        argsOverride = {
          version = "${modDirVersion}-rpi-7.0.y";
          inherit modDirVersion;

          src = fetchFromGitHub {
            owner = "raspberrypi";
            repo = "linux";
            inherit rev;
            hash = "sha256-EqElJi0r40+F9LgeTQlJgfjqIFKthOKbG967IuxjxbA=";
          };
        };
      }
    );
  patches = [
    ./patches/001-OCP8178-backlight-driver.patch
    ./patches/002-drm-panel-add-clockwork-cwu50.patch
    ./patches/003-axp20x-power.patch
    ./patches/004-vc4_dsi-update.patch
    ./patches/005-bcm2835-audio-staging.patch
    ./patches/007-drm-panel-cwu50-expose-dsi-error-status-to-userspace.patch
    ./patches/008-driver-staging-add-uconsole-simple-amplifier-switch.patch
  ];
in
{
  boot.kernelPackages =
    if cfg.crossBuild then
      callPackagesCrossAarch64 kernelPackagesCfg { }
    else
      pkgs.callPackages kernelPackagesCfg { };

  boot.initrd.kernelModules = [
    "ocp8178-bl"
    "panel-clockwork-cwu50"
    "simple-amplifier-switch"
    "vc4"
  ];

  boot.kernelPatches =
    (builtins.map (patch: {
      name = patch + "";
      patch = patch;
    }) patches)
    ++ [
      {
        name = "uconsole-config";
        patch = null;
        structuredExtraConfig = {
          BACKLIGHT_CLASS_DEVICE = pkgs.lib.kernel.yes;
          DRM_PANEL_CLOCKWORK_CWU50 = pkgs.lib.kernel.module;
          SIMPLE_AMPLIFIER_SWITCH = pkgs.lib.kernel.module;
          BACKLIGHT_OCP8178 = pkgs.lib.kernel.module;

          REGMAP_I2C = pkgs.lib.kernel.yes;
          INPUT_AXP20X_PEK = pkgs.lib.kernel.yes;
          CHARGER_AXP20X = pkgs.lib.kernel.module;
          BATTERY_AXP20X = pkgs.lib.kernel.module;
          AXP20X_POWER = pkgs.lib.kernel.module;
          MFD_AXP20X = pkgs.lib.kernel.yes;
          MFD_AXP20X_I2C = pkgs.lib.kernel.yes;
          REGULATOR_AXP20X = pkgs.lib.kernel.yes;
          AXP20X_ADC = pkgs.lib.kernel.module;
          TI_ADC081C = pkgs.lib.kernel.module;
          CRYPTO_LIB_ARC4 = pkgs.lib.kernel.yes; # FIXME
          CRC_CCITT = pkgs.lib.kernel.yes;
        };
      }
    ];
  systemd.services."serial-getty@ttyS0".enable = false;
}

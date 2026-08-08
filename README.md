# nixos-uconsole

NixOS module and base SD card image for clockworkPi uConsole.

## Status

For now, only devices using RaspberryPi Compute Module 4 are supported.

The SD image is best verified with a display attached; serial console is configured for early boot.

|                   | Does it work? |
| ----------------- | ------------- |
| boot              | ✓             |
| built-in display  | ✓             |
| backlight         | ✓             |
| hdmi output       | ✓             |
| built-in keyboard | ✓             |
| usb keyboard      | ?             |
| bluetooth         | x             |
| wifi              | ✓             |
| audio             | x             |
| fast charging     | ✓             |

## Kernel variants

The flake exposes `nixosModules."kernel-<name>"` for each tree under `kernels/`. Examples:

| Module name              | Linux                                   | Notes                                                                     |
| ------------------------ | --------------------------------------- | ------------------------------------------------------------------------- |
| `kernel-6.18-potatomania`  | 6.18 LTS (`rpi-6.18.y` via nixos-hardware) | Default. Kernel is nixos-hardware's; only uConsole patches live here. |
| `kernel-6.6-potatomania`   | 6.6 + `stable_20241008` (nixpkgs `linux_rpi4`) | Legacy fallback                                                   |
| `kernel-6.1-potatomania`   | 6.1 + `stable_20231123` (nixpkgs `linux_rpi4`) | Legacy                                                            |

`kernel-6.18-potatomania` builds no kernel itself: it takes `boot.kernelPackages` from
[nixos-hardware](https://github.com/NixOS/nixos-hardware)'s `raspberry-pi/4` module
(currently 6.18.34, `stable_20260609`) and adds the uConsole patch set via
`boot.kernelPatches` (OCP8178 backlight, CWU50 DSI panel, AXP20x PMU/fast-charge,
simple-amplifier-switch). The firmware partition (GPU blobs, U-Boot, `config.txt`) is
populated by nixos-hardware's `raspberry-pi/common/firmware.nix`; the variant's
`uconsole.boot.configTxt` is wired into `hardware.raspberry-pi.configtxt.file`.

Cross-built kernel variants exist for the legacy trees with a `-cross-build` suffix
(e.g. `kernel-6.6-potatomania-cross-build`); they set `uconsole.boot.kernel.crossBuild = true`.
There is no 6.18 cross-build entry — there is no local kernel derivation to cross-compile.

Discover the full list:

```bash
nix flake show
```

## Usage

### NixOS module

Using the module in a plain `configuration.nix` (the `nixos-hardware` argument can be omitted if `nixos-hardware` is installed as a channel):

```nix
{...}: let
    nixos-uconsole = import (builtins.fetchTarball {
      url = "github.com/jacbart/nixos-uconsole";
      sha256 = "...";
    });
    nixos-hardware = builtins.fetchTarball {
      url = "https://github.com/NixOS/nixos-hardware/archive/9a763a7acc4cfbb8603bb0231fec3eda864f81c0.zip";
      sha256 = "1dfpr7aq5avrsagfdxj8rh8jy25sg806dl5m17pp9p529y5fmswn";
    };
  in {
    imports = [
      (nixos-uconsole.mkNixosModule {
        kernel = "6.18-potatomania";
        inherit nixpkgs nixos-hardware;
      })
    ];

    # Other configs come here....
  }
```

Using the module in a flake:

```nix
{

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  inputs.nixos-uconsole.url = "github:jacbart/nixos-uconsole";
  inputs.nixos-uconsole.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-uconsole.inputs.nixos-hardware.follows = "nixos-hardware";


  outputs = {
    nixpkgs,
    nixos-hardware,
    nixos-uconsole,
    ...
  }: let
    user-module = {...}: {
      # your config comes here
    };
  in
    nixosConfigurations.uconsole = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-uconsole.nixosModules.default
        nixos-uconsole.nixosModules."kernel-6.18-potatomania"
        user-module
      ];
    };
}
```

### SD card image

This flake wires `nixosModules.default` (SD image helpers) into `nixosConfigurations.uconsole`. Build the image from the configuration’s `system.build.sdImage` attribute (requires an `aarch64-linux` builder or remote builder):

```bash
nix build '.#nixosConfigurations.uconsole.config.system.build.sdImage' -L
```

The image directory is then under `result/sd-image/` (see NixOS `sd-image-aarch64`).

To use a different kernel module, add the matching `nixos-uconsole.nixosModules."kernel-..."` module to your own `nixosSystem` modules instead of copying `flake.nix` verbatim.

## Updating the kernel (maintainers)

### 6.18 variant (nixos-hardware kernel)

The kernel source pin (`modDirVersion`/`tag`/`hash`) lives in nixos-hardware's
`raspberry-pi/common/kernel.nix`; bump the `nixos-hardware` flake input to move kernels.
Patches live in `kernels/6.18-potatomania/patches/` and are applied in order via
`boot.kernelPatches` in `kernel.nix`. After a nixos-hardware bump:

1. Find the new pin in nixos-hardware's `kernel.nix`, then fetch and unpack that tree:
   ```bash
   curl -L -o linux.tar.gz https://github.com/raspberrypi/linux/archive/refs/tags/<tag>.tar.gz
   tar xzf linux.tar.gz
   ```
2. For each patch, in patch order:
   ```bash
   patch -p1 --dry-run < path/to/patch
   ```
   On failure, re-apply manually or recreate the diff with `diff -u`. The patch set
   tracks [PotatoMania/uconsole-cm3](https://github.com/PotatoMania/uconsole-cm3)
   (`PKGBUILDs/linux-uconsole-rpi64`, currently targeting `rpi-6.16.y`) — check there
   first for an updated patch before hand-porting. VC4/DSI and AXP power-supply code
   are frequent conflict spots when jumping many releases.
3. **Validate**: `nix eval '.#nixosConfigurations.uconsole.config.boot.kernelPackages.kernel.version'`
   should succeed, then `nix build` `config.boot.kernelPackages.kernel` (needs an
   `aarch64-linux`-capable builder).
4. **Device check** after flashing: boot, built-in display, keyboard, Wi‑Fi, power/battery behavior.

### Legacy 6.1/6.6 variants (nixpkgs `linux_rpi4`)

These override nixpkgs' `linux_rpi4` with a pinned `fetchFromGitHub` in
`kernels/<variant>/kernel.nix` (`rev` + `hash` + `modDirVersion`). Update the pin there
and refresh `kernels/<variant>/patches/` the same way as above. Nixpkgs has deprecated
`linux_rpi*` in favour of the nixos-hardware kernel; expect these variants to be removed
rather than updated.

## Development

Cross compilation is selected by importing the `*-cross-build` kernel module from `kernels/default.nix`, which sets `uconsole.boot.kernel.crossBuild = true` (see `kernels/<version>-potatomania/kernel.nix` and `lib.nix`). Only the legacy variants use it.

For cross builds you typically use an `x86_64-linux` machine with `pkgsCross.aarch64-multiplatform` style tooling as wired in this repo’s `callPackagesCrossAarch64` helper.

After flashing, `/boot/firmware/config.txt` is produced from the active variant's
`uconsole.boot.configTxt` (reference copies: `kernels/<variant>/config.txt`).

`nix flake show` lists all exported `nixosModules`.

## Sources

- Kernel patches: https://github.com/PotatoMania/uconsole-cm3 (dev branch, `PKGBUILDs/linux-uconsole-rpi64`)
- Kernel config changes: https://jhewitt.net/uconsole
- Official ClockworkPi CM4 patch/config: https://github.com/clockworkpi/uConsole (`Code/patch/cm4`)

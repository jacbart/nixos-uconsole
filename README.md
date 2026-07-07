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

| Module name            | Linux (Raspberry Pi fork) | Notes                    |
| ---------------------- | ------------------------- | ------------------------ |
| `kernel-7.0-potatomania` | 7.0.14 (`rpi-7.0.y` @ `42d9bb9`, see `kernels/7.0-potatomania/kernel.nix`) | Default in this repo’s sample flake |
| `kernel-6.6-potatomania` | 6.6 + `stable_20241008`     | Previous default         |
| `kernel-6.1-potatomania` | 6.1 + `stable_20231123`     | Legacy                   |

Cross-built kernel variants use the same logical name with a `-cross-build` suffix (e.g. `kernel-7.0-potatomania-cross-build`). They set `uconsole.boot.kernel.crossBuild = true` for toolchain convenience; building still targets `aarch64-linux`.

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
        kernel = "7.0-potatomania";
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
        nixos-uconsole.nixosModules."kernel-7.0-potatomania"
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

Patches live in `kernels/<version>-potatomania/patches/` and are applied in lexicographic order via `boot.kernelPatches` in `kernel.nix`. When bumping the Raspberry Pi kernel tree:

1. **Pick a revision** on [raspberrypi/linux](https://github.com/raspberrypi/linux): branch `rpi-7.0.y` (or newer `rpi-7.x.y` when you add another variant). Prefer a **tag** or **commit hash** for reproducibility, not a floating branch name, in `fetchFromGitHub.rev`.

2. **Set `modDirVersion`** in `kernels/<variant>/kernel.nix` to match that tree’s `VERSION`, `PATCHLEVEL`, and `SUBLEVEL` in its top-level `Makefile` (e.g. `7.0.3`).

3. **Update the fixed-output hash** for `fetchFromGitHub`. After a failed build, Nix prints the expected `sha256-...` SRI hash; you can also unpack the same commit and run:
   ```bash
   nix hash path --sri /path/to/unpacked/linux-sources
   ```
   (layout should match GitHub’s archive after stripping one top-level directory, same as Nix’s `fetchFromGitHub`.)

4. **Refresh patches**: extract the new tree, then for each patch:
   ```bash
   patch -p1 --dry-run < path/to/patch
   ```
   On failure, re-apply manually or recreate the diff with `diff -u`. Drop patches that are already upstream. VC4/DSI and AXP power-supply code are frequent conflict spots when jumping many releases.

5. **Register the variant** in `kernels/default.nix` (native + optional `-cross-build` entry).

6. **Validate**: `nix eval '.#nixosConfigurations.uconsole.config.boot.kernelPackages.kernel.version'` (or your config) should succeed. A full `nix build` of `config.boot.kernelPackages.kernel` or `system.build.sdImage` needs an `aarch64-linux`-capable builder.

7. **Device check** after flashing: boot, built-in display, keyboard, Wi‑Fi, power/battery behavior.

PotatoMania’s tree is a useful reference ([uconsole-cm3](https://github.com/PotatoMania/uconsole-cm3)); this repo carries its own patch set and does not track it automatically.

## Development

Cross compilation is selected by importing the `*-cross-build` kernel module from `kernels/default.nix`, which sets `uconsole.boot.kernel.crossBuild = true` (see `kernels/<version>-potatomania/kernel.nix` and `lib.nix`).

For cross builds you typically use an `x86_64-linux` machine with `pkgsCross.aarch64-multiplatform` style tooling as wired in this repo’s `callPackagesCrossAarch64` helper.

After flashing, ensure `/boot/config.txt` matches the snippets from the active kernel directory (e.g. `kernels/7.0-potatomania/config.txt`) if you customize firmware behaviour.

`nix flake show` lists all exported `nixosModules`.

Nixpkgs may print a note that the `linux-rpi` attribute is deprecated in favour of patterns from `nixos-hardware`; this flake still uses `linux_rpi4` overrides until that migration is done upstream in a compatible way.

## Sources

- Kernel patches inspired by: https://github.com/PotatoMania/uconsole-cm3
- Kernel config changes: https://jhewitt.net/uconsole

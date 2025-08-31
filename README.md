# nixos-uconsole

NixOS module and base SD card image for clockworkPi uConsole.

## Status

For now, only devices using RaspberryPi Compute Module 4 are supported.

Many things just doesn't work at the moment, the sd image boots, but it can only be confirmed using
the HDMI output, and it's impossible to log in since the keyboard doesn't work.

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

## Usage

### NixOS module

Using the module in a plain `configuration.nix` (please note that, the `nixos-hardware` value can be
omitted if `nixos-hardware` is added as a channel):

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
        kernel = "6.1-potatomania";
        inherit nixpkgs nixos-hardware;
      })
    ];

    # Other configs come here....
  }
```

Using the module in a flake:

```nix
{

  inputs.nixpkgs.url = "nixpkgs/release-25.05";
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
        nixos-uconsole.nixosModules."kernel-6.1-potatomania"
        user-module
      ];
    };
}
```

### SD card image

Build one of the sd-image packages, e.g:

```
nix build .\#packages.aarch64-linux.\"sd-image-cm4-6.1-potatomania\" -L
```

Then flash the img file from `result/sd-image`. For more information see [Development](#development)
section.

## Development

The kernels are available in 2 versions:

as normal `aarch64-linux` build, e.g:

```bash
nix build .\#packages.aarch64-linux.\"sd-image-cm4-6.1-potatomania\" -L
```

and with a config where the kernel is cross built on `x86_64-linux`, e.g:

```bash
nix build .\#packages.aarch64-linux.\"sd-image-cm4-6.1-potatomania-cross-build\" -L
```

For cross building you'll need 2 machines: an `x86_64-linux` and an `aarch64-linux` build machine.
This is useful when you want to offload the kernel compilation to a potentially stronger computer
using cross compilation.

Once the image is flashed into an SD card the `/boot/config.txt` needs to be updated and copied over
from the relevant kernel's directory.

The available images, and NixOS modules are all discoverable using `nix flake show`.

## Sources

- Kernel patches from : https://github.com/PotatoMania/uconsole-cm3
- Kernel config changes: https://jhewitt.net/uconsole

{
  description = "NixOS support for clockworkPi uConsole";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
    }:
    let
      system = "aarch64-linux";

      overlays = [
        (final: super: {
          makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
        })
      ];

      pkgs = import nixpkgs { inherit system overlays; };

      base-module = import ./module.nix nixpkgs;
      kernels = import ./kernels/default.nix nixpkgs nixos-hardware;

      base-system-cm4 =
        kernel:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;

          modules = [
            base-module
            kernel
          ];
        };

      images = pkgs.lib.attrsets.mapAttrs' (name: value: {
        name = "sd-image-cm4-${name}";
        value = (base-system-cm4 value).config.system.build.sdImage;
      }) kernels;

      vm-tests =
        let
          nixos-lib = import (nixpkgs + "/nixos/lib") { };
        in
        nixos-lib.runTest {
          imports = [ (import ./tests.nix nixpkgs) ];
          name = "nixos-uconsole-test";
          hostPkgs = import nixpkgs { system = "aarch64-linux"; };
        };
    in
    {
      packages."aarch64-linux" = images // {
        inherit vm-tests;
      };

      nixosConfigurations.uconsole = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.outputs.nixosModules.default
          self.outputs.nixosModules."kernel-6.6-potatomania"
        ];
      };

      nixosModules = {
        default = base-module;
      }
      // (pkgs.lib.attrsets.mapAttrs' (name: value: {
        name = "kernel-${name}";
        inherit value;
      }) kernels);

    };
}

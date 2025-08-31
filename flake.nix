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
    in
    {
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

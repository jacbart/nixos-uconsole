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
      base-module = import ./module.nix nixpkgs;
      kernels = import ./kernels/default.nix nixpkgs nixos-hardware;
    in
    {
      nixosConfigurations.uconsole = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.outputs.nixosModules.default
          self.outputs.nixosModules."kernel-6.18-potatomania"
        ];
      };

      nixosModules = {
        default = base-module;
      }
      // (nixpkgs.lib.attrsets.mapAttrs' (name: value: {
        name = "kernel-${name}";
        inherit value;
      }) kernels);

    };
}

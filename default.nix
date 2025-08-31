{
  mkNixosModule =
    {
      kernel,
      nixpkgs ? <nixpkgs>,
      nixos-hardware ? <nixos-hardware>,
    }:
    let
      kernels = import ./kernels nixpkgs nixos-hardware;
      baseModule = import ./module.nix nixpkgs;
    in
    { lib, ... }:
    {
      imports = [
        baseModule
        kernels.${kernel}
      ];

      nixpkgs.overlays = [
        (final: super: {
          makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
        })
        (final: super: {
          zfs = super.zfs.overrideAttrs (_: {
            meta.platforms = [ ];
          });
        }) # disable zfs, required for cross built kernels
      ];
    };
}

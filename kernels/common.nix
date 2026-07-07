{ ... }:
{
  imports = [ ../options.nix ];

  # Kernel module names can drift between releases; don't fail the initrd
  # closure on a module that no longer exists.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
}

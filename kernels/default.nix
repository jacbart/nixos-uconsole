nixpkgs: nixos-hardware: {
  "6.1-potatomania" =
    { ... }:
    {
      imports = [ (import ./6.1-potatomania nixpkgs nixos-hardware) ];
      uconsole.boot.kernel.crossBuild = false;
    };
  "6.1-potatomania-cross-build" = {
    imports = [ (import ./6.1-potatomania nixpkgs nixos-hardware) ];
    uconsole.boot.kernel.crossBuild = true;
  };
  "6.6-potatomania" =
    { ... }:
    {
      imports = [ (import ./6.6-potatomania nixpkgs nixos-hardware) ];
      uconsole.boot.kernel.crossBuild = false;
    };
  "6.6-potatomania-cross-build" = {
    imports = [ (import ./6.6-potatomania nixpkgs nixos-hardware) ];
    uconsole.boot.kernel.crossBuild = true;
  };
}

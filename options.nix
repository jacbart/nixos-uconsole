{ lib, ... }:
{
  options = {
    uconsole.boot.configTxt = lib.mkOption {
      type = lib.types.str;
    };
    uconsole.boot.kernel.crossBuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
}

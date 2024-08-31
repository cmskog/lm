args @
  {
    pkgs ? import <nixpkgs> {},
    ...
  }:
pkgs.callPackage ./. (removeAttrs args ["pkgs"])

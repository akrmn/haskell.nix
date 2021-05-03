commandArgs:
let
  hixProject = {
        options = {
          haskellNix = lib.mkOption {
            type = lib.types.unspecified;
            default = null;
          };
          nixpkgsPin = lib.mkOption {
            type = lib.types.str;
            default = "nixpkgs-unstable";
          };
          nixpkgs = lib.mkOption {
            type = lib.types.unspecified;
            default = null;
          };
          nixpkgsArgs = lib.mkOption {
            type = lib.types.unspecified;
            default = null;
          };
          overlays = lib.mkOption {
            type = lib.types.unspecified;
            default = [];
          };
          pkgs = lib.mkOption {
            type = lib.types.unspecified;
            default = null;
          };
          project = lib.mkOption {
            type = lib.types.unspecified;
            default = null;
          };
        };
      };
  inherit ((lib.evalModules {
    modules = [
      hixProject
      {
        options = {
          projectFileName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
      (import ../modules/stack-project.nix)
      (import ../modules/cabal-project.nix)
      commandArgs
    ];
  }).config) src;
  sources = import ../nix/sources.nix {};
  lib = import (sources.nixpkgs-unstable + "/lib");
  commandArgs' =
    builtins.listToAttrs (
      builtins.concatMap (
        name:
          if commandArgs.${name} == null
            then []
            else [{ inherit name; value = commandArgs.${name}; }]
    ) (builtins.attrNames commandArgs));
  defaultArgs = {
    nixpkgsPin = "nixpkgs-unstable";
  };
  importDefaults = src:
    if src == null || !(__pathExists src)
      then {}
      else import src;
  userDefaults = importDefaults (commandArgs.userDefaults or null);
  projectDefaults = importDefaults (toString (src.origSrcSubDir or src) + "/nix/hix.nix");
in (lib.evalModules {
    modules = [
      hixProject
      {
        options = {
          projectFileName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
      (import ../modules/stack-project.nix)
      (import ../modules/cabal-project.nix)
      userDefaults
      projectDefaults
      commandArgs
      ({config, pkgs, ...}: {
        haskellNix = import ./.. {};
        nixpkgsPin = "nixpkgs-unstable";
        nixpkgs = config.haskellNix.sources.${config.nixpkgsPin};
        nixpkgsArgs = config.haskellNix.nixpkgsArgs // {
          overlays = config.haskellNix.nixpkgsArgs.overlays ++ config.overlays;
        };
        pkgs = import config.nixpkgs config.nixpkgsArgs;
        project = config.pkgs.haskell-nix.project [
            hixProject
            userDefaults
            projectDefaults
            commandArgs
          ];
      })
    ];
  }).config.project
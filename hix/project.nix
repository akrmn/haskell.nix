{ src
, userDefaults ? {}
, nxipkgs ? null
, nixpkgsPin ? null
, pkgs ? null
, compiler-nix-name ? null
, shell ? null
, ...}@commandArgs:
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
  hixDefaults = { compiler-nix-name = lib.mkDefault "ghc8104"; };
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
#      (import ../modules/stack-project.nix)
      (import ../modules/cabal-project.nix)
      projectDefaults
      commandArgs'
      { _module.args.pkgs = {}; }
    ];
  }).config) name;
  sources = import ../nix/sources.nix {};
  lib = import (sources.nixpkgs-unstable + "/lib");
  commandArgs' =
    builtins.listToAttrs (
      builtins.concatMap (
        name:
          if commandArgs.${name} == null || name == "src" || name == "userDefaults"
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
      hixDefaults
      userDefaults
      projectDefaults
      commandArgs'
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
            hixDefaults
            userDefaults
            projectDefaults
            commandArgs'
            {
              src =
                if __pathExists (toString (src.origSrcSubDir or src) + "/.git")
                  then config.pkgs.haskell-nix.haskellLib.cleanGit {
                    inherit name;
                    inherit src;
                  }
                  else src;
            }
          ];
      })
    ];
  }).config) project shell;
in project
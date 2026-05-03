# tendril's sole flake. exposes per-language dev shells, a polyglot default
# shell, docker images for linux, and a `lib` consumers can compose with.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>           (e.g. ...typescript)
#   tendril.devShells.<sys>.default          (polyglot — every registered lang)
#   tendril.lib.<lang>.{module, mkShell, mkDockerImage}
#   tendril.lib.tendrilNvim                  (the nvim builder, for custom shells)
#   tendril.lib.ideModule                    (raw ide module for manual composition)
#   tendril.lib.{mkShell, mkDockerImage}     (generic builders over modules lists)
#   tendril.packages.<linux-sys>.<lang>      (pre-built docker images)
#
# also activated by the repo's own `.envrc` for working on tendril itself.
{
  description = "tendril: polyglot dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixvim: declarative neovim config framework. used by `nix/modules/ide/build.nix`
    # to construct the editor that's composed into every language shell.
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
    }:
    let
      # shared helpers (see `./nix/lib/default.nix`).
      tendrilLib = import ./nix/lib { inherit nixpkgs nixvim; };
      inherit (tendrilLib)
        forAllSystems
        ideModule
        mkShell
        mkDockerImage
        mkLanguageLib
        tendrilNvim
        ;

      # docker images need linux pkgs (the contents end up running inside the
      # container). darwin pkgs would build darwin binaries, broken images.
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;

      # registry of languages tendril knows about. adding a new language is a
      # one-line addition here, plus a `nix/modules/<lang>/module.nix`.
      #
      # values are module *functions* (`{ pkgs } -> module`), not modules.
      # we delay evaluation until we know which system's `pkgs` to use.
      languages = {
        go = import ./nix/modules/go/module.nix;
        nix = import ./nix/modules/nix/module.nix;
        typescript = import ./nix/modules/typescript/module.nix;
      };

      # per-system: build the modules list (every language + ide) once. the
      # configured nvim is built once here too, then shared across all
      # builders so we don't re-derive it per shell or per image.
      modulesFor =
        pkgs:
        let
          nvim = tendrilNvim pkgs;
          languageModules = builtins.mapAttrs (_: mkModule: mkModule { inherit pkgs; }) languages;
          ide = ideModule { inherit pkgs nvim; };
        in
        {
          inherit languageModules ide;
          # all languages + ide, ready to splat into a polyglot builder.
          all = (builtins.attrValues languageModules) ++ [ ide ];
        };
    in
    {
      # for each supported system, expose:
      #   - one named shell per language (e.g. `devShells.<sys>.typescript`)
      #   - `default`, the polyglot shell merging every registered language
      #     (what `.envrc` activates and `nix develop` picks by default)
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mods = modulesFor pkgs;
        in
        builtins.mapAttrs (
          _: langModule:
          mkShell {
            inherit pkgs;
            modules = [
              langModule
              mods.ide
            ];
          }
        ) mods.languageModules
        // {
          default = mkShell {
            inherit pkgs;
            modules = mods.all;
          };
        }
      );

      # docker images parallel to the dev shells: per-language plus a polyglot
      # `default`. linux only, see `linuxSystems` above for why.
      packages = forLinuxSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mods = modulesFor pkgs;
        in
        builtins.mapAttrs (
          name: langModule:
          mkDockerImage {
            inherit pkgs;
            name = "tendril-${name}";
            modules = [
              langModule
              mods.ide
            ];
          }
        ) mods.languageModules
        // {
          default = mkDockerImage {
            inherit pkgs;
            name = "tendril";
            modules = mods.all;
          };
        }
      );

      # `lib.<lang>.{module, mkShell, mkDockerImage}` for each language, plus
      # the building blocks consumers may want for custom composition:
      #   - `tendrilNvim`: pkgs -> configured nvim derivation
      #   - `ideModule`:   raw ide module function
      #   - `mkShell` / `mkDockerImage`: generic builders over modules lists
      lib = (builtins.mapAttrs (_: mkLanguageLib) languages) // {
        inherit
          tendrilNvim
          ideModule
          mkShell
          mkDockerImage
          ;
      };

      # `nix fmt` reads this. exposed at the umbrella level so consumers
      # pinning tendril can format their nix with our chosen tool.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

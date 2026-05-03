# tendril's sole flake. exposes per-language dev shells, a polyglot default
# shell, docker images for linux, and a `lib` consumers can compose with.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>              (e.g. ...typescript)
#   tendril.devShells.<sys>.default             (polyglot w/ every registered lang)
#   tendril.packages.<linux-sys>.<lang>         (pre-built docker images)
#   tendril.lib.<lang>.{mkShell, mkDockerImage} (extras-accepting variants of
#                                                the pre-built shells/images)
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
        mkComposer
        mkDockerImage
        mkLanguageLib
        mkShell
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

      # per-system, evaluate every language module and resolve the ide once
      # (via `mkComposer`, which also builds nvim). returns the per-language
      # modules list (with ide composed in) for builder consumption, plus an
      # `all` list for the polyglot default.
      modulesFor =
        pkgs:
        let
          composer = mkComposer pkgs;
          languageModules = builtins.mapAttrs (_: mkModule: mkModule { inherit pkgs; }) languages;
        in
        {
          inherit languageModules;
          inherit (composer) ide;
          perLanguage = builtins.mapAttrs (_: composer.withIde) languageModules;
          all = (builtins.attrValues languageModules) ++ [ composer.ide ];
        };

      # produce the per-language attrs (one entry per language) plus a
      # polyglot `default`, keyed by system. `build` is called as
      # `build { pkgs, name, modules }` for each entry; callers ignore `name`
      # (devShells) or use it to pick an image name (packages).
      mkPerLanguageOutputs =
        {
          genAttrsForSystems,
          build,
        }:
        genAttrsForSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            mods = modulesFor pkgs;
            buildOne = name: modules: build { inherit pkgs name modules; };
          in
          builtins.mapAttrs buildOne mods.perLanguage
          // {
            default = buildOne "default" mods.all;
          }
        );
    in
    {
      # for each supported system, one named shell per language plus a
      # polyglot `default`.
      devShells = mkPerLanguageOutputs {
        genAttrsForSystems = forAllSystems;
        build =
          {
            pkgs,
            modules,
            ...
          }:
          mkShell { inherit pkgs modules; };
      };

      # docker images parallel to the dev shells. linux only, see
      # `linuxSystems` above for why. per-language images get a `tendril-`
      # prefix; the polyglot one is just `tendril`.
      packages = mkPerLanguageOutputs {
        genAttrsForSystems = forLinuxSystems;
        build =
          {
            pkgs,
            name,
            modules,
          }:
          mkDockerImage {
            inherit pkgs modules;
            name = if name == "default" then "tendril" else "tendril-${name}";
          };
      };

      # `lib.<lang>.{mkShell, mkDockerImage}`: the function-form of the
      # pre-built `devShells` / `packages` outputs above. exists so consumers
      # can pass `extraPackages` / `extraEnv` / `extraShellHook` (the flake
      # outputs are concrete derivations and can't accept those).
      lib = builtins.mapAttrs (_: mkLanguageLib) languages;

      # `nix fmt` reads this. exposed at the umbrella level so consumers
      # pinning tendril can format their nix with our chosen tool.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

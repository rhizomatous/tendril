# tendril's sole flake. exposes per-language dev shells, a polyglot default
# shell, docker images for linux, and a `lib` consumers can compose with.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>              (e.g. ...typescript)
#   tendril.devShells.<sys>.<lang>-bare         (same, without bundled nvim+git)
#   tendril.devShells.<sys>.default             (polyglot w/ every registered lang)
#   tendril.devShells.<sys>.default-bare        (polyglot, no ide)
#   tendril.packages.<linux-sys>.<lang>[-bare]  (pre-built docker images, same flavors)
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
      # (via `mkComposer`, which also builds nvim). returns a flat attrset
      # keyed by output name, where each value is the modules list for that
      # output. four flavors per system:
      #   <lang>         language module & ide
      #   <lang>-bare    language module only, no ide
      #   default        every language & ide
      #   default-bare   every language, no ide
      modulesFor =
        pkgs:
        let
          composer = mkComposer pkgs;
          languageModules = builtins.mapAttrs (_: mkModule: mkModule { inherit pkgs; }) languages;
          langs = builtins.attrValues languageModules;
          withIde = builtins.mapAttrs (_: composer.withIde) languageModules;
          bare = nixpkgs.lib.mapAttrs' (n: m: {
            name = "${n}-bare";
            value = composer.withoutIde m;
          }) languageModules;
          # tooling for working on tendril itself
          tendrilDev = {
            packages = [ pkgs.lefthook ];
          };
        in
        withIde
        // bare
        // {
          default = langs ++ [
            composer.ide
            tendrilDev
          ];
          default-bare = langs;
        };

      # produce the per-language outputs keyed by system. `build` is called
      # as `build { pkgs, name, modules }` for each entry; callers ignore
      # `name` (devShells) or use it for naming (packages).
      #
      # tags every output with `TENDRIL_ENV=<name>` so a consumer can tell
      # programmatically (e.g. from a shell prompt or script) which tendril
      # env they're sitting in.
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
          in
          builtins.mapAttrs (
            name: modules:
            build {
              inherit pkgs name;
              modules = modules ++ [ { env.TENDRIL_ENV = name; } ];
            }
          ) mods
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
      # prefix; the polyglot ones drop it.
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
            name =
              {
                default = "tendril";
                default-bare = "tendril-bare";
              }
              .${name} or "tendril-${name}";
          };
      };

      # `lib.<lang>.{mkShell, mkDockerImage}`: the function-form of the
      # pre-built `devShells` / `packages` outputs above. exists so consumers
      # can pass `extraPackages` / `extraEnv` / `extraShellHook` (the flake
      # outputs are concrete derivations and can't accept those).
      lib = builtins.mapAttrs mkLanguageLib languages;

      # `nix fmt` reads this. exposed at the umbrella level so consumers
      # pinning tendril can format their nix with our chosen tool.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

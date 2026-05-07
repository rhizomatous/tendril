# tendril's flake. exposes per-language dev shells, a polyglot default
# shell, docker images for linux, and a `lib` consumers can compose with.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>[-{editor,agent,bare}]   (full | no agent | no ide | neither)
#   tendril.devShells.<sys>.default[-{editor,agent,bare}]  (polyglot, same four flavours)
#   tendril.packages.<linux-sys>.<lang>[-{editor,agent,bare}]   (pre-built docker images)
#   tendril.lib.<lang>.{mkShell, mkDockerImage}            (extras-accepting variants of
#                                                           the pre-built shells/images)
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
      # shared helpers
      tendrilLib = import ./nix/lib { inherit nixpkgs nixvim; };
      inherit (tendrilLib)
        forAllSystems
        mkComposer
        mkLanguageLib
        ;

      # builders
      mkShell = import ./nix/builders/mkShell.nix;
      mkDockerImage = import ./nix/builders/mkDockerImage.nix;

      # docker images need linux pkgs, so we can't build on MacOS right now
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;

      # registry of languages tendril knows about. adding a new language is a
      # one-line addition here, plus a `nix/modules/<lang>/module.nix`.
      languages = {
        go = import ./nix/modules/go/module.nix;
        nix = import ./nix/modules/nix/module.nix;
        typescript = import ./nix/modules/typescript/module.nix;
      };

      # per-system, evaluate every language module and resolve the
      # cross-cutting modules once (via `mkComposer`). returns a flat attrset
      # keyed by output name, where each value is the modules list for that
      # output. four flavours per language, plus four polyglot variants:
      #   <lang>          core + lang + ide + agent  (full)
      #   <lang>-editor   core + lang + ide          (no agent)
      #   <lang>-agent    core + lang + agent        (no editor)
      #   <lang>-bare     core + lang                (neither)
      #   default[-...]   polyglot variants of the above
      modulesFor =
        pkgs:
        let
          composer = mkComposer pkgs;
          languageModules = builtins.mapAttrs (_: mkModule: mkModule { inherit pkgs; }) languages;
          langs = builtins.attrValues languageModules;
          # render one flavour across every language
          flavour =
            suffix: withIde: withAgent:
            nixpkgs.lib.mapAttrs' (name: lm: {
              name = "${name}${suffix}";
              value = composer.compose {
                langModule = lm;
                inherit withIde withAgent;
              };
            }) languageModules;
          polyglotBase = [ composer.coreTools ] ++ langs;
        in
        flavour "" true true
        // flavour "-editor" true false
        // flavour "-agent" false true
        // flavour "-bare" false false
        // {
          default = polyglotBase ++ [
            composer.ide
            composer.agent
          ];
          default-editor = polyglotBase ++ [ composer.ide ];
          default-agent = polyglotBase ++ [ composer.agent ];
          default-bare = polyglotBase;
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
      # `linuxSystems` above for why.
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
            # `default[-flavour]` images get renamed `tendril[-flavour]`
            name =
              if nixpkgs.lib.hasPrefix "default" name then
                "tendril${nixpkgs.lib.removePrefix "default" name}"
              else
                "tendril-${name}";
          };
      };

      # `lib.<lang>.{mkShell, mkDockerImage}`: the function-form of the
      # pre-built `devShells` / `packages` outputs above. exists so consumers
      # can pass `extraPackages` / `extraEnv` / `extraShellHook` (the flake
      # outputs are concrete derivations and can't accept those).
      lib = builtins.mapAttrs mkLanguageLib languages;

      # `nix fmt` reads this.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

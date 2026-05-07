# tendril's flake. exposes per-language dev shells, a polyglot default
# shell, and matching docker images for linux.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>[-{editor,agent,bare}]      (full | no agent | no ide | neither)
#   tendril.devShells.<sys>.default[-{editor,agent,bare}]     (polyglot, same four flavours)
#   tendril.packages.<linux-sys>.<lang>[-{editor,agent,bare}] (pre-built docker images)
#
# also activated by the repo's own `.envrc` for working on tendril itself.
{
  description = "tendril: polyglot dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixvim: declarative neovim config framework. used by `nix/kits/ide.nix`
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
      # helpers
      forAllSystems = import ./nix/utils/forAllSystems.nix { inherit nixpkgs; };
      mkComposer = import ./nix/utils/mkComposer.nix { inherit nixvim; };

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
      # one-line addition here, plus a `nix/kits/languages/<lang>.nix`.
      languages = {
        go = import ./nix/kits/languages/go.nix;
        nix = import ./nix/kits/languages/nix.nix;
        typescript = import ./nix/kits/languages/typescript.nix;
      };

      # per-system, evaluate every language kit and resolve the
      # cross-cutting kits once (via `mkComposer`). returns a flat attrset
      # keyed by output name, where each value is the kit list for that
      # output. four flavours per language, plus four polyglot variants:
      #   <lang>          core + lang + ide + agent  (full)
      #   <lang>-editor   core + lang + ide          (no agent)
      #   <lang>-agent    core + lang + agent        (no editor)
      #   <lang>-bare     core + lang                (neither)
      #   default[-...]   polyglot variants of the above
      kitsFor =
        pkgs:
        let
          composer = mkComposer pkgs;
          languageKits = builtins.mapAttrs (_: mkKit: mkKit { inherit pkgs; }) languages;
          langs = builtins.attrValues languageKits;
          # render one flavour across every language
          flavour =
            suffix: withIde: withAgent:
            nixpkgs.lib.mapAttrs' (name: lk: {
              name = "${name}${suffix}";
              value = composer.compose {
                langKit = lk;
                inherit withIde withAgent;
              };
            }) languageKits;
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
      # as `build { pkgs, name, kits }` for each entry; callers ignore
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
            kits = kitsFor pkgs;
          in
          builtins.mapAttrs (
            name: kitList:
            build {
              inherit pkgs name;
              kits = kitList ++ [ { env.TENDRIL_ENV = name; } ];
            }
          ) kits
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
            kits,
            ...
          }:
          mkShell { inherit pkgs kits; };
      };

      # docker images parallel to the dev shells. linux only, see
      # `linuxSystems` above for why.
      packages = mkPerLanguageOutputs {
        genAttrsForSystems = forLinuxSystems;
        build =
          {
            pkgs,
            name,
            kits,
          }:
          mkDockerImage {
            inherit pkgs kits;
            # `default[-flavour]` images get renamed `tendril[-flavour]`
            name =
              if nixpkgs.lib.hasPrefix "default" name then
                "tendril${nixpkgs.lib.removePrefix "default" name}"
              else
                "tendril-${name}";
          };
      };

      # `nix fmt` reads this.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

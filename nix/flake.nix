# this umbrella flake re-exports each language's dev shell and lib in one place,
# so consumers can pin a single input
#   inputs.tendril.url = "github:rhizomatous/tendril?dir=nix";
# and reach everything via
#   tendril.devShells.<sys>.<lang>          (e.g. ...typescript)
#   tendril.lib.<lang>.{module, mkShell}    (e.g. tendril.lib.typescript.mkShell)
#   tendril.lib.tendrilNvim                 (the nvim builder, for custom shells)
#
# also defines `devShells.<sys>.default`, the polyglot shell for working *on*
# tendril itself, activated via .envrc.
{
  description = "tendril: polyglot dev environment library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixvim — declarative neovim config framework. used by `flakes/ide/build.nix`
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
      # shared helpers (see `./lib/default.nix`).
      tendrilLib = import ./lib { inherit nixpkgs; };
      inherit (tendrilLib)
        forAllSystems
        mkShell
        mergeModules
        mkLanguageLib
        ;

      # the IDE-specific nvim builder — lives with the rest of the nvim stuff
      # under `flakes/ide/`. signature: pkgs -> configured nvim derivation.
      tendrilNvim = import ./flakes/ide/build.nix { inherit nixvim; };

      # registry of languages tendril knows about. adding a new language is a
      # one-line addition here, plus a `flakes/<lang>/module.nix`.
      #
      # values are module *functions* (`{ pkgs, nvim } -> module`), not modules.
      # we delay evaluation until we know which system's `pkgs` (and nvim) to use.
      languages = {
        typescript = import ./flakes/typescript/module.nix;
        go = import ./flakes/go/module.nix;
        nix = import ./flakes/nix/module.nix;
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

          # the configured nvim, built once per system and threaded through
          # to every language module so we don't re-derive it per shell.
          nvim = tendrilNvim pkgs;

          languageShells = builtins.mapAttrs (
            _: mkModule:
            mkShell {
              inherit pkgs;
              module = mkModule { inherit pkgs nvim; };
            }
          ) languages;
        in
        languageShells
        // {
          # the polyglot default. each language module already composes the IDE,
          # so `mergeModules` de-dupes `packages` so nvim appears once.
          default = mkShell {
            inherit pkgs;
            module = mergeModules (
              map (mkModule: mkModule { inherit pkgs nvim; }) (builtins.attrValues languages)
            );
          };
        }
      );

      # `lib.<lang>.{module, mkShell}` for each language, plus `lib.tendrilNvim`
      # so consumers wiring up `lib.<lang>.mkShell { pkgs; nvim }` themselves
      # have access to the configured nvim builder.
      lib = (builtins.mapAttrs (_: mkLanguageLib) languages) // {
        inherit tendrilNvim;
      };

      # `nix fmt` reads this. exposed at the umbrella level so consumers
      # pinning tendril can format their nix with our chosen tool.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

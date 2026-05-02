# this umbrella flake re-exports each language's dev shell and lib in one place,
# so consumers can pin a single input
#   inputs.tendril.url = "github:rhizomatous/tendril?dir=nix";
# and reach everything via
#   tendril.devShells.<sys>.<lang>          (e.g. ...typescript)
#   tendril.lib.<lang>.{module, mkShell}    (e.g. tendril.lib.typescript.mkShell)
#
# also defines `devShells.<sys>.default`, the dev shell for working *on*
# tendril itself (formatter, lsp, debugging tools), activated via .envrc.
{
  description = "tendril: polyglot dev environment library";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # shared helpers (see `./lib/default.nix`).
      tendrilLib = import ./lib { inherit nixpkgs; };
      inherit (tendrilLib)
        forAllSystems
        mkShell
        mergeModules
        mkLanguageLib
        ;

      # registry of languages tendril knows about. adding a new language is a
      # one-line addition here, plus a `flakes/<lang>/module.nix`.
      #
      # values are module *functions* (`{ pkgs } -> module`), not modules.
      # we delay evaluation until we know which system's `pkgs` to use.
      # the same module function gets called with `aarch64-darwin` pkgs in
      # one branch, `x86_64-linux` pkgs in another, etc.
      languages = {
        typescript = import ./flakes/typescript/module.nix;
        go = import ./flakes/go/module.nix;
        nix = import ./flakes/nix/module.nix;
      };
    in
    {
      # for each supported system, expose:
      #   - one named shell per language (e.g. `devShells.<sys>.typescript`)
      #   - `default`, aliased to the nix shell: what `.envrc` activates
      #   - `full`, a polyglot shell merging every registered language
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # `builtins.mapAttrs (name: value: ...) attrset` applies the function
          # to each (name, value) pair. we ignore the name (`_`) and use the
          # value (the module function) to build a shell.
          languageShells = builtins.mapAttrs (
            _: mkModule:
            mkShell {
              inherit pkgs;
              module = mkModule { inherit pkgs; };
            }
          ) languages;
        in
        languageShells
        // {
          # `.envrc` does `use flake ./nix`, which activates `default`. the
          # nix shell (nixfmt + nil + nix-tree) is what we want for working
          # on tendril, so alias it here.
          default = languageShells.nix;

          # consumers reach the polyglot shell as `tendril.devShells.<sys>.full`.
          # each language module already composes the IDE; `mergeModules`
          # de-dupes its `packages` list so neovim appears once.
          full = mkShell {
            inherit pkgs;
            module = mergeModules (map (mkModule: mkModule { inherit pkgs; }) (builtins.attrValues languages));
          };
        }
      );

      # `lib.<lang>.{module, mkShell}` for each language.
      # consumers bring their own `pkgs`.
      lib = builtins.mapAttrs (_: mkLanguageLib) languages;

      # `nix fmt` reads this. exposed at the umbrella level so consumers
      # pinning tendril can format their nix with our chosen tool.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

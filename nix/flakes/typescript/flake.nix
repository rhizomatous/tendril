# standalone typescript flake. directly consumable via:
#   nix develop github:rhizomatous/tendril?dir=nix/flakes/typescript
#
# also re-exported by the umbrella `flake.nix` at `nix/flake.nix`, so consumers
# pinning `github:rhizomatous/tendril?dir=nix` can reach this as
# `tendril.devShells.<sys>.typescript` and `tendril.lib.typescript`.
{
  description = "tendril typescript: node 24 dev shell";

  # flakes declare their dependencies up front so they're hermetic and
  # reproducible. each input gets pinned to a specific revision in `flake.lock`
  # the first time the flake is evaluated.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # pull in the parent repo as a plain source tree so we can `import` the
    # shared `lib/` helpers and the IDE builder without duplicating either in
    # every sub-flake. `flake = false` means "don't evaluate as a flake, just
    # expose the files". this avoids circular flake evaluation and an unnecessary
    # lockfile input. the `path:../..` form works for both:
    #   - local dev: `nix develop ./nix/flakes/typescript`
    #   - published: `github:rhizomatous/tendril?dir=nix/flakes/typescript`
    # (in the published case, the whole repo is copied to the nix store, so
    # `../..` resolves to the parent within that store path.)
    tendril-root = {
      url = "path:../..";
      flake = false;
    };
  };

  # `outputs` is a function from resolved inputs to the flake's output
  # attrset. `self` is a self-reference to this flake.
  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      tendril-root,
    }:
    let
      # `tendril-root` is a path in the nix store; interpolating it as a
      # string (`"${tendril-root}/lib"`) gives the absolute path that the
      # `import` builtin needs.
      tendrilLib = import "${tendril-root}/lib" { inherit nixpkgs; };

      # `inherit (set) a b c` is sugar for `a = set.a; b = set.b; c = set.c;` —
      # pulls specific attribute names from an attrset into local scope.
      inherit (tendrilLib) forAllSystems mkLanguageLib;

      # the IDE-specific nvim builder. signature: pkgs -> configured nvim.
      tendrilNvim = import "${tendril-root}/flakes/ide/build.nix" { inherit nixvim; };

      langLib = mkLanguageLib (import ./module.nix);
    in
    {
      # `devShells.<system>.<name>` is the canonical flake output for shells
      # entered via `nix develop`. `default` is the implicit choice when no
      # name is passed to `nix develop`.
      devShells = forAllSystems (
        system:
        # `legacyPackages` is nixpkgs' convention for "the entire package set
        # as an attrset, indexed by system". the name is historical — it is
        # not deprecated.
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nvim = tendrilNvim pkgs;
        in
        {
          default = langLib.mkShell { inherit pkgs nvim; };
        }
      );

      # `lib` is a free-form, system-agnostic flake output. consumers reach
      # it as `tendril-typescript.lib.{module, mkShell}` and pass their own
      # `pkgs` and `nvim`.
      lib = langLib;
    };
}

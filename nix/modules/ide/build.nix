# build the tendril-configured nvim derivation for a given pkgs (per-system).
# pulls the declarative spec from `./nixvim.nix` and hands it to nixvim's
# `makeNixvimWithModule` builder.
#
# called from `nix/lib/default.nix`; the resulting `pkgs -> nvim` function
# is threaded through `mkLanguageLib` so every language shell gets the
# configured editor.

{ nixvim }:

pkgs:
nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
  inherit pkgs;
  module = import ./nixvim.nix;
}

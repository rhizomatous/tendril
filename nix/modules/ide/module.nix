# the ide module: the configured nvim derivation plus editor-adjacent tools
# (`git`, expected by the nvim config's gitsigns / snacks dashboard / etc.).
# composed into every tendril shell & image by `mkComposer`.
#
# nvim is built here from the declarative nixvim spec at `./nixvim.nix`.
# this used to live in a separate `build.nix`, but the split only made sense
# when the nvim derivation was an independent public export.
#
# shape: `{ nixvim } -> pkgs -> module`. takes nixvim once at lib-init time,
# then `pkgs` per-system at composition time.

{ nixvim }:

pkgs:
let
  nvim = nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
    inherit pkgs;
    module = import ./nixvim.nix;
  };
in
{
  packages = [
    nvim
    pkgs.git
  ];
}

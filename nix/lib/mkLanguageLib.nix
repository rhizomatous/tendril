# turn a language's `module` *function* (`{ pkgs, nvim } -> module`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# `mkShell` requires a `nvim` derivation. tendril builds one via
# `flakes/ide/build.nix`; consumers reach it as `tendril.lib.tendrilNvim pkgs`
# or supply their own.
#
# consumers use `lib.<lang>.mkShell { pkgs = ...; nvim = ...; }` (plus
# optional `extraPackages`/`extraEnv`/`extraShellHook`).

{ mkShell }:

mkModule: {
  module = mkModule;
  mkShell =
    {
      pkgs,
      nvim,
      extraPackages ? [ ],
      extraEnv ? { },
      extraShellHook ? "",
    }:
    mkShell {
      inherit
        pkgs
        extraPackages
        extraEnv
        extraShellHook
        ;
      module = mkModule { inherit pkgs nvim; };
    };
}

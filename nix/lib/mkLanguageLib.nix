# turn a language's `module` *function* (`{ pkgs }: { packages, env, shellHook }`)
# into the public-facing per-language lib that consumers reach as
# `tendril.lib.<lang>`.
#
# consumers use `lib.<lang>.mkShell { pkgs = ...; extraPackages = [...]; }`
# to extend the base shell without re-deriving it from scratch.

{ mkShell }:

mkModule: {
  module = mkModule;
  mkShell =
    {
      pkgs,
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
      module = mkModule { inherit pkgs; };
    };
}

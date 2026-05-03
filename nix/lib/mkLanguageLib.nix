# turn a language's `module` *function* (`{ pkgs, nvim } -> module`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# both `mkShell` and `mkDockerImage` require a `nvim` derivation. tendril
# builds one via `flakes/ide/build.nix`; consumers reach it as
# `tendril.lib.tendrilNvim pkgs` or supply their own.
#
# consumers use:
#   lib.<lang>.mkShell { pkgs; nvim; ... }       -> dev shell
#   lib.<lang>.mkDockerImage { pkgs; nvim; name } -> docker image (linux pkgs)

{ mkShell, mkDockerImage }:

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

  mkDockerImage =
    {
      pkgs,
      nvim,
      name,
      tag ? "latest",
    }:
    mkDockerImage {
      inherit pkgs name tag;
      module = mkModule { inherit pkgs nvim; };
    };
}

# turn a language's `kit` *function* (`{ pkgs } -> kit`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# the consumer-facing `mkShell` / `mkDockerImage` auto-include the tendril
# ide and agent kits. pass `withIde = false` and/or `withAgent = false`
# to opt out of either piece independently.
#
# usage:
#   lib.<lang>.mkShell { pkgs; ... }                        -> dev shell, full
#   lib.<lang>.mkShell { pkgs; withAgent = false; }         -> editor only
#   lib.<lang>.mkDockerImage { pkgs; name; }                -> docker image, full

{ mkComposer }:

let
  mkShell = import ../builders/mkShell.nix;
  mkDockerImage = import ../builders/mkDockerImage.nix;
in

langName: mkKit:
let
  # build the kit list passed to a builder. always includes the language
  # kit; conditionally includes ide and agent kits. also, tag the env with
  # the name of the tendril env this shell/image represents.
  kitsFor =
    {
      pkgs,
      withIde,
      withAgent,
    }:
    let
      composer = mkComposer pkgs;
      langKit = mkKit { inherit pkgs; };
      base = composer.compose { inherit langKit withIde withAgent; };
      suffix =
        if withIde && withAgent then
          ""
        else if withIde then
          "-editor"
        else if withAgent then
          "-agent"
        else
          "-bare";
    in
    base ++ [ { env.TENDRIL_ENV = "${langName}${suffix}"; } ];
in
{
  mkShell =
    {
      pkgs,
      withIde ? true,
      withAgent ? true,
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
      kits = kitsFor { inherit pkgs withIde withAgent; };
    };

  mkDockerImage =
    {
      pkgs,
      name,
      tag ? "latest",
      withIde ? true,
      withAgent ? true,
    }:
    mkDockerImage {
      inherit pkgs name tag;
      kits = kitsFor { inherit pkgs withIde withAgent; };
    };
}

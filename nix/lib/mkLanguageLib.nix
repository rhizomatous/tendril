# turn a language's `module` *function* (`{ pkgs } -> module`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# the consumer-facing `mkShell` / `mkDockerImage` auto-include the tendril
# ide and agent modules. pass `withIde = false` and/or `withAgent = false`
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

langName: mkModule:
let
  # build the module list passed to a builder. always includes the language
  # module; conditionally includes ide and agent modules. also, tag the env with
  # the name of the tendril env this shell/image represents.
  modulesFor =
    {
      pkgs,
      withIde,
      withAgent,
    }:
    let
      composer = mkComposer pkgs;
      langModule = mkModule { inherit pkgs; };
      base = composer.compose { inherit langModule withIde withAgent; };
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
      modules = modulesFor { inherit pkgs withIde withAgent; };
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
      modules = modulesFor { inherit pkgs withIde withAgent; };
    };
}

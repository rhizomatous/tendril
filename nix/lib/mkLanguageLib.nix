# turn a language's `module` *function* (`{ pkgs } -> module`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# the consumer-facing `mkShell` / `mkDockerImage` auto-include the tendril
# ide module (configured nvim + git). pass `withIde = false` to opt out.
#
# consumers use:
#   lib.<lang>.mkShell { pkgs; ... }              -> dev shell with ide
#   lib.<lang>.mkShell { pkgs; withIde = false; } -> language only
#   lib.<lang>.mkDockerImage { pkgs; name; }      -> docker image with ide
#   lib.<lang>.module                             -> raw `{ pkgs } -> module`

{
  mkShell,
  mkDockerImage,
  ideModule,
  tendrilNvim,
}:

mkModule:
let
  # build the module list passed to a builder. always includes the language
  # module; conditionally includes the ide module + nvim derivation.
  modulesFor =
    pkgs: withIde:
    [ (mkModule { inherit pkgs; }) ]
    ++ (
      if withIde then
        [
          (ideModule {
            inherit pkgs;
            nvim = tendrilNvim pkgs;
          })
        ]
      else
        [ ]
    );
in
{
  module = mkModule;

  mkShell =
    {
      pkgs,
      withIde ? true,
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
      modules = modulesFor pkgs withIde;
    };

  mkDockerImage =
    {
      pkgs,
      name,
      tag ? "latest",
      withIde ? true,
    }:
    mkDockerImage {
      inherit pkgs name tag;
      modules = modulesFor pkgs withIde;
    };
}

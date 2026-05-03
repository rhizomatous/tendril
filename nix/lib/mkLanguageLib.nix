# turn a language's `module` *function* (`{ pkgs } -> module`) into the
# public-facing per-language lib that consumers reach as `tendril.lib.<lang>`.
#
# the consumer-facing `mkShell` / `mkDockerImage` auto-include the tendril
# ide module (configured nvim & git). pass `withIde = false` to opt out.
#
# composition is delegated to `mkComposer`, the same helper the flake uses
# for its own outputs, so per-language and consumer-side shells stay in sync.
#
# consumers use:
#   lib.<lang>.mkShell { pkgs; ... }              -> dev shell with ide
#   lib.<lang>.mkShell { pkgs; withIde = false; } -> language only
#   lib.<lang>.mkDockerImage { pkgs; name; }      -> docker image with ide

{
  mkShell,
  mkDockerImage,
  mkComposer,
}:

mkModule:
let
  # build the module list passed to a builder. always includes the language
  # module; conditionally includes the ide module.
  modulesFor =
    pkgs: withIde:
    let
      composer = mkComposer pkgs;
      langModule = mkModule { inherit pkgs; };
    in
    if withIde then composer.withIde langModule else composer.withoutIde langModule;
in
{
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

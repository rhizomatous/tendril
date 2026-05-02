# the IDE module. takes a pre-built nvim derivation (configured via nixvim
# in `lib.tendrilNvim`) and exposes it as a shell package. composed into
# every language shell so any tendril shell has the configured editor on PATH.

{ pkgs, nvim }:
{
  packages = [ nvim ];
  env = { };
  shellHook = "";
}

# the IDE module. takes a pre-built nvim derivation (configured via nixvim
# in `lib.tendrilNvim`) and exposes it as a shell package, alongside editor-
# adjacent tools that the nvim config expects on PATH (gitsigns, snacks
# lazygit, the dashboard's git-status section all want `git`). composed into
# every language shell so any tendril shell has the configured editor on PATH.

{ pkgs, nvim }:
{
  packages = [
    nvim
    pkgs.git
  ];
  env = { };
  shellHook = "";
}

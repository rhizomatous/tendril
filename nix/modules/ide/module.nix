# the IDE module. takes a pre-built nvim derivation (configured via nixvim
# in `lib.tendrilNvim`) and exposes it as a shell package, alongside editor-
# adjacent tools that the nvim config expects on PATH (gitsigns, snacks
# lazygit, the dashboard's git-status section all want `git`).

{ pkgs, nvim }:
{
  packages = [
    nvim
    pkgs.git
  ];
  env = { };
  shellHook = "";
}

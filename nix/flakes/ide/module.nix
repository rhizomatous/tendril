# the IDE module. composed into every language shell, so any tendril shell
# has an editor on PATH.

{ pkgs }:
{
  packages = with pkgs; [ neovim ];
  env = { };
  shellHook = "";
}

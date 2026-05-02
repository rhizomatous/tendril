# the IDE module. auto-composed into every language shell built via
# `mkLanguageLib`, so any tendril shell has an editor on PATH.
#
# v1: bare neovim. growth path is configured nvim with lspconfig wired to
# our language-server packages (gopls/nil/etc.), or wholesale nixvim.

{ pkgs }:
{
  packages = with pkgs; [ neovim ];
  env = { };
  shellHook = "";
}

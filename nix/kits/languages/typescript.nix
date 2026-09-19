# The TypeScript dev environment.

{ pkgs }:
{
  packages = with pkgs; [
    nodejs_24
    typescript-language-server
    vscode-langservers-extracted
  ];
}

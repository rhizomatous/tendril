# The go dev environment.

{ pkgs }:
{
  packages = with pkgs; [
    go_1_26 # compiler and `go` command
    gopls # language server
    delve # debugger (`dlv`)
    gotools # goimports, etc.
  ];

  # `GOTOOLCHAIN=local` pins the toolchain to the Nix-provided go and
  # prevents `go.mod`'s `go <version>` directive from downloading another
  # version.
  env = {
    GOTOOLCHAIN = "local";
  };
}

# the go dev environment, expressed as a reusable `module`.

{ pkgs }: {
  # tools globally available on PATH inside the shell.
  #
  # the lsp/debugger/editor-integration tools live here rather than in a
  # per-project `tools.go` because editors expect to find them on PATH
  # and don't pin versions per-project.
  #
  # `golangci-lint` is *not* bundled — projects pin it per-repo via go.mod's
  # `tool` directive (or `tools.go`/`go run` for older projects).
  packages = with pkgs; [
    go_1_26   # compiler and `go` command
    gopls     # language server
    delve     # debugger (`dlv`)
    gotools   # goimports, etc.
  ];

  # `GOTOOLCHAIN=local` pins the toolchain to the nix-provided go and
  # prevents `go.mod`'s `go <version>` directive from triggering a silent
  # download of a different toolchain at the network layer (default since
  # go 1.21).
  env = { GOTOOLCHAIN = "local"; };

  shellHook = "";
}

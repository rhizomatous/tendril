# The Rust dev environment.

{ pkgs }:
{
  packages = with pkgs; [
    rustc # compiler
    cargo # build & package manager
    rust-analyzer # language server
    rustfmt # formatter
    clippy # linter (rust-lang standard component, ships with rustup by default)
  ];
}

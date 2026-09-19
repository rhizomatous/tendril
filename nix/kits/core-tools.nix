# Tendril's base tools kit, containing modern Unix utilities
# that every shell should have.

{ pkgs }:
{
  packages = with pkgs; [
    # Shell fundamentals
    bashInteractive
    coreutils

    # Version control & repo tooling
    git
    lefthook # Git hooks runner

    # Modern unix utilities
    bat # `cat` with syntax highlighting
    eza # `ls` with colors & git integration
    ripgrep # fast `grep`
    fzf # fuzzy finder
    fd # `find` replacement
  ];
}

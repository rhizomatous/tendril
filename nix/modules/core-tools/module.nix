# tendril's base tools module. shell fundamentals, version control, repo tooling,
# and modern unix utilities every tendril env should have.

{ pkgs }:
{
  packages = with pkgs; [
    # shell fundamentals
    bashInteractive
    coreutils

    # version control & repo tooling
    git
    lefthook # git hooks runner

    # modern unix utilities
    bat # `cat` with syntax highlighting
    eza # `ls` with colors & git integration
    ripgrep # fast `grep`
    fzf # fuzzy finder
  ];
}

# given `system -> value`, returns
#   { aarch64-darwin = value; x86_64-linux = ...; ... }
# for all supported systems.

{ nixpkgs }:

nixpkgs.lib.genAttrs [
  "aarch64-darwin"
  "x86_64-linux"
  "aarch64-linux"
]

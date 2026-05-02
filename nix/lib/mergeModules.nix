# merge a list of evaluated modules into a single combined module.
#
# - `packages`: concatenated and de-duplicated via `lib.unique`.
# - `env`: merged left-to-right with `//` (right-wins on key collision).
#   callers should make sure modules don't fight over the same env var.
# - `shellHook`: non-empty hooks joined with newlines.

{ lib }:

modules: {
  packages = lib.unique (builtins.concatLists (map (m: m.packages or [ ]) modules));
  env = builtins.foldl' (acc: m: acc // (m.env or { })) { } modules;
  shellHook = builtins.concatStringsSep "\n" (
    builtins.filter (s: s != "") (map (m: m.shellHook or "") modules)
  );
}

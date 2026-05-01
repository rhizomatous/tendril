# merge a list of evaluated modules into a single combined module.
#
# - `packages`: concatenated as-is. nix derivations dedupe at the closure
#   level, so identical packages won't bloat the store; but PATH may carry
#   duplicates if two modules pin different versions of the same tool.
# - `env`: merged left-to-right with `//` (right-wins on key collision).
#   callers building polyglot shells should make sure modules don't fight
#   over the same env var.
# - `shellHook`: non-empty hooks joined with newlines.

modules: {
  packages = builtins.concatLists (map (m: m.packages or [ ]) modules);
  env = builtins.foldl' (acc: m: acc // (m.env or { })) { } modules;
  shellHook = builtins.concatStringsSep "\n" (
    builtins.filter (s: s != "") (map (m: m.shellHook or "") modules)
  );
}

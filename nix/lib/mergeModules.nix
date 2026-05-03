# merge a list of evaluated modules into a single combined module.
#
# - `packages`: concatenated and de-duplicated via `lib.unique`.
# - `env`: merged left-to-right with `//` (later modules win on collision).
#   if two modules set the same key we emit a `lib.warn` listing the
#   colliding keys, so a clash doesn't slip through silently. consumer
#   overrides via `mkShell`'s `extraEnv` happen *after* this merge and are
#   intentional, so they don't trigger the warning.
# - `shellHook`: non-empty hooks joined with newlines.

{ lib }:

modules:
let
  envFold =
    builtins.foldl'
      (
        acc: m:
        let
          mEnv = m.env or { };
          collisions = builtins.filter (k: builtins.hasAttr k acc.env) (builtins.attrNames mEnv);
        in
        {
          env = acc.env // mEnv;
          collisions = acc.collisions ++ collisions;
        }
      )
      {
        env = { };
        collisions = [ ];
      }
      modules;

  mergedEnv =
    if envFold.collisions == [ ] then
      envFold.env
    else
      lib.warn "tendril mergeModules: env keys set by multiple modules (later wins): ${builtins.concatStringsSep ", " (lib.unique envFold.collisions)}" envFold.env;
in
{
  packages = lib.unique (builtins.concatLists (map (m: m.packages or [ ]) modules));
  env = mergedEnv;
  shellHook = builtins.concatStringsSep "\n" (
    builtins.filter (s: s != "") (map (m: m.shellHook or "") modules)
  );
}

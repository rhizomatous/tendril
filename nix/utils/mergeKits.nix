# Merge a list of evaluated kits into a single combined kit.
#
# - `packages`: concatenated and de-duplicated via `lib.unique`.
# - `env`: merged left-to-right with `//`). If two kits set the same key we emit a `lib.warn` listing the
#   colliding keys. consumer overrides via `mkShell`'s `extraEnv` happen *after* this merge and are
#   intentional, so they are excluded from the warning.
# - `shellHook`: non-empty hooks joined with newlines.

{ lib }:

kits:
let
  envFold =
    builtins.foldl'
      (
        acc: k:
        let
          kEnv = k.env or { };
          collisions = builtins.filter (key: builtins.hasAttr key acc.env) (builtins.attrNames kEnv);
        in
        {
          env = acc.env // kEnv;
          collisions = acc.collisions ++ collisions;
        }
      )
      {
        env = { };
        collisions = [ ];
      }
      kits;

  mergedEnv =
    if envFold.collisions == [ ] then
      envFold.env
    else
      lib.warn "tendril mergeKits: env keys set by multiple kits (later wins): ${builtins.concatStringsSep ", " (lib.unique envFold.collisions)}" envFold.env;
in
{
  packages = lib.unique (builtins.concatLists (map (k: k.packages or [ ]) kits));
  env = mergedEnv;
  shellHook = builtins.concatStringsSep "\n" (
    builtins.filter (s: s != "") (map (k: k.shellHook or "") kits)
  );
}

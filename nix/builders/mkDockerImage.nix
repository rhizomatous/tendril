# Build a Docker image from a list of `kit` attrsets.
#
# `shellHook` doesn't really translate to a docker image, so it's ignored
# here. Consumers wanting startup commands can pass `entrypoint`.
#
# `pkgs` must be a Linux pkgs (`x86_64-linux` or `aarch64-linux`) to create
# a usable image.

{
  pkgs,
  name,
  tag ? "latest",
  kits ? [ ],
  cmd ? null,
  workingDir ? "/workspace",
  entrypoint ? null,
}:
let
  mergeKits = import ../utils/mergeKits.nix { inherit (pkgs) lib; };
  merged = mergeKits kits;

  pathString = pkgs.lib.makeBinPath merged.packages;
  envList = (pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") merged.env) ++ [
    "PATH=${pathString}"
  ];
in
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;
  contents = merged.packages;

  # `buildLayeredImage` doesn't auto-create `WorkingDir`. Do it ourselves so
  # `docker run` doesn't fail trying to `chdir` into a missing path.
  extraCommands = ''
    mkdir -p ${pkgs.lib.removePrefix "/" workingDir}
  '';

  config = {
    Cmd = if cmd != null then cmd else [ "${pkgs.bashInteractive}/bin/bash" ];
    WorkingDir = workingDir;
    Env = envList;
  }
  // pkgs.lib.optionalAttrs (entrypoint != null) { Entrypoint = entrypoint; };
}

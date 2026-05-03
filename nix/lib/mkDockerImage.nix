# build a docker image from a `module` attrset.
#
# this is the docker-targeted parallel of `mkShell` — same module shape
# (`{ packages, env, shellHook }`), different output. `shellHook` doesn't
# really translate to a docker image (no shell entry hook concept), so it's
# ignored here; consumers wanting startup commands can pass `entrypoint`.
#
# `pkgs` must be a Linux pkgs (`x86_64-linux` or `aarch64-linux`); using
# darwin pkgs would build darwin binaries, which won't run inside the
# linux container the image describes. the umbrella's `packages.<sys>`
# output restricts itself to linux systems for this reason.
#
# adds `bashInteractive` + `coreutils` to contents so `docker run -it` lands
# in a usable shell. `PATH` is built from every package's `bin/` dir.

{
  pkgs,
  name,
  tag ? "latest",
  module,
  cmd ? null,
  workingDir ? "/workspace",
  entrypoint ? null,
}:
let
  shellPackages = with pkgs; [
    bashInteractive
    coreutils
  ];
  allPackages = (module.packages or [ ]) ++ shellPackages;

  pathString = pkgs.lib.makeBinPath allPackages;
  envList = (pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") (module.env or { })) ++ [
    "PATH=${pathString}"
  ];
in
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;
  contents = allPackages;

  # buildLayeredImage doesn't auto-create `WorkingDir`; do it ourselves so
  # `docker run` doesn't fail trying to chdir into a missing path.
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

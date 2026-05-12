# build a NixOS VM from a list of `kit` attrsets.
#
# `pkgs` must be a Linux pkgs (`x86_64-linux` or `aarch64-linux`). using
# darwin pkgs would fail to build. the umbrella's `packages.<sys>` output
# restricts itself to linux systems for this reason.
#
# returns the runnable VM script derivation (`.config.system.build.vm`).
# users invoke via `nix run .#vm-<name>` or `nix build .#vm-<name>` then
# run `./result/bin/run-tendril-<name>-vm`.

{ nixpkgs }:

{
  pkgs,
  name,
  kits ? [ ],
}:
let
  mergeKits = import ../utils/mergeKits.nix { inherit (pkgs) lib; };
  merged = mergeKits kits;

  # OS-level defaults. lives in the builder rather than a kit because it's
  # specific to this execution context (a real boot, init, login) and would
  # be meaningless to mkShell or mkDockerImage.
  baseModule =
    { ... }:
    {
      networking.hostName = "tendril-${name}";

      # a default user so the console actually lets someone log in.
      # TODO: password-by-default is a placeholder for a throwaway dev VM.
      # swap to ssh-key-only or accept a key path / user attr from the
      # caller once we figure out how consumers want to inject identity.
      users.users.tendril = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialPassword = "tendril";
      };

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "no";
      };

      # headless console: the VM runs in your terminal, no graphical window.
      virtualisation.graphics = false;

      # NixOS requires this. track whatever release nixpkgs is on so module
      # option defaults don't drift unexpectedly.
      system.stateVersion = pkgs.lib.trivial.release;
    };

  # the kit layer: packages, env vars, and shell-entry hooks from whatever
  # composition the caller passed in.
  kitModule =
    { ... }:
    {
      environment.systemPackages = merged.packages;
      environment.variables = merged.env;
      programs.bash.interactiveShellInit = merged.shellHook;
    };

  nixosConfig = nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      # qemu-vm.nix is what defines `system.build.vm` (the runnable script
      # we return), plus options like `virtualisation.graphics`. it isn't
      # in the default module list, so we import it explicitly.
      "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
      baseModule
      kitModule
    ];
  };
in
nixosConfig.config.system.build.vm

# Build a NixOS VM from a list of `kit` attrsets.
#
# `pkgs` must be a Linux pkgs (`x86_64-linux` or `aarch64-linux`). Using
# darwin pkgs would fail to build.
#
# Returns a runnable VM script derivation (`.config.system.build.vm`).
# Users can invole via `nix run .#vm` or `nix build .#vm`, then run
# `./result/bin/run-tendril-vm`.

{ nixpkgs }:

{
  pkgs,
  kits ? [ ],
}:
let
  mergeKits = import ../utils/mergeKits.nix { inherit (pkgs) lib; };
  merged = mergeKits kits;

  # OS-level defaults.
  baseModule =
    { ... }:
    {
      networking.hostName = "tendril";

      # A default user so the console actually lets the user log in.
      # TODO: password-by-default is a placeholder. swap to ssh key?
      users.users.tendril = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialPassword = "tendril";
      };

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "no";
      };

      # Headless console only
      virtualisation.graphics = false;

      # Track whatever release nixpkgs is on
      system.stateVersion = pkgs.lib.trivial.release;
    };

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
      # `qemu-vm.nix` isn't included by default
      "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
      baseModule
      kitModule
    ];
  };
in
nixosConfig.config.system.build.vm

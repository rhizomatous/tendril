# tendril's flake. exposes a dev shell, plus a matching docker image and NixOS
# VM for linux.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.default       (polyglot dev shell)
#   tendril.devShells.<sys>.ollama        (dev shell plus local AI)
#   tendril.packages.<linux-sys>.default  (docker image)
#   tendril.packages.<linux-sys>.vm       (runnable NixOS VM)
#
# also activated by the repo's own `.envrc` for working on tendril itself.
{
  description = "tendril: polyglot dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixvim, the declarative neovim config framework. used by `nix/kits/ide.nix`.
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixvim,
    }:
    let
      # helpers
      forAllSystems = import ./nix/utils/forAllSystems.nix { inherit nixpkgs; };

      # cross-cutting kit factories
      coreToolsKit = import ./nix/kits/core-tools.nix;
      ideKit = import ./nix/kits/ide.nix { inherit nixvim; };
      agentKit = import ./nix/kits/agent.nix;
      ollamaKit = import ./nix/kits/ollama.nix;

      # builders
      mkShell = import ./nix/builders/mkShell.nix;
      mkDockerImage = import ./nix/builders/mkDockerImage.nix;
      mkNixosVm = import ./nix/builders/mkNixosVm.nix { inherit nixpkgs; };

      # docker images need linux pkgs, so we can't build on MacOS right now
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;

      # Registry of language kits included in Tendril.
      languages = {
        go = import ./nix/kits/languages/go.nix;
        nix = import ./nix/kits/languages/nix.nix;
        python = import ./nix/kits/languages/python.nix;
        rust = import ./nix/kits/languages/rust.nix;
        typescript = import ./nix/kits/languages/typescript.nix;
      };

      # Evaluate each kit once per system and compose them into the Tendril env.
      kitsFor =
        pkgs:
        [ (coreToolsKit { inherit pkgs; }) ]
        ++ builtins.attrValues (builtins.mapAttrs (_: mkKit: mkKit { inherit pkgs; }) languages)
        ++ [
          (ideKit { inherit pkgs; })
          (agentKit { inherit pkgs; })
        ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          kits = kitsFor pkgs;
        in
        {
          default = mkShell {
            inherit pkgs kits;
          };

          ollama = mkShell {
            inherit pkgs;
            kits = kits ++ [ (ollamaKit { inherit pkgs; }) ];
          };
        }
      );

      # The docker image and NixOS VM parallel the dev shell. Linux only, see
      # `linuxSystems` above for why.
      packages = forLinuxSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          kits = kitsFor pkgs;
        in
        {
          default = mkDockerImage {
            inherit pkgs kits;
            name = "tendril";
          };

          vm = mkNixosVm {
            inherit pkgs kits;
          };
        }
      );

      # `nix fmt` reads this.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

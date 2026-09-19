# Tendril is a polyglot, AI-enabled, local development environment.
{
  description = "Tendril: polyglot local AI dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # used by `nix/kits/ide.nix`.
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
      # Helpers
      forAllSystems = import ./nix/utils/forAllSystems.nix { inherit nixpkgs; };

      # Tools
      coreToolsKit = import ./nix/kits/core-tools.nix;
      ideKit = import ./nix/kits/ide.nix { inherit nixvim; };
      agentKit = import ./nix/kits/agent.nix;
      ollamaKit = import ./nix/kits/ollama.nix;

      # Builders
      mkShell = import ./nix/builders/mkShell.nix;
      mkDockerImage = import ./nix/builders/mkDockerImage.nix;
      mkNixosVm = import ./nix/builders/mkNixosVm.nix { inherit nixpkgs; };

      # Docker images need Linux pkgs
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forLinuxSystems = nixpkgs.lib.genAttrs linuxSystems;

      # Languages
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

      # The Docker image and NixOS VM parallel the dev shell. Linux only.
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

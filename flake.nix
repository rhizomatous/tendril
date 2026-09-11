# tendril's flake. exposes per-language dev shells, polyglot shells,
# matching docker images, and matching NixOS VMs for linux.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>             (dev shell for a language)
#   tendril.devShells.<sys>.polyglot           (every language at once)
#   tendril.devShells.<sys>.default            (alias for polyglot)
#   tendril.packages.<linux-sys>.<lang>        (docker image named `tendril-<lang>`)
#   tendril.packages.<linux-sys>.polyglot      (polyglot docker image)
#   tendril.packages.<linux-sys>.vm-<lang>     (runnable NixOS VM script)
#   tendril.packages.<linux-sys>.vm-polyglot   (polyglot NixOS VM)
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

      # registry of languages tendril knows about. adding a new language is a
      # one-line addition here, plus a `nix/kits/languages/<lang>.nix`.
      languages = {
        go = import ./nix/kits/languages/go.nix;
        nix = import ./nix/kits/languages/nix.nix;
        python = import ./nix/kits/languages/python.nix;
        rust = import ./nix/kits/languages/rust.nix;
        typescript = import ./nix/kits/languages/typescript.nix;
      };

      # Per-system, evaluate each kit once and return one full environment per
      # language plus the polyglot environment. Every environment contains
      # core tools, its language kit(s), the configured editor, and opencode.
      kitsFor =
        pkgs:
        let
          coreTools = coreToolsKit { inherit pkgs; };
          ide = ideKit { inherit pkgs; };
          agent = agentKit { inherit pkgs; };
          languageKits = builtins.mapAttrs (_: mkKit: mkKit { inherit pkgs; }) languages;
          langs = builtins.attrValues languageKits;
          compose =
            langKits:
            [ coreTools ]
            ++ langKits
            ++ [
              ide
              agent
            ];
        in
        builtins.mapAttrs (_: langKit: compose [ langKit ]) languageKits // { polyglot = compose langs; };

      # produce the per-language outputs keyed by system. `build` is called
      # as `build { pkgs, name, kits }` for each entry; callers ignore
      # `name` (devShells) or use it for naming (packages).
      #
      # `namePrefix` lets callers occupy a distinct namespace within the
      # same output attrset. docker images at `packages.<sys>.<lang>`
      # and VMs at `packages.<sys>.vm-<lang>` both flow through here.
      mkPerLanguageOutputs =
        {
          genAttrsForSystems,
          build,
          namePrefix ? "",
        }:
        genAttrsForSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            kits = kitsFor pkgs;
          in
          nixpkgs.lib.mapAttrs' (
            baseName: kitList:
            let
              name = "${namePrefix}${baseName}";
            in
            {
              inherit name;
              value = build {
                inherit pkgs name;
                # tag every output with `TENDRIL_ENV=<name>` so a consumer can tell
                # programmatically which tendril env they're sitting in.
                kits = kitList ++ [ { env.TENDRIL_ENV = name; } ];
              };
            }
          ) kits
        );
    in
    {
      # For each supported system, one named shell per language plus polyglot.
      # `default` aliases the polyglot shell.
      devShells =
        let
          base = mkPerLanguageOutputs {
            genAttrsForSystems = forAllSystems;
            build =
              {
                pkgs,
                kits,
                ...
              }:
              mkShell { inherit pkgs kits; };
          };
        in
        builtins.mapAttrs (_: shells: shells // { default = shells.polyglot; }) base;

      # docker images and NixOS VMs parallel to the dev shells.
      # linux only, see `linuxSystems` above for why.
      packages =
        let
          dockerImages = mkPerLanguageOutputs {
            genAttrsForSystems = forLinuxSystems;
            build =
              {
                pkgs,
                name,
                kits,
              }:
              mkDockerImage {
                inherit pkgs kits;
                name = "tendril-${name}";
              };
          };
          vms = mkPerLanguageOutputs {
            genAttrsForSystems = forLinuxSystems;
            namePrefix = "vm-";
            build =
              {
                pkgs,
                name,
                kits,
              }:
              mkNixosVm { inherit pkgs name kits; };
          };
        in
        forLinuxSystems (system: dockerImages.${system} // vms.${system});

      # `nix fmt` reads this.
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}

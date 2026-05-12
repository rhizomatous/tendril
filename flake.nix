# tendril's flake. exposes per-language dev shells, polyglot shells,
# matching docker images, and matching NixOS VMs for linux.
#
# consumers pin a single input:
#   inputs.tendril.url = "github:rhizomatous/tendril";
# and reach everything via:
#   tendril.devShells.<sys>.<lang>-{ci,agent,ide}            (base | base+opencode | everything)
#   tendril.devShells.<sys>.polyglot-{ci,agent,ide}          (every language at once, three flavours)
#   tendril.devShells.<sys>.default                          (alias for polyglot-ide)
#   tendril.packages.<linux-sys>.<lang>-{ci,agent,ide}       (pre-built docker images, named `tendril-<lang>-<flavour>`)
#   tendril.packages.<linux-sys>.polyglot-{ci,agent,ide}     (polyglot docker images, named `tendril-polyglot-<flavour>`)
#   tendril.packages.<linux-sys>.vm-<lang>-{ci,agent,ide}    (runnable NixOS VM scripts, hostname `tendril-vm-<lang>-<flavour>`)
#   tendril.packages.<linux-sys>.vm-polyglot-{ci,agent,ide}  (polyglot NixOS VMs)
#
# also activated by the repo's own `.envrc` for working on tendril itself.
{
  description = "tendril: polyglot dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixvim, the declarative neovim config framework. used by `nix/kits/ide.nix`
    # to construct the editor that's composed into ide-flavoured shells.
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
      mkComposer = import ./nix/utils/mkComposer.nix { inherit nixvim; };

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

      # per-system, evaluate every language kit and resolve the
      # cross-cutting kits once (via `mkComposer`). returns a flat attrset
      # keyed by output name, where each value is the kit list for that
      # output. three flavours per language, plus the polyglot variants:
      #   <lang>-ci       core + lang                (base only)
      #   <lang>-agent    core + lang + agent        (base + opencode)
      #   <lang>-ide      core + lang + ide + agent  (everything)
      #   polyglot-...    polyglot variants of the above
      kitsFor =
        pkgs:
        let
          composer = mkComposer pkgs;
          languageKits = builtins.mapAttrs (_: mkKit: mkKit { inherit pkgs; }) languages;
          langs = builtins.attrValues languageKits;
          # render one flavour across every language (plus the polyglot variant).
          flavour =
            {
              suffix,
              withIde,
              withAgent,
            }:
            let
              composeWith = langKits: composer.compose { inherit langKits withIde withAgent; };
              perLanguage = nixpkgs.lib.mapAttrs' (name: lk: {
                name = "${name}${suffix}";
                value = composeWith [ lk ];
              }) languageKits;
              polyglot = {
                "polyglot${suffix}" = composeWith langs;
              };
            in
            perLanguage // polyglot;
        in
        flavour {
          suffix = "-ci";
          withIde = false;
          withAgent = false;
        }
        // flavour {
          suffix = "-agent";
          withIde = false;
          withAgent = true;
        }
        // flavour {
          suffix = "-ide";
          withIde = true;
          withAgent = true;
        };

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
      # for each supported system, one named shell per language flavour plus
      # the polyglot variants. `default` aliases the full polyglot-ide shell.
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
        builtins.mapAttrs (_: shells: shells // { default = shells.polyglot-ide; }) base;

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

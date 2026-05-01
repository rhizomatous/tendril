# tendril: plan

a polyglot **dev environment library**, distributed as Nix flakes. other projects pull tendril in and consume language-specific dev shells (and, later, container images / VMs) without each project re-deriving toolchain setup. a single source of truth will drive all environments

## goals

- expose per-language flakes that downstream projects can pin (e.g. `inputs.tendril-go.url = "github:rhizomatous/tendril?dir=nix/flakes/go"`).
- keep the *globally installed* surface minimal: only tools that genuinely cannot live in a project's `package.json` / `go.mod`.
- structure each language as a reusable **module** (a package set + env + hooks) so the same module can drive a `devShell` today and a `dockerTools` image or NixOS module tomorrow.
- cross-platform from day one: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`.
- stay extensible: adding a new language is a new directory under `nix/flakes/`; adding a new build target (Docker, OCI, NixOS VM, nixos-generators) is a new builder under `nix/lib/`.

## non-goals (for now)

- tendril does **not** scaffold projects, control how shells are entered, or own per-project tooling (linters, formatters, test runners). Those live in the consumer project.
- no container/VM builders in v1, but the abstraction must not preclude them.
- no binary cache / Cachix setup yet.

## repository layout

```
tendril/
├── README.md
├── .gitignore
├── .envrc                       # `use flake ./nix` — for tendril's own dev only
├── docs/
│   └── PLAN.md                  # this file
├── .github/workflows/ci.yml
└── nix/
    ├── flake.nix                # umbrella flake: aggregates per-language outputs
    ├── flake.lock
    ├── flakes/
    │   ├── typescript/
    │   │   ├── flake.nix        # standalone TS flake (consumable directly)
    │   │   └── module.nix       # { packages, env, shellHook } — the reusable unit
    │   └── go/
    │       ├── flake.nix
    │       └── module.nix
    └── lib/
        ├── default.nix          # re-exports
        ├── forAllSystems.nix    # tiny helper: genAttrs over supported systems
        ├── mkShell.nix          # module → devShell (the only builder in v1)
        └── mkLanguageLib.nix    # module → { module, mkShell } public-api adapter
```

rationale: each language directory is self-contained and consumable as its own flake (via the `?dir=` flake-ref subpath). the umbrella at `nix/flake.nix` re-exports everything for consumers who want one input. all nix machinery lives under `nix/` to keep the repo root focused on docs/CI/direnv.

## the module abstraction

each language exposes a plain attrset describing its toolchain:

```nix
# nix/flakes/go/module.nix
{ pkgs }: {
  packages = with pkgs; [ go_1_26 gopls delve gotools ];
  env = { GOTOOLCHAIN = "local"; };
  shellHook = "";
}
```

this is the unit of reuse. builders are functions `module → derivation`:

- `lib.mkShell` → `pkgs.mkShell` (v1)
- `lib.mkDockerImage` → `pkgs.dockerTools.buildLayeredImage` (later)
- `lib.mkNixosModule` → `{ environment.systemPackages = module.packages; ... }` (later)
- `lib.mkVMImage` via `nixos-generators` (later)

adding a new builder never requires touching language modules; adding a new language never requires touching builders.

## per-language flake outputs

each `flakes/<lang>/flake.nix` exposes:

- `devShells.<system>.default` — directly consumable: `nix develop github:rhizomatous/tendril?dir=nix/flakes/go`
- `lib.module` — the raw module attrset (consumers compose with their own packages)
- `lib.mkShell { extraPackages ? [], extraEnv ? {} }` — a builder that lets consumers extend the base shell without re-deriving it

## umbrella flake outputs

the root `flake.nix` re-exports:

- `devShells.<system>.typescript` and `devShells.<system>.go`
- `lib.typescript` and `lib.go` (each containing `module`, `mkShell`)
- (future) a combined `polyglot` shell

## per-language specifics

### TypeScript (`nix/flakes/typescript/`)

globally installed (in the flake):
- `nodejs_24` — Node 24 LTS (Active LTS through Apr 2027, maintenance through Apr 2028). includes `npm` and `corepack`.

not bundled (consumer's `package.json` owns these):
- `typescript`, `eslint`, `prettier`, `vitest`, `ts-node`, etc.

### Go (`nix/flakes/go/`)

globally installed:
- `go_1_26` — Go 1.26.x compiler and `go` command.
- `gopls` — language server (editors expect it on `PATH`).
- `delve` — debugger (same reason).
- `gotools` — `goimports`, etc. (editor integrations).

not bundled:
- `golangci-lint` — pinnable per-project via the `tool` directive in `go.mod` (Go 1.24+), or `tools.go`/`go run` for older projects.

## platform support

```nix
systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
```

`forAllSystems` helper wraps `nixpkgs.lib.genAttrs systems`. vanilla flakes — no `flake-utils` / `flake-parts` dependency in v1.

## consumer usage examples

### pin one language

```nix
{
  inputs.tendril-go.url = "github:rhizomatous/tendril?dir=nix/flakes/go";
  outputs = { self, nixpkgs, tendril-go, ... }: {
    devShells.aarch64-darwin.default = tendril-go.devShells.aarch64-darwin.default;
  };
}
```

### pin umbrella, extend a shell

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril?dir=nix";
  outputs = { self, nixpkgs, tendril, ... }: let
    pkgs = import nixpkgs { system = "aarch64-darwin"; };
  in {
    devShells.aarch64-darwin.default = tendril.lib.go.mkShell {
      inherit pkgs;
      extraPackages = [ pkgs.golangci-lint pkgs.protobuf ];
    };
  };
}
```

### direnv (consumer side)

```bash
# .envrc in the consumer repo
use flake github:rhizomatous/tendril?dir=nix/flakes/typescript
```

## tendril's own dev setup

- `.envrc` with `use flake ./nix` so working on tendril auto-activates a shell containing `nixfmt`, `nil` LSP, and `nix-tree` for debugging closures.
- each `nix/flakes/<lang>/` is independently testable: `nix develop ./nix/flakes/go` should drop you into a working Go env with no umbrella involvement.

## phased delivery

**Phase 1 — skeleton & TS**
1. initialize `tendril/` as a git repo, add `.gitignore`, README stub.
2. write `nix/lib/forAllSystems.nix` and `nix/lib/mkShell.nix`.
3. implement `nix/flakes/typescript/{flake.nix,module.nix}`.
4. wire up the umbrella `nix/flake.nix` to re-export TS.
5. smoke test: `nix develop ./nix/flakes/typescript`, `node --version`, `npm init -y`.
6. `.envrc` for tendril dev.

**Phase 2 — Go**
1. implement `nix/flakes/go/{flake.nix,module.nix}`.
2. add Go to umbrella outputs.
3. smoke test on macOS and Linux (CI or manual).

**Phase 3 — solidify**
1. ~~README with consumer examples.~~ — done.
2. ~~decide on formatter~~ — settled: `nixfmt` (RFC 166 standard); also exposed as `formatter.<sys>` so `nix fmt` works for consumers.
3. ~~optional: GitHub Actions running `nix flake check` on each push.~~ — done (`.github/workflows/ci.yml`, matrix over ubuntu/macos).

**Phase 4+ — build targets (deferred, but designed for)**
- `nix/lib/mkDockerImage.nix` using `pkgs.dockerTools.buildLayeredImage`.
- `nix/lib/mkNixosModule.nix`.
- `nix/lib/mkVMImage.nix` via `nixos-generators`.
- each is a new function over the existing module attrset; no language flake needs to change.

## open decisions (pick later)

- whether to publish a `polyglot` umbrella shell that includes every language at once, or leave composition to consumers.
- whether `golangci-lint` belongs in the base Go module after we get real usage.
- binary cache strategy if CI build times become annoying (Cachix vs self-hosted).

## risks / things to watch

- `?dir=` subpath flake refs are well-supported but consumers on very old Nix may hit edge cases — document a minimum Nix version (≥ 2.19 is safe).
- cross-platform parity: macOS and Linux nixpkgs sometimes diverge on tool availability (e.g. `delve` packaging quirks). Catch via `nix flake check` across all four systems.
- module abstraction must stay simple. If we find ourselves needing conditional logic inside `module.nix`, that's a smell — push variation into the builder layer instead.

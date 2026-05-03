# tendril: plan

a polyglot **dev environment library**, distributed as a Nix flake. other projects pull tendril in and consume language-specific dev shells (and, later, container images / VMs) without each project re-deriving toolchain setup. a single source of truth will drive all environments

## goals

- expose per-language dev shells consumers can pin via a single flake input (`inputs.tendril.url = "github:rhizomatous/tendril"`).
- keep the *globally installed* surface minimal: only tools that genuinely cannot live in a project's `package.json` / `go.mod`.
- structure each language as a reusable **module** (a package set + env + hooks) so the same module can drive a `devShell` today and a `dockerTools` image or NixOS module tomorrow.
- cross-platform from day one: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`.
- stay extensible: adding a new language is a new directory under `nix/modules/`; adding a new build target (Docker, OCI, NixOS VM, nixos-generators) is a new builder under `nix/lib/`.

## non-goals (for now)

- tendril does **not** scaffold projects, control how shells are entered, or own per-project tooling (linters, formatters, test runners). Those live in the consumer project.
- no container/VM builders in v1, but the abstraction must not preclude them.
- no binary cache / Cachix setup yet.

## repository layout

```
tendril/
├── README.md
├── .gitignore
├── .envrc                       # `use flake` — for tendril's own dev only
├── flake.nix                    # the sole flake. exposes per-lang shells, polyglot default, lib, docker images
├── flake.lock
├── docs/
│   └── PLAN.md                  # this file
├── .github/workflows/ci.yml
└── nix/
    ├── modules/                 # the language + ide modules consumed by the flake
    │   ├── typescript/module.nix
    │   ├── go/module.nix
    │   ├── nix/module.nix
    │   └── ide/
    │       ├── module.nix       # `{ nixvim } -> pkgs -> module` for nvim + git, composed into every shell at the builder layer
    │       └── nixvim.nix       # the declarative nvim config
    └── lib/
        ├── default.nix          # composition root: wires nixpkgs + nixvim into the helpers
        ├── forAllSystems.nix    # tiny helper: genAttrs over supported systems
        ├── mkShell.nix          # modules list → devShell
        ├── mergeModules.nix     # combine N modules into one
        ├── mkDockerImage.nix    # modules list → docker image (linux only)
        ├── mkComposer.nix       # pkgs → { ide, withIde, withoutIde }; sole source of language+ide composition
        └── mkLanguageLib.nix    # mkModule → { mkShell, mkDockerImage } public-api adapter
```

rationale: one flake means one lockfile, one place to bump pins, no drift between "the standalone go flake" and "the umbrella's go shell." the per-language directories under `modules/` hold pure language modules; ide composition happens at the builder layer (`mkLanguageLib`), not inside each module.

## the module abstraction

each language exposes a plain attrset describing its toolchain:

```nix
# nix/modules/go/module.nix
{ pkgs }: {
  packages = with pkgs; [ go_1_26 gopls delve gotools ];
  env = { GOTOOLCHAIN = "local"; };
}
```

this is the unit of reuse. builders are functions `modules → derivation`:

- `lib.mkShell` → `pkgs.mkShell` (v1)
- `lib.mkDockerImage` → `pkgs.dockerTools.buildLayeredImage` (v1, linux only)
- `lib.mkNixosModule` → `{ environment.systemPackages = merged.packages; ... }` (later)
- `lib.mkVMImage` via `nixos-generators` (later)

builders take a *list* of modules and merge them via `mergeModules`. composition (e.g. "language + ide") is done at the call site by passing both modules in the list — nothing inside a language module knows about ide.

adding a new builder never requires touching language modules; adding a new language never requires touching builders.

## flake outputs

the sole flake at `flake.nix` exposes:

- `devShells.<sys>.<lang>` — per-language shells, each with the ide module composed in
- `devShells.<sys>.default` — polyglot shell with every language + ide
- `packages.<linux-sys>.<lang>` and `packages.<linux-sys>.default` — docker images, parallel to the shells (linux only — darwin pkgs would build broken images)
- `lib.<lang>.{mkShell, mkDockerImage}` — function-form of the per-language outputs, accepting `extraPackages` / `extraEnv` / `extraShellHook` for project-specific layering. both auto-include the ide module; pass `withIde = false` to opt out
- `formatter.<sys>` — `nixfmt`, so `nix fmt` works for consumers

## per-language specifics

### TypeScript (`nix/modules/typescript/`)

globally installed (in the flake):
- `nodejs_24` — Node 24 LTS (Active LTS through Apr 2027, maintenance through Apr 2028). includes `npm` and `corepack`.

also bundled:
- `typescript-language-server` — auto-attached by tendril's nvim.

not bundled (consumer's `package.json` owns these):
- `typescript`, `eslint`, `prettier`, `vitest`, `ts-node`, etc.

### Go (`nix/modules/go/`)

globally installed:
- `go_1_26` — Go 1.26.x compiler and `go` command.
- `gopls` — language server (auto-attached by tendril's nvim, also expected by other editors on `PATH`).
- `delve` — debugger.
- `gotools` — `goimports`, etc.

not bundled:
- `golangci-lint` — pinnable per-project via the `tool` directive in `go.mod` (Go 1.24+), or `tools.go`/`go run` for older projects.

### Nix (`nix/modules/nix/`)

globally installed:
- `nixfmt` — formatter (RFC 166 standard).
- `nil` — language server.
- `nix-tree` — interactive closure inspector.

not bundled:
- `statix`, `deadnix`, etc. — pinnable per-project as needed.

consumers reach the nix tooling as `tendril.devShells.<sys>.nix`. tendril's own `.envrc` activates the polyglot `default` shell (which includes nix), so this set is on PATH whenever you're working on the repo.

### IDE (`nix/modules/ide/`)

cross-cutting module — not a language. composed into every language shell at the builder layer (`mkLanguageLib`) so entering any tendril shell gives you the configured nvim on PATH.

built via [nixvim](https://nix-community.github.io/nixvim/) — the declarative config lives at `nix/modules/ide/nixvim.nix`. plugin set:

- **snacks.nvim** (folke) — bundled QoL: dashboard, picker, notifier, indent guides, scope, statuscolumn, terminal.
- **blink.cmp** — rust-backed completion.
- **nvim-treesitter** — syntax highlighting and indent.
- **lspconfig** with auto-attach for `gopls` (Go), `nil_ls` (Nix), `ts_ls` (TypeScript). servers only attach when their binary is on PATH — `gopls` won't fire in the typescript shell.
- **lualine, gitsigns, nvim-autopairs, ts-autotag, bufferline, which-key, web-devicons** — standard kit.
- **conform.nvim** — format-on-save (nixfmt / gofmt+goimports / prettier).
- **mini.nvim** — surround, comment, ai textobjects.
- **dracula** colorscheme.

`nvim` is built once per system in `lib.tendrilNvim` (a function `pkgs -> nvim derivation`) and threaded into the ide module by the builder layer. the ide module itself takes `{ pkgs, nvim }` and contributes `[ nvim pkgs.git ]` plus nothing else — it's intentionally tiny so the composition story stays clear.

## platform support

```nix
systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
```

`forAllSystems` helper wraps `nixpkgs.lib.genAttrs systems`. vanilla flakes — no `flake-utils` / `flake-parts` dependency in v1.

## consumer usage examples

### pin one language

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril";
  outputs = { self, nixpkgs, tendril, ... }: {
    devShells.aarch64-darwin.default = tendril.devShells.aarch64-darwin.go;
  };
}
```

### extend a shell

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril";
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
use flake github:rhizomatous/tendril#typescript
```

## tendril's own dev setup

- `.envrc` with `use flake` so working on tendril auto-activates the polyglot `default` shell — every language's toolchain plus the IDE module, since tendril is itself a polyglot dev env library.
- per-language verification: `nix develop .#go` drops you into the standalone Go shell.

## phased delivery

**Phase 1 — skeleton & TS**
1. initialize `tendril/` as a git repo, add `.gitignore`, README stub.
2. write `nix/lib/forAllSystems.nix` and `nix/lib/mkShell.nix`.
3. implement `nix/modules/typescript/module.nix`.
4. wire up `flake.nix` to expose TS.
5. smoke test: `nix develop .#typescript`, `node --version`, `npm init -y`.
6. `.envrc` for tendril dev.

**Phase 2 — Go**
1. implement `nix/modules/go/module.nix`.
2. add Go to umbrella's language registry.
3. smoke test on macOS and Linux (CI or manual).

**Phase 3 — solidify**
1. ~~README with consumer examples.~~ — done.
2. ~~decide on formatter~~ — settled: `nixfmt` (RFC 166 standard); also exposed as `formatter.<sys>` so `nix fmt` works for consumers.
3. ~~optional: GitHub Actions running `nix flake check` on each push.~~ — done (`.github/workflows/ci.yml`, matrix over ubuntu/macos).

**Phase 4 — build targets**
- ~~`nix/lib/mkDockerImage.nix` using `pkgs.dockerTools.buildLayeredImage`~~ — done. `mkLanguageLib` exposes `mkDockerImage` alongside `mkShell`. the umbrella exposes pre-built images at `packages.<linux-sys>.<lang>` (`x86_64-linux`/`aarch64-linux` only — darwin pkgs would build broken images). macos local builds need a linux builder (Determinate Nix's native one, `nix-darwin`'s `linux-builder`, or a remote builder).
- `nix/lib/mkNixosModule.nix` — deferred.
- `nix/lib/mkVMImage.nix` via `nixos-generators` — deferred.
- each is a new function over the existing module attrset; no language module needs to change.

## open decisions (pick later)

- ~~whether to publish a `polyglot` umbrella shell~~ — settled: `devShells.<sys>.default` merges every language module into one shell.
- whether `golangci-lint` belongs in the base Go module after we get real usage.
- binary cache strategy if CI build times become annoying (Cachix vs self-hosted).

## risks / things to watch

- cross-platform parity: macOS and Linux nixpkgs sometimes diverge on tool availability (e.g. `delve` packaging quirks). Catch via `nix flake check` across all four systems (currently CI only matrices ubuntu + macos hosts; consider `--all-systems` for eval coverage of the missing pair).
- module abstraction must stay simple. If we find ourselves needing conditional logic inside `module.nix`, that's a smell — push variation into the builder layer instead.

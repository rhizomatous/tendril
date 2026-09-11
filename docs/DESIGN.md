# tendril: design

## tendril's north star

a polyglot cross-platform dev environment, distributed as a Nix flake. users pin `tendril` once to get standardized per-language dev shells and docker images from a single source of truth. this makes it easy to "grab-and-go" a batteries-included dev env for any supported language, anywhere you need it. tendril is easier to use than standing up a Nix config from scratch, allowing the user to gain the benefits of hermetic builds and environment standardization without the complexity of DIYing it.

## what tendril is (and isn't)

**is:**

- a Nix flake
- a single source of truth for language toolchains (compiler, language server, debugger, formatter), core tools (CLI utils, git) an editor (nvim), and an agent (opencode), all composable.
- per-language dev shells, plus polyglot shells that bundle every language at once.
- matching docker images parallel to every shell.

**isn't:**

- a per-project tooling pin. linters, formatters, & test runners belong in the user's own repo, following the idioms of their language and project.

## structure

```
tendril/
├── flake.nix               # the sole flake, exposes all user-facing surfaces for consumption
└── nix/
    ├── builders/           # tools to build tendril environments (dev shells, docker images)
    ├── kits/               # single source of truth for all packages
    │   ├── core-tools.nix  # basic CLI tools (shell fundamentals, git, lefthook, modern unix utilities)
    │   ├── agent.nix       # AI agent tools (opencode)
    │   ├── ide.nix         # editor tools (nvim & its config)
    │   └── languages/      # per-language toolchains
    │       ├── go.nix
    │       ├── nix.nix
    │       ├── python.nix
    │       ├── rust.nix
    │       └── typescript.nix
    └── utils/              # internal helpers
```

## environments

an **environment** is a fully-functioning tendril derivation. each environment is constructed by feeding some **kits** into a **builder**.

environments come in multiple languages, currently six*:
- `go`
- `nix`
- `python`
- `rust`
- `typescript`
- `polyglot` *(not really _a_ language, just all of the languages, but close 'nuff)

each language has one full environment containing core tools, its language
toolchain, opencode, and the configured nvim. `polyglot` has the same shape but
includes every language toolchain.

each environment can be run in any of the execution contexts tendril supports. currently, that is:
- Nix dev shells
- containers
- NixOS VMs

each environment is tagged with `TENDRIL_ENV=<name>` (e.g. `go`, `polyglot`, or
`vm-go`) so any shell or script can introspect which tendril env it's sitting
in.

## kits

every reusable unit in tendril is a **kit**, a plain attrset of shape:

```nix
{ packages = [...]; env = { ... }; shellHook = "..."; }
```

a kit file is a function `{ pkgs } -> kit`. a simple language kit looks like:

```nix
# nix/kits/languages/go.nix
{ pkgs }: {
  packages = with pkgs; [ go_1_26 gopls delve gotools ];
  env = { GOTOOLCHAIN = "local"; };
}
```

kits are fully agnostic to which system they will run on, which builder will consume them, and which other kits they'll be composed with. when tendril needs to handle these things, the variation goes into the builder layer instead.


### languages

languages are a slightly special type of kit. the core of tendril, after all, is to provide development environments! so every tendril environment includes at least one language, and there is bespoke logic to wire languages up to the rest of the build stuff.

| language   | bundled                                | rationale                                                                  |
| ---------- | -------------------------------------- | -------------------------------------------------------------------------- |
| typescript | `nodejs_24`, `typescript-language-server` | node 24 LTS through apr 2028. lsp on PATH so nvim's `ts_ls` finds it.   |
| go         | `go_1_26`, `gopls`, `delve`, `gotools` | lsp/debugger expected on PATH; `GOTOOLCHAIN=local` blocks silent toolchain downloads. |
| nix        | `nixfmt`, `nil`, `nix-tree`            | RFC 166 formatter; lsp; closure inspector for debugging.                   |
| python     | `python314`, `uv`, `pyright`, `ruff`   | uv for env/dep management; pyright for lsp; ruff for format.               |
| rust       | `rustc`, `cargo`, `rust-analyzer`, `rustfmt`, `clippy` | standard rust-lang toolchain, matching `rustup`'s default install. lsp & formatter on PATH. |

what's *not* bundled: things like `eslint`, `prettier`, `vitest`, `golangci-lint`, `statix`, `deadnix`. those are pinnable per-project (in `package.json`, `go.mod`'s `tool` directive, etc.) and don't belong in a shared base.

[`flake.nix`](../flake.nix) holds a language registry:

```nix
languages = {
  go = import ./nix/kits/languages/go.nix;
  nix = import ./nix/kits/languages/nix.nix;
  python = import ./nix/kits/languages/python.nix;
  rust = import ./nix/kits/languages/rust.nix;
  typescript = import ./nix/kits/languages/typescript.nix;
};
```

adding a language is one line here plus a `nix/kits/languages/<lang>.nix`.

### core-tools

as a baseline, tendril provides a modern set of ergonomic  CLI tools like `eza`, `ripgrep`, `fzf`, `fd` in all environments.

### ide

the `ide` kit is a preconfigured batteries-included neovim. users don't _need_ to use it, but if they do, they'll drop in to a fully-functional IDE, that's available anywhere a CLI is, properly wired to the rest of the env. nixvim is used to configure a `snacks.nvim`-based setup.

lspconfig is set up with auto-attach for for all languages tendril knows about. lsp servers will autoattach when their binary is on PATH. this means you can, if for some reason you need to, attach an LSP than is not installed via Nix.

## builders

a **builder** is a functions `[ kits ] -> derivation` that construct a tendril environment with the given set of kits.

- `mkShell` wraps `pkgs.mkShell`.
- `mkDockerImage` wraps `pkgs.dockerTools.buildLayeredImage`.
- `mkNixosVm` wraps `nixpkgs.lib.nixosSystem`, returning a runnable VM script.

builders must handle merging kits. that's because a complete tendril environment is constructed of several kits composed together. the composition is determined at the callsite. as a result, builders are isolated and modular. we can add a new builder without touching the language kits, or add a new language without fiddling with builders.

each builder maps the kit into its target's idiom:

| kit field   | mkShell             | mkDockerImage         | mkNixosVm                            |
| ----------- | ------------------- | --------------------- | ------------------------------------ |
| `packages`  | shell PATH          | image `contents`      | `environment.systemPackages`         |
| `env`       | shell env vars      | container `Env`       | `environment.variables`              |
| `shellHook` | bash on shell entry | dropped (TODO)        | `programs.bash.interactiveShellInit` |

## composition

the flake evaluates the `core-tools`, `ide`, and `agent` kits once per system.
each language environment is the direct composition:

```nix
[ coreTools languageKit ide agent ]
```

the polyglot environment replaces `languageKit` with all language kits. the
same composed kit lists feed every execution context, keeping dev shells,
containers, and VMs consistent without a matrix of optional features.

## flake outputs

```
devShells.<sys>.<lang>           # per-language shell
devShells.<sys>.polyglot         # shell with every language
devShells.<sys>.default          # alias for polyglot
packages.<linux-sys>.<lang>      # docker image
packages.<linux-sys>.polyglot    # polyglot docker image
packages.<linux-sys>.vm-<lang>   # NixOS VM script
packages.<linux-sys>.vm-polyglot # polyglot NixOS VM
formatter.<sys>                  # nixfmt, so `nix fmt` works
```

generation is mechanical. when a language is added, every output (shell,
docker image, and VM) follows automatically.

## platform support

```nix
systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
```

however, containers and NixOS VMs are linux-only. `pkgs.dockerTools.buildLayeredImage` will happily run on darwin pkgs, but produces an image whose contents are darwin binaries, which can't execute inside a linux container. the NixOS VM builder likewise will not cooperate. the flake restricts `packages.*` to `x86_64-linux` and `aarch64-linux` to make this fail at evaluation rather than at runtime.

building those images on a darwin host therefore needs a linux builder.

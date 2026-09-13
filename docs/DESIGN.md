# tendril: design

## tendril's north star

a polyglot cross-platform dev environment, distributed as a Nix flake. users pin `tendril` once to get a standardized dev shell and docker image from a single source of truth. this makes it easy to "grab-and-go" a batteries-included dev env with every supported language, anywhere you need it. tendril is easier to use than standing up a Nix config from scratch, allowing the user to gain the benefits of hermetic builds and environment standardization without the complexity of DIYing it.

## what tendril is (and isn't)

**is:**

- a Nix flake
- a single source of truth for language toolchains (compiler, language server, debugger, formatter), core tools (CLI utils, git) an editor (nvim), and an agent (opencode), all composable.
- a base environment that bundles every supported language.
- an additive local-AI dev shell with Ollama and small coding models.
- a matching docker image and NixOS VM.

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
    │   ├── ollama.nix      # optional local-AI service, models, and OpenCode wiring
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

tendril's base environment contains core tools, every language toolchain,
opencode, and the configured nvim. the `ollama` dev-shell variant adds the
local-AI kit to that complete base; it is not a reduced or standalone shell.

the environment can be run in any of the execution contexts tendril supports. currently, that is:
- Nix dev shells
- containers
- NixOS VMs

the Ollama variant is intentionally dev-shell-only. local model state and
long-running inference services do not fit the reproducible container and VM
outputs, which continue to use exactly the base kit list.

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

languages are a slightly special type of kit. each remains isolated in its own
file so its toolchain stays easy to understand and update, while the environment
composes all of them together.

| language   | bundled                                | rationale                                                                  |
| ---------- | -------------------------------------- | -------------------------------------------------------------------------- |
| typescript | `nodejs_24`, `typescript-language-server`, `vscode-langservers-extracted` | node 24 LTS through apr 2028. |
| go         | `go_1_26`, `gopls`, `delve`, `gotools` | lsp/debugger expected on PATH; `GOTOOLCHAIN=local` blocks silent toolchain downloads. |
| nix        | `nixfmt`, `nil`, `nix-tree`            | RFC 166 formatter; lsp; closure inspector for debugging.                   |
| python     | `python314`, `uv`, `pyright`, `ruff`   | uv for env/dep management; pyright for lsp; ruff for format.               |
| rust       | `rustc`, `cargo`, `rust-analyzer`, `rustfmt`, `clippy` | standard rust-lang toolchain, matching `rustup`'s default install. |

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

rust-analyzer uses the Rust kit's Clippy command for save-time checking instead
of plain `cargo check`. lint levels and options remain controlled by each
project through `Cargo.toml`, `clippy.toml`, and source attributes.

### local AI

the optional `ollama` kit installs Ollama and starts its API server on shell
entry. it never downloads model weights automatically: when Ollama's model
store is empty, the startup helper prints commands for the small
`qwen3.5:0.8b`, `qwen3.5:2b`, and `qwen3.5:4b` options. its inline OpenCode
configuration deep-merges with the user's config, points the existing agent and
Sidekick.nvim integration at the local API, and selects the 4B model by default.

the kit limits context to 32k, concurrent requests to one, and loaded models to
one. these trade some maximum agentic context for a useful setup on a small
machine. model weights remain runtime state in Ollama's user data directory;
they are deliberately not Nix store paths.

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

the flake evaluates every kit once per system. the environment is the direct
composition:

```nix
[ coreTools ] ++ languageKits ++ [ ide agent ]
```

the same base kit list feeds every execution context, keeping the default dev
shell, container, and VM consistent. the local-AI shell is the single additive
composition:

```nix
baseKits ++ [ ollama ]
```

## flake outputs

```
devShells.<sys>.default          # shell with every language
devShells.<sys>.ollama           # default shell plus local AI
packages.<linux-sys>.default    # docker image
packages.<linux-sys>.vm         # NixOS VM script
formatter.<sys>                 # nixfmt, so `nix fmt` works
```

when a language kit is added to the registry, it flows automatically into the
shell, docker image, and VM.

## platform support

```nix
systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
```

however, containers and NixOS VMs are linux-only. `pkgs.dockerTools.buildLayeredImage` will happily run on darwin pkgs, but produces an image whose contents are darwin binaries, which can't execute inside a linux container. the NixOS VM builder likewise will not cooperate. the flake restricts `packages.*` to `x86_64-linux` and `aarch64-linux` to make this fail at evaluation rather than at runtime.

building those images on a darwin host therefore needs a linux builder.

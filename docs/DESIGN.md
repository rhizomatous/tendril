# Tendril design doc

## Goal

A polyglot cross-platform agentic dev environment, distributed as a Nix flake. Tendril includes a preconfigured open-source editor, harness, and model. This makes it easy to "grab-and-go" a batteries-included dev env with every supported language, anywhere you need it. Tendril can also build a matching Docker container and VM. Tendril is more approachable than standing up a Nix config from scratch, allowing a novice to gain familiarity with hermetic builds and environment standardization without the complexity of DIYing it.

### What tendril is and isn't

**Tendril is:**

- A Nix flake
- A polglot set of language toolchains (compiler, language server, debugger)
- A batteries-included dev env of core tools (CLI utils, git) an editor (nvim), and an agent (opencode), all composable.
- An additive local-AI dev shell with Ollama and small coding models.
- A matching docker image and NixOS VM.

**Tendril isn't:**

- A language dependency manager. Things like NPM dependencies and PyPI packaes ought to be handled following the usual idioms of their language.

## Structure

```
tendril/
├── flake.nix
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

## Kits

A **kit** a just a name for a reusable, system-agnostic unit of config. Tendril uses these to break up its Nix config into tidy modules.

### IDE

The `ide` kit is a preconfigured batteries-included neovim. This will drop the user in to a fully-functional IDE, that's available anywhere a CLI is, properly wired to the rest of the env. `nixvim` is used to configure a `snacks.nvim`-based setup.

`lspconfig` is set up with auto-attach for for all languages tendril knows about. LSP servers will autoattach when their binary is on PATH. This means you can attach an LSP than is not installed via Nix if needed.

### Local AI

The optional `ollama` kit installs Ollama and starts its API server on shell entry. If Ollama's model store is empty, the startup helper prints instructions to download a suggested set of models at a variety of sizes. At the moment, that's `qwen3.5:0.8b`, `qwen3.5:2b`, and `qwen3.5:4b`.

The `ollama` kit also provides OpenCode config that merges with the user's. This points OpenCode and Sidekick.nvim at the local API, and selects the 4B model by default.

The kit limits context to 32k, concurrent requests to one, and loaded models to one. These keep system load at a low enough level for an average dev laptop.

Model weights are stored in the usuall Ollama directory.

## Builders

A **builder** constructs a Tendril environment from a given set of kits. There are three builders:

- `mkShell`, which produces a Nix devshell (wraps `pkgs.mkShell`)
- `mkDockerImage`, which produces a Docker contianer (wraps `pkgs.dockerTools.buildLayeredImage`)
- `mkNixosVm`, which produces a VM image and runnable boot script (wraps `nixpkgs.lib.nixosSystem`)

## Flake outputs

```
devShells.<sys>.default         # polyglot dev shell
devShells.<sys>.ollama          # default shell plus local AI
packages.<linux-sys>.default    # Docker image
packages.<linux-sys>.vm         # NixOS VM script
formatter.<sys>                 # nixfmt, so `nix fmt` works
```

## Platform support

```nix
systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
```

However, containers and NixOS VMs are linux-only. `pkgs.dockerTools.buildLayeredImage` will happily run on darwin pkgs, but produces an image whose contents are darwin binaries. The NixOS VM builder likewise will not cooperate. The flake restricts `packages.*` to `x86_64-linux` and `aarch64-linux` to make this fail at evaluation rather than at runtime.

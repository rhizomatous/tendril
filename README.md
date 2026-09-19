# Tendril

Tendril is a polyglot agent-enabled dev environment with a local model, distributed as a Nix flake. Pin tendril, and get a batteries-included dev shell: toolchain, language server, debugger and editor integrations, agent harness (OpenCode), and Ollama server.

## Fast facts

### Platforms

Tendril supports `aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`. Tendril requires Nix >= 2.19.

### Languages

| Language   | Bundled tools                          |
| ---------- | -------------------------------------- | 
| typescript | `nodejs_24`                            | 
| go         | `go_1_26`, `gopls`, `delve`, `gotools` | 
| nix        | `nixfmt`, `nil`, `nix-tree`            | 
| python     | `python314`, `uv`, `pyright`, `ruff`   | 
| rust       | `rustc`, `cargo`, `rust-analyzer`, `rustfmt`, `clippy` | 

### Agent tools

Tendril provides:

- [OpenCode](https://opencode.ai/) for agentic work in a chat or CLI workflow
- [Sidekick](https://github.com/folke/sidekick.nvim) for more collaborative AIDE-style work (running OpenCode inside)
- [Ollama](https://ollama.com/) to host open models on your device

## Consuming

You can use Tendril either as an input in your own Nix files, or by directly using the supplied flake.

### Nix

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril";
  outputs = { self, nixpkgs, tendril, ... }: {
    devShells.aarch64-darwin.default = tendril.devShells.aarch64-darwin.default;
  };
}
```

### direnv

```bash
# .envrc in the consumer repo
use flake github:rhizomatous/tendril
```

### Containers & VMs

The environment is also provided as a docker image and a NixOS VM:

```bash
nix build  github:rhizomatous/tendril      # docker image
nix run    github:rhizomatous/tendril#vm   # boot a NixOS VM
```

You might want something like this if you wished to dynamically spin up developer environments in the cloud that matched your local tooling.

Note that these, naturally, do not include Ollama. Model inference is nowhere near lightweight enough (yet!) to slap into a virtualized environment.

Containers and VMs can only be built on Linux at this time.

## Working in Tendril

### OpenCode

Tendril provides OpenCode as an agent harness in the terminal. OpenCode is configured to use the local Ollama instance as a provider.

### Editor

Tendril provides a fully loaded nvim config. This config will auto-attach to relevant linters and language servers when present. It also integrates OpenCode into nvim through
[Sidekick.nvim](https://github.com/folke/sidekick.nvim). `<Space>aa` toggles the chat panel, `<C-.>` moves focus to or from it, and `<Space>a` shows the available context and prompt mappings through which-key.

### Local AI

On entry, tendril starts Ollama if necessary. (If you don't want autostart, you can set `TENDRIL_OLLAMA_SKIP_START=1`.) If you have no models, it will recommend a set of Qwen 3.5 versions appropriate to various machine sizes. OpenCode will defaults to `qwen3.5:4b`.

Model data is stored in Ollama's normal user data directory, outside the Nix store, so existing downloads can be reused.

## What motivated this?

Tendril is largely intended as a tech demo to show off two things:

- **Nix and agent tooling go together like peanut butter and jelly.** It can be effortful to correctly configure all the moving parts. Dev tools may get wrong versions and cause surprising mismatches between installs. These trip up agents and humans alike. Nix lets you specify what you need once, then get the same thing every time. (And agents are decent at writing it, too!)
- **Open-weight local models are for everyone.** If you have a machine that can run a normal current-gen software development environment, you can play with a local model. With the right tools, doing so can be one-click easy.

Tendril _isn't_ intended for mass adoption. Frankly, this would be missing the point! What we hope is to inspire you to build your own tooling that best fits your tastes and your work. If helpful, you are welcome to remix Tendril to do so. If you aren't familiar with Nix yet, we encourage you to ask your agent for help, as well as to check out [the NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/).

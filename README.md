# tendril

a polyglot dev environment, distributed as a Nix flake.

pin tendril, get a batteries-included dev shell: toolchain, language server, debugger, and editor integrations.

see [`docs/DESIGN.md`](docs/DESIGN.md) for the shape of the project and the architectural choices behind it.

## languages

| language   | bundled                                | consumer brings                         |
| ---------- | -------------------------------------- | --------------------------------------- |
| typescript | `nodejs_24`                            | `typescript`, `eslint`, `prettier`, ... |
| go         | `go_1_26`, `gopls`, `delve`, `gotools` | `golangci-lint`, ...                    |
| nix        | `nixfmt`, `nil`, `nix-tree`            | `statix`, `deadnix`, ...                |
| python     | `python314`, `uv`, `pyright`, `ruff`   | `mypy`, `pytest`, project deps via uv, ... |
| rust       | `rustc`, `cargo`, `rust-analyzer`, `rustfmt`, `clippy` | crates via cargo, `cargo-nextest`, ...     |

## consuming

### pin one language

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril";
  outputs = { self, nixpkgs, tendril, ... }: {
    devShells.aarch64-darwin.default = tendril.devShells.aarch64-darwin.go;
  };
}
```

each language ships as one full environment containing its toolchain, core
tools, opencode, and the configured nvim. `polyglot` provides the same
environment with every language bundled together, and `default` aliases it.

each environment is provided as a dev shell. but shells aren't the only target!
each language also produces a docker image and a NixOS VM under
`packages.<linux-sys>`:

```bash
nix build  github:rhizomatous/tendril#go         # docker image
nix run    github:rhizomatous/tendril#vm-go      # boot a NixOS VM with the go env
```

### editor agent

the environments integrate opencode into nvim through
[Sidekick.nvim](https://github.com/folke/sidekick.nvim). `<Space>aa` toggles
opencode in a right-hand panel, `<C-.>` moves focus to or from it, and
`<Space>a` shows the available context and prompt mappings through which-key.

### one shell with everything

```nix
{
  inputs.tendril.url = "github:rhizomatous/tendril";
  outputs = { self, nixpkgs, tendril, ... }: {
    devShells.aarch64-darwin.default = tendril.devShells.aarch64-darwin.polyglot;
  };
}
```

### direnv

```bash
# .envrc in the consumer repo
use flake github:rhizomatous/tendril#typescript
```

## platforms

`aarch64-darwin`, `aarch64-linux`, `x86_64-linux`. requires nix >= 2.19.

## developing tendril

```bash
direnv allow                          # auto-activates dev shell on cd
lefthook install                      # one-time, wires .git/hooks/ to lefthook.yml
nixfmt path/to/file.nix               # format (nixfmt on PATH via dev shell)
nix flake check                       # evaluate all outputs
nix develop .#go                      # standalone per-language shell
```

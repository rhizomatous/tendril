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

each language ships in four flavours:

- `<lang>` — full default: language tools + nvim (ide) + opencode (agent)
- `<lang>-editor` — drops the agent
- `<lang>-agent` — drops the editor
- `<lang>-bare` — drops both, language tools only

`polyglot[-flavour]` follows the same pattern, with every language bundled together. `default` aliases the full polyglot shell.

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

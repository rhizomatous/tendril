# tendril

a polyglot dev environment, distributed as a Nix flake.

pin tendril, get a batteries-included dev shell: toolchain, language server, debugger, and editor integrations.

see [`docs/PLAN.md`](docs/PLAN.md) for design and roadmap.

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

each language ships in four flavors:

- `<lang>` — full default: language tools + nvim (ide) + opencode (agent)
- `<lang>-editor` — drops the agent
- `<lang>-agent` — drops the editor
- `<lang>-bare` — drops both, language tools only

`default[-flavor]` follows the same pattern for the polyglot shell.

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

`mkShell` accepts `extraPackages`, `extraEnv`, and `extraShellHook` for layering on top of the base shell.

### one shell with everything

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
use flake github:rhizomatous/tendril#typescript
```

## platforms

`aarch64-darwin`, `x86_64-darwin`, `aarch64-linux`, `x86_64-linux`. requires nix >= 2.19.

## developing tendril

```bash
direnv allow                          # auto-activates dev shell on cd
lefthook install                      # one-time, wires .git/hooks/ to lefthook.yml
nixfmt path/to/file.nix               # format (nixfmt on PATH via dev shell)
nix flake check                       # evaluate all outputs
nix develop .#go                      # standalone per-language shell
```

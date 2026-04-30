# tendril

a polyglot dev environment, distributed as Nix flakes.

pin tendril, get a batteries-included dev shell: toolchain, language server, debugger, and editor integrations.

see [`docs/PLAN.md`](docs/PLAN.md) for design and roadmap.

## languages

| language   | bundled                                | consumer brings                       |
| ---------- | -------------------------------------- | ------------------------------------- |
| typescript | `nodejs_24`                            | `typescript`, `eslint`, `prettier`, … |
| go         | `go_1_26`, `gopls`, `delve`, `gotools` | `golangci-lint`, …                    |

## consuming

### pin one language

```nix
{
  inputs.tendril-go.url = "github:rhizomatous/tendril?dir=flakes/go";
  outputs = { self, nixpkgs, tendril-go, ... }: {
    devShells.aarch64-darwin.default = tendril-go.devShells.aarch64-darwin.default;
  };
}
```

### pin umbrella, extend a shell

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

### direnv

```bash
# .envrc in the consumer repo
use flake github:rhizomatous/tendril?dir=flakes/typescript
```

## platforms

`aarch64-darwin`, `x86_64-darwin`, `aarch64-linux`, `x86_64-linux`. requires nix >= 2.19.

## developing tendril

```bash
direnv allow                       # auto-activates dev shell on cd
nix fmt path/to/file.nix           # format with nixfmt
nix flake check                    # evaluate all outputs
nix develop ./flakes/<lang>        # standalone per-language shell
```

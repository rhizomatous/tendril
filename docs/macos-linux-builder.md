# building tendril's docker images on macOS

tendril's docker images live at `packages.x86_64-linux.*` and `packages.aarch64-linux.*`. they're linux-targeted (the contents have to run inside the container). on macOS, `nix build` of these fails out of the box with `Cannot build... Build failed due to failed dependency`.

## what doesn't work

**nix-darwin's `nix.linux-builder` module is unreachable when Determinate Nix is installed.** the two directions both fail:

- with `nix.enable = false` (which the determinate nix-darwin module requires), `nix.linux-builder.enable` asserts `requires nix.enable`.
- with `nix.enable = true`, nix-darwin detects Determinate and aborts activation: `Determinate detected, aborting activation`.

this is [nix-darwin#1505](https://github.com/nix-darwin/nix-darwin/issues/1505), open since 2025 with no resolution.

## option 1: Determinate's native linux-builder (preferred, gated)

Determinate Nix 3.8.4+ ships a native linux-builder using macOS's Virtualization framework, configured via the `external-builders` experimental nix setting + the `determinate-nixd builder` helper. once enabled, `nix build` of linux derivations Just Works.

steps:

1. sign up at flakehub.com (free).
2. email `support@determinate.systems` with your FlakeHub username, requesting `native-linux-builder` access. they're rolling it out gradually.
3. once approved: `determinate-nixd auth login`.
4. verify with `determinate-nixd version` — should list `native-linux-builder` under "features enabled".
5. `nix build .#packages.x86_64-linux.typescript --no-link` should now succeed.

## option 2: external linux VM as a remote builder (works today)

run a NixOS guest locally and wire it up as a nix remote builder. no waiting list, no Determinate compat issues.

rough steps:

1. pick a VM runner. [OrbStack](https://orbstack.dev) (macOS-native, fast) or [UTM](https://mac.getutm.app) (Apple Virtualization GUI) are the easiest; [Lima](https://github.com/lima-vm/lima) works for CLI-only setups.
2. boot a NixOS guest with the SSH daemon enabled and your public key in `root@`'s `authorized_keys` (nix builds as root on the remote).
3. configure your local nix to use it. via Determinate, this means adding to `/etc/nix/nix.custom.conf`:

   ```
   builders = ssh://nixos-vm aarch64-linux,x86_64-linux /path/to/key 8 1 kvm,nixos-test,big-parallel,benchmark
   builders-use-substitutes = true
   ```

   substitute `nixos-vm` with your SSH host alias and the key path with the private key matching the one you put in the VM.

4. smoke test: `nix build nixpkgs#legacyPackages.x86_64-linux.hello --no-link`. should dispatch to the VM the first time and stay fast after.

caveats: VM has to be running for builds; ongoing maintenance (`nixos-rebuild`, disk usage); ~hour of one-time setup.

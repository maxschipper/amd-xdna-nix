# amd-xdna-nix

Nix flake for the [AMD XDNA driver](https://github.com/amd/xdna-driver) user-space components and XRT SHIM library, enabling AMD NPU support on NixOS without using pre-built driver binaries.

## Package Summary

| Field | Value |
|---|---|
| Upstream | [amd/xdna-driver](https://github.com/amd/xdna-driver) |
| Packaged source | Commit `beb9e450fe123ecdf395453971576179cedcf1dd` |
| Main tools | `xrt-smi`, `xclbinutil`, and related XRT tools |
| Supported systems | `x86_64-linux` |
| Flake outputs | `packages.x86_64-linux.default`, `packages.x86_64-linux.xdna-driver`, `nixosModules.default` |

## Requirements

- Nix with flakes enabled.
- Linux kernel 6.14 or newer, or a backport, with the `amdxdna` kernel driver enabled.
- An AMD processor with an integrated NPU, such as Ryzen AI, Phoenix, or Strix Point.

## Usage

### Build

```bash
nix build github:michnicki/amd-xdna-nix
```

### Install the package directly

```nix
{ inputs, pkgs, ... }: {
  environment.systemPackages = [
    inputs.amd-xdna-nix.packages.${pkgs.system}.xdna-driver
  ];
}
```

### Enable the NixOS module

Add the flake input:

```nix
{
  inputs.amd-xdna-nix.url = "github:michnicki/amd-xdna-nix";
}
```

Then import the module and enable the driver:

```nix
{ inputs, ... }: {
  imports = [
    inputs.amd-xdna-nix.nixosModules.default
  ];

  hardware.amdnpu.enable = true;
}
```

The module installs the `xdna-driver` package and sets `XILINX_XRT` to the package store path. That direct store path is needed because XRT expects a `lib64` directory that `/run/current-system/sw` does not expose.

## Development

This flake does not define a dedicated development shell. Use `nix build` for local verification.

## Updating

Use the update helper from the repository root:

```bash
./scripts/update-amd-xdna.sh [--dry-run]
```

The script resolves the latest upstream tag to a commit, updates `default.nix`, verifies the build, and commits the bump. If upstream changes generated XRT tarball names, `default.nix` may need a manual install-phase adjustment before the final build passes.

## License

The Nix expressions in this repository are licensed under Apache 2.0, matching the upstream [amd/xdna-driver](https://github.com/amd/xdna-driver) repository.

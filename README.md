# AMD XDNA Driver & XRT SHIM for NixOS

A standalone Nix flake that packages the AMD XDNA™ Driver user-space components and the XRT SHIM library, enabling AMD NPU support on NixOS. XRT and the XDNA SHIM are compiled entirely within the Nix sandbox — no pre-built binaries.

## Requirements

- Linux kernel 6.14+ (or a backport) with the `amdxdna` driver enabled
- An AMD processor with an integrated NPU (e.g. Ryzen AI / Phoenix / Strix Point)

## Usage

### 1. Add to your `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    amd-xdna = {
      url = "github:michnicki/amd-xdna-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, amd-xdna, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        amd-xdna.nixosModules.default
      ];
    };
  };
}
```

### 2. Enable in `configuration.nix`

```nix
{
  hardware.amdnpu.enable = true;
}
```

This installs the `xdna-driver` package (providing `xrt-smi`, `xclbinutil`, and related XRT tools) and sets the `XILINX_XRT` environment variable to the package's store path. The variable is needed because XRT expects a `lib64` directory that NixOS's environment symlinks don't expose.

## Without the NixOS Module

You can also use the package directly without the module:

```nix
{ inputs, pkgs, ... }: {
  environment.systemPackages = [ inputs.amd-xdna.packages.${pkgs.system}.xdna-driver ];
}
```

## License

The Nix expressions in this repository are licensed under Apache-2.0, matching the upstream [amd/xdna-driver](https://github.com/amd/xdna-driver) repository.

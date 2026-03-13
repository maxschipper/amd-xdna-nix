{
  description = "AMD XDNA Driver and XRT SHIM for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          xdna-driver = pkgs.callPackage ./default.nix { };
          default = self.packages.${system}.xdna-driver;
        }
      );

      # A NixOS module to easily enable the driver on any machine
      nixosModules.default = import ./module.nix { inherit self; };
    };
}

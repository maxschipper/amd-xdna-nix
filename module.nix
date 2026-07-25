{ self }:
{ config, lib, pkgs, ... }: {
  options.hardware.amdnpu.enable = lib.mkEnableOption "AMD XDNA NPU driver and XRT SHIM";

  config = lib.mkIf config.hardware.amdnpu.enable {
    environment.systemPackages = [ self.packages.${pkgs.system}.xdna-driver ];
    
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ./kmod.nix {
        src = self.packages.${pkgs.system}.xdna-driver.src;
      })
    ];

    boot.kernelModules = [ "amdxdna" ];

    # The driver requests firmware by exact filename per device/revision
    # (e.g. amdnpu/17f0_10/npu.dev.sbin); without this the module loads but
    # fails to probe any NPU.
    hardware.firmware = [ self.packages.${pkgs.system}.xdna-firmware ];

    # Expose XRT to applications
    # We point directly to the package in the store because XRT expects a lib64
    # directory/symlink which NixOS's buildEnv (/run/current-system/sw) doesn't
    # provide by default.
    environment.sessionVariables = {
      XILINX_XRT = "${self.packages.${pkgs.system}.xdna-driver}";
    };
  };
}

{ self }:
{ config, lib, pkgs, ... }: {
  options.hardware.amdnpu.enable = lib.mkEnableOption "AMD XDNA NPU driver and XRT SHIM";

  config = lib.mkIf config.hardware.amdnpu.enable {
    environment.systemPackages = [ self.packages.${pkgs.system}.xdna-driver ];
    
    # Expose XRT to applications
    # We point directly to the package in the store because XRT expects a lib64
    # directory/symlink which NixOS's buildEnv (/run/current-system/sw) doesn't
    # provide by default.
    environment.sessionVariables = {
      XILINX_XRT = "${self.packages.${pkgs.system}.xdna-driver}";
    };
  };
}

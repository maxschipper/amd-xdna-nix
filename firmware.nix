{
  pkgs ? import <nixpkgs> { },
}:

let
  # The amdxdna driver hardcodes its firmware filename as "npu.dev.sbin" per
  # device/revision directory (see src/driver/amdxdna/npu{1,4,5}_regs.c
  # fw_path). Upstream's own build/build.sh download_npufws() step fetches
  # these same blobs from this gitlab.com/kernel-firmware/drm-firmware
  # "amd-ipu-staging" mirror at build time; we pin them instead so the
  # module actually has firmware to load once the .ko is installed.
  #
  # npu2 (17f0_00, early Strix stepping) has been removed from the staging
  # branch upstream and is not packaged here.
  npu1Fw = pkgs.fetchurl {
    url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/1502_00/1.5_npu.sbin.1.5.5.391";
    sha256 = "17pv10cf7ij34gb882bwnq5z0aam8siyasgs2c1a9kn6jpxzjgyi";
  };
  npu4Fw = pkgs.fetchurl {
    url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/17f0_10/1.7_npu.sbin.1.1.2.64";
    sha256 = "0sal4illifdy86jkbdk3h1cvlbyr713b7j68fpmq3daky91g5l3y";
  };
  npu5Fw = pkgs.fetchurl {
    url = "https://gitlab.com/kernel-firmware/drm-firmware/-/raw/amd-ipu-staging/amdnpu/17f0_11/1.7_npu.sbin.1.1.2.65";
    sha256 = "1v9zj0scr4nm6p7ipbx35p3k44dgkym0znf4wipfjqp5y5p9jg1y";
  };
in
pkgs.runCommand "amdxdna-firmware" { } ''
  mkdir -p $out/lib/firmware/amdnpu/1502_00
  mkdir -p $out/lib/firmware/amdnpu/17f0_10
  mkdir -p $out/lib/firmware/amdnpu/17f0_11

  cp ${npu1Fw} $out/lib/firmware/amdnpu/1502_00/npu.dev.sbin
  cp ${npu4Fw} $out/lib/firmware/amdnpu/17f0_10/npu.dev.sbin
  cp ${npu5Fw} $out/lib/firmware/amdnpu/17f0_11/npu.dev.sbin
''

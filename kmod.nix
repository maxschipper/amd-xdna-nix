{
  stdenv,
  lib,
  kernel,
  src,
}:

stdenv.mkDerivation rec {
  pname = "amdxdna-kmod";
  version = src.version or "git";

  inherit src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Allow configure_kernel.sh to find kernel headers under NixOS split directories
  # and allow overriding the output path via environment variables
  postPatch = ''
    substituteInPlace src/driver/tools/configure_kernel.sh \
      --replace-fail 'OUT="driver/amdxdna/config_kernel.h"' 'OUT="''${OUT:-driver/amdxdna/config_kernel.h}"' \
      --replace-fail 'if [ ! -d "$KERNEL_SRC/include/linux" ]; then' 'if [ ! -d "$KERNEL_SRC/include/linux" ] && [ ! -d "$KERNEL_SRC/../source/include/linux" ]; then'
  '';

  # Build out-of-tree kernel module
  preBuild = ''
    # Generate the compatibility header in the correct path
    export KERNEL_SRC="${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    export KERNEL_VER="${kernel.modDirVersion}"

    mkdir -p src/driver/amdxdna
    OUT="src/driver/amdxdna/config_kernel.h" bash src/driver/tools/configure_kernel.sh
  '';

  buildPhase = ''
    runHook preBuild

    # Compile the module
    make -C src/driver/amdxdna \
      KERNEL_SRC="${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
      KERNEL_VER="${kernel.modDirVersion}" \
      BUILD_ROOT_DIR="$PWD/build" \
      XDNA_BUS_TYPE=pci

    # Copy the built .ko file to the root of the build directory
    make -C src/driver/amdxdna \
      BUILD_ROOT_DIR="$PWD/build" \
      copy_ko

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install to the standard NixOS out-of-tree kernel module directory
    mkdir -p "$out/lib/modules/${kernel.modDirVersion}/extra"
    cp build/amdxdna.ko "$out/lib/modules/${kernel.modDirVersion}/extra/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "AMD XDNA NPU kernel driver module";
    homepage = "https://github.com/amd/xdna-driver";
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}

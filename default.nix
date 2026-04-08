{ pkgs ? import <nixpkgs> {} }:

let
  vtdStrx = pkgs.fetchurl {
    url = "https://github.com/Xilinx/VTD/raw/0b65e6c61ca5505bac0b0b7d6c500806e53b0ad1/archive/strx/xrt_smi_strx.a";
    sha256 = "1ahd7s3zanvxz72w8wzr1zfh4im15dcw4mfwmm6dgw4d95q1nbd3";
  };
  vtdPhx = pkgs.fetchurl {
    url = "https://github.com/Xilinx/VTD/raw/0b65e6c61ca5505bac0b0b7d6c500806e53b0ad1/archive/phx/xrt_smi_phx.a";
    sha256 = "0265jpqqy4f9sb6q2wd1nn3ldfbiab2jlk3hphyz7p77iq1z4w09";
  };
  vtdNpu3 = pkgs.fetchurl {
    url = "https://github.com/Xilinx/VTD/raw/0b65e6c61ca5505bac0b0b7d6c500806e53b0ad1/archive/npu3/xrt_smi_npu3.a";
    sha256 = "13h0rvg4avfssn5dq0na277mbc0kv37g34cnxkdjiwa3va3j312j";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "xdna-driver-xrt";
  version = "ffe59680bedff4280a63af95af4333df826ecf96";

  src = pkgs.fetchgit {
    url = "https://github.com/amd/xdna-driver.git";
    rev = "ffe59680bedff4280a63af95af4333df826ecf96";
    fetchSubmodules = true;
    hash = "sha256-BIW2OQ55Ejctm9C1043q7fUdnmK1HvVIzPF1p8y2KfU=";
  };

  nativeBuildInputs = with pkgs; [
    cmake pkg-config git perl unzip wget gcc autoPatchelfHook python3
    python3Packages.pip python3Packages.pybind11 python3Packages.sphinx
    python3Packages.breathe python3Packages.sphinx-rtd-theme jq
  ];

  buildInputs = with pkgs; [
    boost libdrm libuuid libyaml ncurses ocl-icd opencl-headers openssl
    rapidjson gtest json-glib systemd curl libjpeg libpng libtiff
    elfutils gnuplot graphviz cppcheck strace lm_sensors dmidecode
    yaml-cpp valgrind systemtap-unwrapped
  ];

  postPatch = ''
    # Create fake os-release for build scripts and CMake
    echo 'ID="nixos"' > os-release
    echo 'VERSION_ID="25.11"' >> os-release
    grep -rl '/etc/os-release' . | xargs -r sed -i "s|/etc/os-release|$PWD/os-release|g" || true

    # Disable dynamic dependencies check which fails if not statically compiled
    substituteInPlace xrt/src/runtime_src/core/common/aiebu/src/cpp/utils/asm/CMakeLists.txt \
      --replace-fail "if (NOT AIEBU_UPSTREAM)" "if (FALSE)"
    substituteInPlace xrt/src/runtime_src/core/common/aiebu/src/cpp/utils/dump/CMakeLists.txt \
      --replace-fail "if (NOT AIEBU_UPSTREAM)" "if (FALSE)"
    substituteInPlace xrt/src/runtime_src/core/common/aiebu/src/cpp/utils/transform/CMakeLists.txt \
      --replace-fail "if (NOT AIEBU_UPSTREAM)" "if (FALSE)"

    # Patch CMake pkg.cmake to treat nixos as arch to output TGZ
    substituteInPlace CMake/pkg.cmake \
      --replace-fail 'elseif("''${XDNA_CPACK_LINUX_PKG_FLAVOR}" MATCHES "arch")' \
                     'elseif("''${XDNA_CPACK_LINUX_PKG_FLAVOR}" MATCHES "arch" OR "''${XDNA_CPACK_LINUX_PKG_FLAVOR}" MATCHES "nixos")'

    # Stop build.sh from downloading VTD archives since we provide them manually in configurePhase
    substituteInPlace build/build.sh \
      --replace-fail "wget -O" "echo 'Skipping wget -O'"

    # Bypass wget in xrt/src/runtime_src/core/common/aiebu/src/python/CMakeLists.txt
    if [ -f xrt/src/runtime_src/core/common/aiebu/src/python/CMakeLists.txt ]; then
        substituteInPlace xrt/src/runtime_src/core/common/aiebu/src/python/CMakeLists.txt \
          --replace-fail "COMMAND wget" "# COMMAND wget" || true
    fi
  '';

  configurePhase = ''
    # Provide the VTD archives in the expected location
    mkdir -p amdxdna_bins/vtd_archives
    cp ${vtdStrx} amdxdna_bins/vtd_archives/xrt_smi_strx.a
    cp ${vtdPhx} amdxdna_bins/vtd_archives/xrt_smi_phx.a
    cp ${vtdNpu3} amdxdna_bins/vtd_archives/xrt_smi_npu3.a
  '';

  buildPhase = ''
    export HOME=$TMPDIR
    export XRT_SOURCE_DIR=$PWD/xrt
    export CFLAGS="-isystem ${pkgs.systemtap-unwrapped}/include"
    export CXXFLAGS="-isystem ${pkgs.systemtap-unwrapped}/include"

    # 1. Build XRT
    cd xrt/build
    bash ./build.sh -noinit -npu -opt -noctest -disable-werror -cmake-flags '-DAIEBU_UPSTREAM=ON' -install_prefix $PWD/install
    cd ../..

    # 2. Build XDNA SHIM
    cd build
    bash ./build.sh -release -install_prefix $PWD/install -nokmod
    cd ..
  '';

  installPhase = ''
    mkdir -p $out
    
    mkdir -p tmp_extract
    tar -xzf xrt/build/Release/xrt_202610.2.23.0_25.11--base.tar.gz -C tmp_extract
    tar -xzf xrt/build/Release/xrt_202610.2.23.0_25.11--npu.tar.gz -C tmp_extract
    tar -xzf build/Release/xrt_plugin.2.23.0_25.11-x86_64-amdxdna.tar.gz -C tmp_extract

    # Move the deeply nested install directory contents to the root of $out
    for dir in $(find tmp_extract -type d -name "install"); do
      cp -a $dir/* $out/
    done

    # Move any etc configurations
    ETC_DIR=$(find tmp_extract -type d -path "*/etc" | head -n 1)
    if [ -n "$ETC_DIR" ]; then
      cp -a $ETC_DIR $out/
    fi

    # Cleanup generated setup scripts if they exist
    rm -f $out/setup.sh $out/setup.csh $out/setup.fish

    # Move lib64 to lib so Nix's standard fixup doesn't fail
    if [ -d "$out/lib64" ]; then
      mkdir -p $out/lib
      cp -a $out/lib64/* $out/lib/
      rm -rf $out/lib64
      ln -s lib $out/lib64
    fi
  '';

  postFixup = ''
    for lib in $out/lib/*.so*; do
      if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        echo "Fixing hardcoded paths in $lib"
        sed -i "s|/build/xdna-driver-ffe5968/xrt/build/install|$out|g" "$lib" || true
      fi
    done

    # The loader binary (bin/unwrapped/loader) looks for setup.sh at
    # dirname(argv[0])/../../setup.sh. Create a minimal one at $out/setup.sh.
    cat > $out/setup.sh << EOF
#!/bin/sh
export XILINX_XRT="$out"
export PATH="$out/bin:\$PATH"
export LD_LIBRARY_PATH="$out/lib:\$LD_LIBRARY_PATH"
EOF
    chmod +x $out/setup.sh

    # When xrt-smi is invoked via a symlink in /run/current-system/sw/bin,
    # loader receives the symlink path as argv[0] and computes the wrong
    # setup.sh location. Resolve the real path first so loader finds $out/setup.sh.
    substituteInPlace $out/bin/xrt-smi \
      --replace-fail '"''${XRT_LOADER}" -exec' \
                     '"$(readlink -f "''${XRT_LOADER}")" -exec'
  '';
}
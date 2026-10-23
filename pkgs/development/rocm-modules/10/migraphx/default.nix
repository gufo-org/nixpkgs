{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  pkg-config,
  cmake,
  protobuf,
  abseil-cpp,
  nlohmann_json,
  boost,
  msgpack-cxx,
  sqlite,
  # TODO(@LunNova): Swap to `onednn` once v3 is supported
  # Upstream issue: https://github.com/ROCm/AMDMIGraphX/issues/4351
  onednn_2,
  blaze,
  texliveSmall,
  doxygen,
  sphinx,
  docutils,
  ghostscript,
  python3Packages,

  clr,
  half,
  hipblas,
  hipblas-common,
  hipblaslt,
  miopen,
  openmp,
  rocblas,
  rocm-cmake,
  rocmUpdateScript,
  rocmlir,

  writableTmpDirAsHomeHook,
  buildDocs ? false,
  buildTests ? false,
  gpuTargets ? clr.localGpuTargets or clr.gpuTargets,
}:

let
  # this standard version needs to match the version that migraphx pins, or
  # compilation fails if the pinned version is not the same as the compiler's
  # default.
  # https://github.com/ROCm/AMDMIGraphX/blob/07ef4ba4f9ef95d241b7be165e60ad148f3344ee/CMakeLists.txt#L143-L148
  abseil-cpp' = abseil-cpp.override { cxxStandard = "17"; };

  latex = lib.optionalAttrs buildDocs (
    texliveSmall.withPackages (
      ps: with ps; [
        latexmk
        tex-gyre
        fncychap
        wrapfig
        capt-of
        framed
        needspace
        tabulary
        varwidth
        titlesec
        epstopdf
      ]
    )
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "migraphx";
  version = "10.1";

  outputs = [
    "out"
  ]
  ++ lib.optionals buildDocs [
    "doc"
  ]
  ++ lib.optionals buildTests [
    "test"
  ];

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "AMDMIGraphX";
    tag = "rocm-${finalAttrs.version}";
    hash = "sha256-NusXF2BrmLrAbImnBh4zGKrsBs2O8E6R0kMmPN5S858=";
  };

  patches = [
    # rocm_add_version_resource does not exist in rocm-cmake until after 10.1+
    ./fix-missing-cmake-function.patch
  ];

  nativeBuildInputs = [
    pkg-config
    cmake
    rocm-cmake
    clr
    python3Packages.python
  ]
  ++ lib.optionals buildDocs [
    latex
    doxygen
    sphinx
    docutils
    ghostscript
    python3Packages.sphinx-rtd-theme
    python3Packages.breathe
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    openmp
    rocblas
    hipblas-common
    hipblas
    hipblaslt
    rocmlir
    miopen
    protobuf
    half
    nlohmann_json
    boost
    msgpack-cxx
    sqlite
    onednn_2
    blaze
    python3Packages.pybind11
    python3Packages.onnx
  ];

  env.LDFLAGS = "-Wl,--allow-shlib-undefined";

  cmakeFlags = [
    (lib.cmakeFeature "MIGRAPHX_ENABLE_GPU" "ON")
    (lib.cmakeFeature "MIGRAPHX_ENABLE_CPU" "ON")
    (lib.cmakeFeature "MIGRAPHX_ENABLE_FPGA" "ON")
    (lib.cmakeFeature "MIGRAPHX_ENABLE_MLIR" "ON")
    (lib.cmakeFeature "CMAKE_C_COMPILER" "amdclang")
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "amdclang++")
    (lib.cmakeFeature "CMAKE_VERBOSE_MAKEFILE" "ON")
    (lib.cmakeFeature "EMBED_USE" "CArrays") # Fixes error with lld
    (lib.cmakeFeature "DMIGRAPHX_ENABLE_PYTHON" "ON")
    (lib.cmakeFeature "ROCM_PATH" "${clr}")
    (lib.cmakeFeature "HIP_ROOT_DIR" "${clr}")
    # migraphx relies on an incompatible fork of composable_kernel
    # migraphxs relies on miopen which relies on current composable_kernel
    # impossible to build with this ON; we can't link both of them even if we package both
    (lib.cmakeFeature "MIGRAPHX_USE_COMPOSABLEKERNEL" "OFF")
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    (lib.cmakeFeature "GPU_TARGETS" "${lib.concatStringsSep ";" gpuTargets}")
  ];

  postPatch = ''
    export CXXFLAGS+=" -w -isystem${rocmlir}/include/rocmlir -I${half}/include -I${lib.getInclude abseil-cpp'}/include -I${hipblas-common}/include -I${lib.getInclude protobuf}/include"
    patchShebangs tools

    # `error: '__clang_hip_runtime_wrapper.h' file not found [clang-diagnostic-error]`
    substituteInPlace CMakeLists.txt \
      --replace "set(MIGRAPHX_TIDY_ERRORS ALL)" ""

    # Fix Unicode minus sign (U+2212) in comment that breaks EMBED_USE=CArrays
    # The embed mechanism generates char[] arrays that can't store unicode −
    # which has values >127
    substituteInPlace src/targets/gpu/kernels/include/migraphx/kernels/bit.hpp \
      --replace-fail "// popcount(~(x | −x))" "// popcount(~(x | -x))"
  ''
  + lib.optionalString (!buildDocs) ''
    substituteInPlace CMakeLists.txt \
      --replace "add_subdirectory(doc)" ""
  ''
  + lib.optionalString (!buildTests) ''
    substituteInPlace CMakeLists.txt \
      --replace "add_subdirectory(test)" ""
  '';

  # Unfortunately, it seems like we have to call make on this manually
  preInstall = lib.optionalString buildDocs ''
    make -j$NIX_BUILD_CORES doc
    cd ../doc/pdf
    make -j$NIX_BUILD_CORES
    cd -
  '';

  postInstall =
    lib.optionalString buildDocs ''
      mv ../doc/html $out/share/doc/migraphx
      mv ../doc/pdf/MIGraphX.pdf $out/share/doc/migraphx
    ''
    + lib.optionalString buildTests ''
      mkdir -p $test/bin
      mv bin/test_* $test/bin
      patchelf $test/bin/test_* --shrink-rpath --allowed-rpath-prefixes "$NIX_STORE"
    '';

  passthru.impureTests = {
    # NIXPKGS_ALLOW_UNFREE=1 bash $(nix-build -A rocmPackages.migraphx.impureTests.migraphx-driver)
    migraphx-driver = callPackage ./test-migraphx-driver.nix {
      migraphx = finalAttrs.finalPackage;
    };
  };
  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "AMD's graph optimization engine";
    homepage = "https://github.com/ROCm/AMDMIGraphX";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

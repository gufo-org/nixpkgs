{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  clr,
  gfortran,
  rocblas,
  rocsolver,
  rocsparse,
  suitesparse,
  gtest,
  blas,
  lapack-reference,
  buildTests ? false,
  buildBenchmarks ? false,
  buildSamples ? false,
}:

# Can also use cuSOLVER
stdenv.mkDerivation (finalAttrs: {
  pname = "hipsolver";
  version = "10.0";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/hipsolver"
      "shared"
    ];
    hash = "sha256-E9WxBfJ5CUCgDdIF05Uy80HfId+ZJSxG5k51jaWNyEw=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/hipsolver";

  nativeBuildInputs = [
    cmake
    rocm-cmake
    clr
    gfortran
  ];

  buildInputs = [
    blas
    lapack-reference
    rocblas
    rocsolver
    rocsparse
    suitesparse
  ]
  ++ lib.optionals buildTests [
    gtest
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "hipcc")
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    # use system lapack
    (lib.cmakeFeature "HIPSOLVER_INTERNAL_LAPACK_BUILD" "OFF")
    (lib.cmakeFeature "HIPSOLVER_FIND_PACKAGE_LAPACK_CONFIG" "OFF")
  ]
  ++ lib.optionals buildTests [
    (lib.cmakeFeature "BUILD_CLIENTS_TESTS" "ON")
  ]
  ++ lib.optionals buildBenchmarks [
    (lib.cmakeFeature "BUILD_CLIENTS_BENCHMARKS" "ON")
  ]
  ++ lib.optionals buildSamples [
    (lib.cmakeFeature "BUILD_CLIENTS_SAMPLES" "ON")
  ];

  postInstall =
    lib.optionalString buildTests ''
      mkdir -p $test/bin
      mv $out/bin/hipsolver-test $test/bin
    ''
    + lib.optionalString buildBenchmarks ''
      mkdir -p $benchmark/bin
      mv $out/bin/hipsolver-bench $benchmark/bin
    ''
    + lib.optionalString buildSamples ''
      mkdir -p $sample/bin
      mv clients/staging/example-* $sample/bin
      patchelf $sample/bin/example-* --shrink-rpath --allowed-rpath-prefixes "$NIX_STORE"
    ''
    + lib.optionalString (buildTests || buildBenchmarks) ''
      rmdir $out/bin
    '';

  outputs = [
    "out"
  ]
  ++ lib.optionals buildTests [
    "test"
  ]
  ++ lib.optionals buildBenchmarks [
    "benchmark"
  ]
  ++ lib.optionals buildSamples [
    "sample"
  ];

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "ROCm SOLVER marshalling library";
    homepage = "https://github.com/ROCm/rocm-libraries/tree/develop/projects/hipsolver";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

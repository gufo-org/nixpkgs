{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  rocblas,
  rocsparse,
  rocprim,
  rocrand,
  clr,
  pkg-config,
  openmp,
  openmpi,
  gtest,
  buildTests ? false,
  buildBenchmarks ? false,
  buildSamples ? false,
  gpuTargets ? clr.localGpuTargets or [ ], # gpuTargets = [ "gfx803" "gfx900:xnack-" "gfx906:xnack-" ... ]
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rocalution";
  version = "10.0";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/rocalution"
      "shared"
    ];
    hash = "sha256-fIntHp+NCC7v1tOnRq8W3tOSuSpdreC7CpUhkhui8xs=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/rocalution";

  nativeBuildInputs = [
    cmake
    rocm-cmake
    clr
    pkg-config
  ];

  buildInputs = [
    rocblas
    rocsparse
    rocprim
    rocrand
    openmp
    openmpi
  ]
  ++ lib.optionals buildTests [
    gtest
  ];

  cmakeFlags = [
    (lib.cmakeFeature "ROCM_PATH" "${clr}")
    (lib.cmakeFeature "HIP_ROOT_DIR" "${clr}")
    (lib.cmakeFeature "SUPPORT_HIP" "ON")
    (lib.cmakeFeature "SUPPORT_OMP" "ON")
    (lib.cmakeFeature "SUPPORT_MPI" "ON")
    (lib.cmakeFeature "BUILD_CLIENTS_SAMPLES" "${if buildSamples then "ON" else "OFF"}")
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
  ]
  ++ lib.optionals (gpuTargets != [ ]) [
    (lib.cmakeFeature "GPU_TARGETS" "${lib.strings.concatStringsSep ";" gpuTargets}")
  ]
  ++ lib.optionals buildTests [
    (lib.cmakeFeature "BUILD_CLIENTS_TESTS" "ON")
  ]
  ++ lib.optionals buildBenchmarks [
    (lib.cmakeFeature "BUILD_CLIENTS_BENCHMARKS" "ON")
  ];

  postInstall =
    lib.optionalString buildTests ''
      mkdir -p $test/bin
      mv $out/bin/rocalution-test $test/bin
    ''
    + lib.optionalString buildBenchmarks ''
      mkdir -p $benchmark/bin
      mv $out/bin/rocalution-bench $benchmark/bin
    ''
    + lib.optionalString buildSamples ''
      mkdir -p $sample/bin
      mv clients/staging/* $sample/bin
      rm $sample/bin/rocalution-test || true
      rm $sample/bin/rocalution-bench || true

      patchelf --set-rpath \
        $out/lib:${lib.makeLibraryPath (finalAttrs.buildInputs ++ [ clr ])} \
        $sample/bin/*
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
    description = "Iterative sparse solvers for ROCm";
    homepage = "https://github.com/ROCm/rocALUTION";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

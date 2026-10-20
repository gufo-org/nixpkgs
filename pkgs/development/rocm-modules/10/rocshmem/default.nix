{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  rocm-core,
  rocm-runtime,
  rocprofiler-register,
  amdsmi,
  clr,
  mpi,
  symlinkJoin,
  useMpi ? true,
  useReverseOffload ? useMpi,
  buildExamples ? false,
  gpuTargets ? (clr.localGpuTargets or clr.gpuTargets),
}:


let
  rocm-path = symlinkJoin {
    name = "rocm-merged";
    paths = [
      clr
      rocm-runtime
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "rocshmem${clr.gpuArchSuffix}";
  version = "10.0";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-systems";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/rocshmem"
      "shared"
    ];
    hash = "sha256-KkMtpW1OYqTp4p+d/Z27PCVM4T4oAOtAPk3uqTxFRJA=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/rocshmem";

  patches = [
    ./fix-clang-include-path.patch
  ];

  nativeBuildInputs = [
    cmake
    rocm-cmake
    rocm-path
  ];

  buildInputs = [
    rocprofiler-register
    amdsmi
  ]
  ++ lib.optionals useMpi [
    mpi
  ];

  cmakeFlags = [
    (lib.cmakeBool "CMAKE_POSITION_INDEPENDENT_CODE" true)
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "hipcc")
    (lib.cmakeFeature "ROCM_VERSION" rocm-core.ROCM_LIBPATCH_VERSION)
    (lib.cmakeFeature "ROCM_PATH" "${rocm-path}")
    (lib.cmakeBool "USE_IPC" true)
    (lib.cmakeBool "USE_RO" useReverseOffload)
    (lib.cmakeBool "USE_SINGLE_NODE" (!useMpi))
    (lib.cmakeBool "USE_EXTERNAL_MPI" useMpi)
    (lib.cmakeBool "BUILD_EXAMPLES" buildExamples)
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
  ]
  ++ lib.optionals (gpuTargets != [ ]) [
    (lib.cmakeFeature "GPU_TARGETS" (lib.concatStringsSep ";" gpuTargets))
  ];

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "The ROCm OpenSHMEM (rocSHMEM) runtime";
    homepage = "https://github.com/ROCm/rocSHMEM";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

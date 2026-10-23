{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  git,
  libxml2,
  msgpack-cxx,
  ninja,
  openmp,
  pkg-config,
  python3,
  python3Packages,
  zlib,
  zstd,

  amdsmi,
  clr,
  hipsparse,
  llvm,
  rocm-cmake,
  rocm-comgr,
  rocm-device-libs,
  rocm-runtime,
  rocmUpdateScript,
  # hipsparselt only supports gfx942/gfx950/gfx1250
  gpuTargets ? clr.localGpuTargets or clr.gpuTargets,
}:

let
  supportedTargets = (
    lib.lists.intersectLists gpuTargets [
      "gfx942"
      "gfx950"
      "gfx1250"
    ]
  );
  supportsTargetArches = supportedTargets != [ ];
  py = python3.withPackages (ps: [
    ps.pyyaml
    ps.setuptools
    ps.packaging
    ps.nanobind
    ps.msgpack
    ps.joblib
  ]);
  compiler = "amdclang++";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hipsparselt${clr.gpuArchSuffix}";
  version = "10.1";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    hash = "sha256-n/MZPHFFtcVY2yHTapBSPTjvS7J+VtgCWunvSv8De48=";
    sparseCheckout = [
      "projects/hipsparselt"
      # TODO: stop building hipblaslt from source, needs a 10.1+ release
      # https://github.com/ROCm/rocm-libraries/pull/11726
      "projects/hipblaslt/tensilelite"
      "projects/hipblaslt/cmake"
      "projects/hipblaslt/device-library"
      "projects/hipblaslt/library/include"
      "shared"
    ];
  };
  sourceRoot = "${finalAttrs.src.name}/projects/hipsparselt";

  postPatch = ''
    # linting tool that lives in <root>/cmake/modules/ so isn't present in sparse checkout
    substituteInPlace ../../shared/stinkytofu/CMakeLists.txt \
      --replace-fail 'include(ClangTidy)' "" \
      --replace-fail 'add_clang_tidy_custom_target()' ""
  '';

  preBuild = ''
    # Tensile wants to write to <home>/.tensile/helper_cache during the build
    export HOME=$(mktemp -d)
  '';

  env.CXX = compiler;
  env.ROCM_PATH = "${clr}";
  env.TENSILE_ROCM_ASSEMBLER_PATH = lib.getExe' clr "amdclang++";
  env.TENSILE_GEN_ASSEMBLY_TOOLCHAIN = lib.getExe' clr "amdclang++";
  requiredSystemFeatures = [ "big-parallel" ];

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    amdsmi
    clr
    rocm-cmake

    cmake
    git
    ninja
    pkg-config
    py
  ];

  buildInputs = [
    hipsparse
    llvm.llvm
    rocm-cmake
    rocm-comgr
    rocm-device-libs
    rocm-runtime

    libxml2
    msgpack-cxx
    openmp
    python3Packages.msgpack
    zlib
    zstd
  ];

  cmakeFlags = [
    (lib.cmakeFeature "GPU_TARGETS" (lib.concatStringsSep ";" supportedTargets))
    (lib.cmakeBool "HIPSPARSELT_ENABLE_DEVICE" supportsTargetArches)
    (lib.cmakeBool "HIPSPARSELT_ENABLE_CLIENT" false)
    (lib.cmakeBool "HIPSPARSELT_BUILD_TESTING" false)
    (lib.cmakeBool "HIPSPARSELT_ENABLE_MARKER" false)
    (lib.cmakeFeature "CMAKE_C_COMPILER" "amdclang")
    (lib.cmakeFeature "CMAKE_HIP_COMPILER" compiler)
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" compiler)
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_NANOBIND" "${python3Packages.nanobind.src}")
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
  ];

  passthru.supportsTargetArches = supportsTargetArches;
  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "ROCm hipSPARSELt - a SPARSE marshalling library";
    homepage = "https://github.com/ROCm/rocm-libraries/tree/develop/projects/hipsparselt";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

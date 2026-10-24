{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  rocm-cmake,
  rocm-docs-core,
  half,
  clr,
  openmp,
  boost,
  gfortran,
  python3Packages,
  symlinkJoin,
  fetchpatch,
  buildDocs ? false, # Needs internet
  useCPU ? false,
  gpuTargets ? clr.localGpuTargets or [ ],
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rpp-${if useCPU then "cpu" else "hip"}";

  version = "10.1";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/rpp"
      "shared"
    ];
    hash = "sha256-ZD3gzZhb1n5hSJ6nnYVksuoYEEy+wzaLbh02tMdv8dQ=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/rpp";

  # api/rppdefs.h includes <half.hpp> but HALF::half is linked PRIVATE, so
  # targets built against rpp (the in-tree test_rpp_backend_macro) cannot find it.
  # BUILD_INTERFACE keeps HALF::half out of the installed rpp-targets.cmake,
  # where consumers like mivisionx could not resolve it.
  postPatch = ''
    sed -i 's|^\(set_target_properties(''${PROJECT_NAME} PROPERTIES POSITION_INDEPENDENT_CODE ON)\)$|target_link_libraries(''${PROJECT_NAME} PUBLIC $<BUILD_INTERFACE:HALF::half>)\n\1|' CMakeLists.txt
    grep -q 'PUBLIC $<BUILD_INTERFACE:HALF::half>' CMakeLists.txt
  '';

  nativeBuildInputs = [
    cmake
    rocm-cmake
    clr
    gfortran
  ]
  ++ lib.optionals buildDocs [
    rocm-docs-core
    python3Packages.python
  ];

  buildInputs = [
    half
    openmp
    boost
  ];

  cmakeFlags = [
    (lib.cmakeFeature "ROCM_PATH" "${clr}")
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    (lib.cmakeFeature "BACKEND" "${if useCPU then "CPU" else "HIP"}")
  ]
  ++ lib.optionals (gpuTargets != [ ]) [
    (lib.cmakeFeature "GPU_TARGETS" "${lib.concatStringsSep ";" gpuTargets}")
  ];

  # fixes error: 'posix_memalign' is missing exception specification 'noexcept(true)'
  # during the CPU build. Likely due to rpp adding `-fopenmp` when building without HIP
  env = lib.optionalAttrs useCPU {
    CXXFLAGS = "-isystem ${stdenv.cc}/include";
  };

  postBuild = lib.optionalString buildDocs ''
    python3 -m sphinx -T -E -b html -d _build/doctrees -D language=en ../docs _build/html
  '';

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "Comprehensive high-performance computer vision library for AMD processors";
    homepage = "https://github.com/ROCm/rpp";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

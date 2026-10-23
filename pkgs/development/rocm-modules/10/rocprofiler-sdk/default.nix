{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  aqlprofile,
  clr,
  rccl,
  rocm-cmake,
  rocm-comgr,
  rocm-device-libs,
  rocm-runtime,
  rocmUpdateScript,
  rocprof-trace-decoder,
  rocprofiler-register,
  python3,
  python3Packages,
  libdrm,
  elfutils,
  sqlite,
  otf2,
  zlib,
  zstd,
  xz,
  numactl,
  fmt,
  glog,
  gtest,
  yaml-cpp,
  elfio,
  nlohmann_json,
  makeWrapper,
  gpuTargets ? (clr.localGpuTargets or clr.gpuTargets),
  buildTests ? false,
  buildSamples ? false,
}:

# FIXME: devendor remaining git submodules:
#   external/cereal     -> https://github.com/jrmadsen/cereal
#   external/gotcha     -> https://github.com/jrmadsen/GOTCHA
#   external/perfetto   -> https://github.com/google/perfetto
#   external/ptl        -> https://github.com/jrmadsen/PTL

# rocprofiler-sdk is the home of rocprofv3
stdenv.mkDerivation (finalAttrs: {
  pname = "rocprofiler-sdk";
  version = "10.1";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-systems";
    tag = "therock-${finalAttrs.version}";
    hash = "sha256-UmYHC+87XIW+Z4WVd7k0MQ9baTvFlq/SgCt9Foy1mPI=";
    fetchSubmodules = true;
    sparseCheckout = [
      "projects/rocprofiler-sdk"
    ];
  };
  sourceRoot = "${finalAttrs.src.name}/projects/rocprofiler-sdk";

  strictDeps = true;

  nativeBuildInputs = [
    clr

    cmake
    ninja
    pkg-config
    python3
    makeWrapper
  ];

  buildInputs = [
    aqlprofile
    rccl
    rocm-cmake
    rocm-comgr
    rocm-device-libs
    rocm-runtime
    rocprof-trace-decoder
    rocprofiler-register

    elfio
    elfutils
    fmt
    glog
    gtest
    libdrm
    nlohmann_json
    numactl
    otf2
    python3Packages.pybind11
    sqlite
    xz
    yaml-cpp
    zlib
    zstd
  ];

  patches = [
    # Can be removed when a release contains the changes found in this pr:
    # https://github.com/ROCm/rocm-systems/pull/4721
    # Not quite for 10.0
    ./0003-allow-using-system-elfio-dependency.patch
    ./0004-allow-using-system-otf2-dependency.patch
    ./0005-allow-using-system-json-dependency.patch
    ./0006-fix-amd-comgr-resolution.patch
  ]
  ++ [
    # One new import failure added to source commit:
    # https://github.com/ROCm/rocm-systems/pull/4721/changes/f7f24a54cbe55425fbefc87c7a3d0f4c85224948
    # which is also part of https://github.com/ROCm/rocm-systems/pull/4721
    # limited down to fstream includes in 10.0. Likely removable during 10.1
    ./fstream-include.patch
  ]
  ++ [
    # Prevent a segfault on `import torch` (and other consumers that link
    # librocprofiler-sdk for tracing) when OpenMP auto-discovers our
    # ompt_start_tool before glog is initialized. Upstream incidentally fixes
    # this by dropping glog in rocm-systems d80117889b3f
    # "[rocprofiler-sdk] Migrate from glog to Abseil Logging (#4668)", which
    # is too invasive (40 files + new abseil submodule) to backport.
    ./0009-rocprofiler-sdk-guard-ompt-auto-start.patch
  ];

  postPatch = ''
    # NixOS' ROCm distribution does not support libomptarget yet
    substituteInPlace samples/CMakeLists.txt \
      --replace-fail 'add_subdirectory(openmp_target)' '# add_subdirectory(openmp_target)'
    substituteInPlace tests/CMakeLists.txt \
      --replace-fail 'add_subdirectory(openmp-tools)' '# add_subdirectory(openmp-tools)'
    substituteInPlace tests/bin/CMakeLists.txt \
      --replace-fail 'add_subdirectory(openmp)' '# add_subdirectory(openmp)'

    # This requires building perfetto's trace-processor-shell via a weird external script
    substituteInPlace tests/CMakeLists.txt \
      --replace-fail 'add_subdirectory(pytest-packages)' ""

    patchShebangs source/libexec/rocprofiler-sdk/rocprofiler-sdk-launch-compiler/rocprofiler-sdk-launch-compiler.sh

    # CMAKE includes for `<sqlite3.h>` `<libdrm/amdgpu*.h>`
    # add_subdirectory(external) appears to find libdrm just fine.
    # add_subdirectory(source) breaks something in resolution afterwards
    # note: multiline substituteInPlace
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        'add_subdirectory(source)' \
        'include_directories(SYSTEM ${lib.getDev sqlite}/include ${lib.getDev libdrm}/include)
        add_subdirectory(source)'
  '';

  cmakeFlags = [
    (lib.cmakeBool "ROCPROFILER_BUILD_GHC_FS" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_FMT" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_GLOG" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_GTEST" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_PYBIND11" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_YAML_CPP" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_ELFIO" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_OTF2" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_JSON" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_TESTS" buildTests)
    (lib.cmakeBool "ROCPROFILER_BUILD_SAMPLES" buildSamples)
    (lib.cmakeBool "ROCPROFILER_BUILD_BENCHMARK" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_WERROR" false)
    (lib.cmakeBool "ROCPROFILER_BUILD_SQLITE3" false)
    # rocprofiler-sdk's CMake file doesn't add this dependency properly.
    (lib.cmakeFeature "CMAKE_HIP_FLAGS" "-I${rocm-runtime}/include")
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    # Required for rocprofiler-sdk-launch-compiler.sh
    (lib.cmakeFeature "CMAKE_INSTALL_LIBEXECDIR" "libexec")
    #"--debug-find-pkg=amd_comgr"
    #"--trace-source=CMakeLists.txt"
    #"--trace-expand"
  ]
  ++ lib.optionals (buildTests || buildSamples) [
    # rocprofiler-sdk normally doesn't depend on which GPU is in the system, only when
    # building tests or samples.
    (lib.cmakeFeature "GPU_TARGETS" (lib.concatStringsSep ";" gpuTargets))
  ];

  doCheck = false; # Requires GPU

  postFixup = ''
    patchelf $out/lib/*.so \
      --add-rpath ${aqlprofile}/lib \
      --add-needed libhsa-amd-aqlprofile64.so

    wrapProgram $out/bin/rocprofv3 --add-flags "--att-library-path ${
      lib.makeLibraryPath [ rocprof-trace-decoder ]
    }"
  '';

  postInstall = ''
    mkdir -p $dev/lib $dev/share/rocprofiler-sdk
    mv $out/lib/cmake $dev/lib/
    mv $out/share/rocprofiler-sdk/{samples,tests} $dev/share/rocprofiler-sdk/
  '';

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "ROCm GPU performance analysis SDK";
    homepage = "https://github.com/ROCm/rocprofiler-sdk";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

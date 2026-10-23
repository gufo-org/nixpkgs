{
  amd-blis,
  boost,
  cmake,
  fetchFromGitHub,
  fmt,
  gfortran,
  gtest,
  jemalloc,
  lapack-reference,
  lib,
  libffi,
  libxml2,
  msgpack-cxx,
  ncurses,
  ninja,
  openmp,
  pkg-config,
  python3,
  python3Packages,
  spdlog,
  stdenv,
  yaml-cpp,
  zlib,
  zstd,

  # rocmPackages imports
  amdsmi,
  clr,
  hipblas-common,
  libdivide,
  llvm,
  rocm-cmake,
  rocm-comgr,
  rocm-device-libs,
  rocm-runtime,
  rocmUpdateScript,

  buildTests ? false,
  buildSamples ? false,
  # hipblaslt supports only devices with MFMA or WMMA
  gpuTargets ? (clr.localGpuTargets or clr.gpuTargets),
}:

let
  # hipblaslt is extremely particular about what it will build with
  # so intersect with a known supported list and use only those
  supportedTargets = (
    lib.lists.intersectLists gpuTargets [
      "gfx908"
      "gfx90a"
      "gfx942"
      "gfx950"
      "gfx1100"
      "gfx1101"
      "gfx1102"
      "gfx1103"
      "gfx1150"
      "gfx1151"
      "gfx1152"
      "gfx1153"
      "gfx1200"
      "gfx1201"
      "gfx1250"
    ]
  );
  supportsTargetArches = supportedTargets != [ ];
  py = python3.withPackages (ps: [
    ps.joblib
    ps.msgpack
    ps.nanobind
    ps.packaging
    ps.pyyaml
    ps.setuptools
  ]);
  # workaround: build for one working target if no targets are supported
  # a few CXX files are still build for the device
  gpuTargets' =
    if supportsTargetArches then (lib.concatStringsSep ";" supportedTargets) else "gfx1200";
  compiler = "amdclang++";
  # no-switch due to spammy warnings on some cases with fixme messages
  # FIXME(LunNova@): cmake files need patched to include this properly or
  # maybe we improve the toolchain to use config files + assemble a sysroot
  # so system wide include assumptions work
  cFlags = "-Wno-switch -fopenmp -I${lib.getDev zstd}/include -I${amd-blis}/include/blis/ -I${lib.getDev msgpack-cxx}/include";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hipblaslt${clr.gpuArchSuffix}";
  version = "10.1";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-libraries";
    tag = "therock-${finalAttrs.version}";
    hash = "sha256-FOwC+eG8dYgiktogDrUZhtKbKl9iNFvnGXSt0Uj02lQ=";
    sparseCheckout = [
      "projects/hipblaslt"
      "shared"
    ];
    # Compress the 5ish GiB of yaml files so this .src is under output size limit
    postFetch = ''
      find $out -name '*.yaml' -path '*/Tensile/Logic/*' -exec ${lib.getExe zstd} --rm {} \;
    '';
  };
  # rocroller requires patching, rocroller is in shared complicating patching
  # manually set sourceRoot in postPatch
  #sourceRoot = "${finalAttrs.src.name}/projects/hipblaslt";

  env.CXX = compiler;
  env.CFLAGS = cFlags;
  env.CXXFLAGS = cFlags;
  env.ROCM_PATH = "${clr}";
  env.TENSILE_ROCM_ASSEMBLER_PATH = lib.getExe' clr "amdclang++";
  env.TENSILE_GEN_ASSEMBLY_TOOLCHAIN = lib.getExe' clr "amdclang++";
  env.LD_PRELOAD = "${jemalloc}/lib/libjemalloc.so";
  env.MALLOC_CONF = "background_thread:true,metadata_thp:auto,dirty_decay_ms:10000,muzzy_decay_ms:10000";
  requiredSystemFeatures = [ "big-parallel" ];

  __structuredAttrs = true;
  strictDeps = true;

  outputs = [
    "out"
    # benchmarks are non-optional
    "benchmark"
  ]
  ++ lib.optionals buildTests [
    "test"
  ]
  ++ lib.optionals buildSamples [
    "sample"
  ];

  patches = [
    # Upstream issue requesting properly specifying
    # parallel-jobs for these invocations
    # https://github.com/ROCm/rocm-libraries/issues/1242
    ./parallel-buildSourceCodeObjectFile.diff
  ]
  ++ [
    # fixes unknown type name 'uint32_t'
    ./rocroller-includes-fixes.patch
  ]
  ++ [
    # cmake seems to override/ignore/need a different path to set
    # (lib.cmakeBool "ROCROLLER_ENABLE_FETCH" false)
    # when that's true the current yaml-cpp cmake attempts to git fetch
    # other targets are protected by 'find_package' first
    ./cmake-fix-yaml-cpp-lookup.patch
  ];

  preConfigure = ''
    find . -name '*.yaml.zst' -path '*/Tensile/Logic/*' -exec zstd -d --rm {} \;
  '';

  postPatch = ''
    # manually transition to what should be sourceRoot
    cd projects/hipblaslt

    substituteInPlace CMakeLists.txt \
      --replace-fail " LANGUAGES CXX" " LANGUAGES CXX C ASM"

    # needs git if rocm-cmake can't be found, ignore
    substituteInPlace /build/source/shared/origami/cmake/dependencies.cmake \
      --replace-fail "find_package(Git REQUIRED)" ""

    # linting tool that lives in <root>/cmake/modules/ so isn't present in sparse checkout
    substituteInPlace /build/source/shared/stinkytofu/CMakeLists.txt \
      --replace-fail 'include(ClangTidy)' "" \
      --replace-fail 'add_clang_tidy_custom_target()' ""
  '';

  preBuild = ''
    # Tensile wants to write to <home>/.tensile/helper_cache during the build
    export HOME=$(mktemp -d)
  '';

  doCheck = false;
  doInstallCheck = true;

  nativeBuildInputs = [
    amdsmi
    clr
    cmake
    gfortran
    ninja
    pkg-config
    py
    zstd
  ];

  buildInputs = [
    hipblas-common
    lapack-reference
    libdivide
    libffi
    llvm.llvm
    rocm-cmake
    rocm-comgr
    rocm-device-libs
    rocm-runtime

    amd-blis
    fmt
    ncurses
    openmp
    spdlog
    yaml-cpp

    # Tensile deps - not optional, building without tensile isn't actually supported
    msgpack-cxx
    libxml2
    python3Packages.msgpack
    zlib
    zstd
  ]
  ++ lib.optionals buildTests [
    gtest
  ];

  cmakeFlags = [
    (lib.cmakeFeature "Boost_INCLUDE_DIR" "${lib.getDev boost}/include") # msgpack FindBoost fails to find boost
    (lib.cmakeFeature "GPU_TARGETS" gpuTargets')
    (lib.cmakeBool "BUILD_TESTING" buildTests)
    (lib.cmakeBool "HIPBLASLT_ENABLE_BLIS" true)
    (lib.cmakeBool "HIPBLASLT_BUILD_TESTING" buildTests)
    (lib.cmakeBool "HIPBLASLT_ENABLE_SAMPLES" buildSamples)
    (lib.cmakeBool "HIPBLASLT_ENABLE_DEVICE" supportsTargetArches)
    (lib.cmakeFeature "CMAKE_C_COMPILER" "amdclang")
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "${compiler}")
    (lib.cmakeFeature "BLIS_ROOT" "${amd-blis}")
    (lib.cmakeFeature "BLIS_LIB" "${amd-blis}/lib/libblis-mt.so")
    (lib.cmakeFeature "BLIS_INCLUDE_DIR" "${amd-blis}/include/blis/")
    (lib.cmakeFeature "BLA_PREFER_PKGCONFIG" "ON")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_NANOBIND" "${python3Packages.nanobind.src}")
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_INCLUDEDIR" "include")
    (lib.cmakeFeature "HIPBLASLT_ENABLE_MARKER" "Off")
  ];

  postInstall =
    # Compress msgpack .dat files to stay under hydra output size limit
    # Relies on messagepack-compression-support.patch
    ''
      for file in $out/lib/hipblaslt/library/*.dat; do
        zstd -19 --long -f "$file" -o "$file.tmp" && mv "$file.tmp" "$file"
      done
    ''
    # Move binaries to appropriate outputs and delete leftover /bin
    + ''
      mkdir -p $benchmark/bin
      mv $out/bin/hipblaslt-{api-overhead,bench*,cotenant*,perf} \
        $out/bin/*.yaml \
        $out/bin/*.py \
        $benchmark/bin
      ${lib.optionalString buildTests ''
        mkdir -p $test/bin
        mv $out/bin/hipblas-test $test/bin
      ''}
      ${lib.optionalString buildSamples ''
        mkdir -p $sample/bin
        mv $out/bin/example-* $sample/bin
      ''}
      rmdir $out/bin
    '';

  installCheckPhase =
    # Verify compression worked and .dat files aren't huge
    ''
      runHook preInstallCheck
      find "$out" -type f -name "*.dat" -size "+2M" -exec sh -c '
          echo "ERROR: oversized .dat file, check for issues with install compression: {}" >&2
          exit 1
      ' {} \;
      echo "Verified .dat files in $out are not huge"
      runHook postInstallCheck
    '';

  # If this is false there are no kernels in the output lib
  # supporting the target device
  # so if it's an optional dep it's best to not depend on it
  # Some packages like torch need hipblaslt to compile
  # and are fine ignoring it at runtime if it's not supported
  # so we have to support building an empty hipblaslt
  passthru.supportsTargetArches = supportsTargetArches;
  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };
  meta = {
    description = "Library that provides general matrix-matrix operations with a flexible API";
    homepage = "https://github.com/ROCm/rocm-libraries/tree/develop/projects/hipblaslt";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

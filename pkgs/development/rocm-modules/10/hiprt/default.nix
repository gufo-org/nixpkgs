{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  clr,
  python3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hiprt";
  version = "3.2.0.ccf3068";

  src = fetchFromGitHub {
    owner = "GPUOpen-LibrariesAndSDKs";
    repo = "HIPRT";
    tag = finalAttrs.version;
    hash = "sha256-MvkIO9wbivG7vhyGCsNdrNuCOVgU783aWXR5vl9/t4M=";
  };

  postPatch = ''
    substituteInPlace contrib/Orochi/contrib/hipew/src/hipew.cpp --replace-fail '"/opt/rocm/hip/lib/' '"${clr}/lib'
    substituteInPlace hiprt/hiprt_libpath.h --replace-fail '"/opt/rocm/hip/lib/' '"${clr}/lib/'
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        'COMMAND ''${CMAKE_CURRENT_SOURCE_DIR}/tools/bakeKernel.sh' \
        'COMMAND bash ''${CMAKE_CURRENT_SOURCE_DIR}/tools/bakeKernel.sh'
  ''
  + ''
    # TODO: below fails to regain parallel execution, it only disables the warning messages about unused -parallel-jobs
    # can be removed when https://github.com/GPUOpen-LibrariesAndSDKs/HIPRT/issues/21 is resloved
    substituteInPlace contrib/Orochi/scripts/kernelCompile.py \
      --replace-fail "-parallel-jobs=15" ""
    substituteInPlace scripts/bitcodes/precompile_bitcode.py \
      --replace-fail "-parallel-jobs=15" ""

    substituteInPlace scripts/bitcodes/compile.py \
      --replace-fail "-parallel-jobs=' + str(parallel_jobs) + '" ""
  '';

  nativeBuildInputs = [
    cmake
    python3
  ];

  buildInputs = [
    clr
  ];

  cmakeFlags = [
    (lib.cmakeBool "BAKE_KERNEL" false)
    (lib.cmakeBool "BAKE_COMPILED_KERNEL" false)
    (lib.cmakeBool "BITCODE" true)
    (lib.cmakeBool "PRECOMPILE" true)
    # needs accelerator
    (lib.cmakeBool "NO_UNITTEST" true)
    (lib.cmakeBool "FORCE_DISABLE_CUDA" true)
  ];

  postInstall = ''
    mv $out/bin $out/lib
    ln -sr $out/lib/libhiprt*64.so $out/lib/libhiprt64.so
    install -v -Dm644 ../scripts/bitcodes/hiprt*_amd_lib_linux.bc $out/lib/
  '';

  meta = {
    homepage = "https://gpuopen.com/hiprt";
    description = "Ray tracing library for HIP";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      mksafavi
    ];
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

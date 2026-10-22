{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  nix-update-script,
  qt6,
  rocprof-trace-decoder,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "rocprof-compute-viewer";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocprof-compute-viewer";
    tag = finalAttrs.version;
    hash = "sha256-pZLolbSnNzFnCOCUqo/UHhQpCiZggh+JA3D+4SbZ4jM=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    rocprof-trace-decoder
  ];

  # tries to use qt_deploy_runtime_dependencies, but wrapQtAppsHook
  # handles that instead
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'install(SCRIPT ''${deploy_script})' ""

    # -static taget is not present in /cmake for rocprof-trace-decoder
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        'target_link_libraries(''${PROJECT_NAME} PRIVATE rocprof-trace-decoder::rocprof-trace-decoder-static)' \
        'target_link_libraries(''${PROJECT_NAME} PRIVATE rocprof-trace-decoder::rocprof-trace-decoder)'
  '';

  cmakeFlags = [
    (lib.cmakeFeature "QT_VERSION_MAJOR" "6")
    (lib.cmakeBool "RCV_DISABLE_OPENGL" true)
    (lib.cmakeFeature "ROCM_PATH" "${rocprof-trace-decoder}")
    (lib.cmakeFeature "TRACE_DECODER_ROOT" "${rocprof-trace-decoder}")
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Visualization tool for AMD GPU thread traces from rocprofv3 --att";
    homepage = "https://github.com/ROCm/rocprof-compute-viewer";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "rocprof-compute-viewer";
  };
})

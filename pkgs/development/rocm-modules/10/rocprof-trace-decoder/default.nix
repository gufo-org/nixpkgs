{
  lib,
  stdenv,
  fetchFromGitHub,
  rocm-comgr,
  rocm-runtime,
  cmake,
  python3,
  nlohmann_json,
  gtest,
}:

stdenv.mkDerivation (finalAttrs: {
  name = "rocprof-trace-decoder";
  version = "10.1";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-systems";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/rocprof-trace-decoder"
      "shared"
    ];
    hash = "sha256-0cbkljtw/gZJwXPUpJuLXpQlXfR/MQgEGbLDsRdzpcw=";
  };

  sourceRoot = "${finalAttrs.src.name}/projects/rocprof-trace-decoder";

  strictDeps = true;

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    rocm-comgr
    rocm-runtime
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTS" finalAttrs.finalPackage.doCheck)
    # requires pyelftools
    (lib.cmakeBool "BUILD_INTEGRATION_TESTS" false)
  ];

  nativeCheckInputs = [
    python3
  ];

  checkInputs = [
    nlohmann_json
    gtest
  ];

  preCheck = ''
    patchShebangs test
  '';

  checkPhase =
    let
      # Sanitize tests fail because the UBSan runtime (__ubsan_vptr_type_cache) is not available for
      # LD_PRELOAD in the sandbox.
      skipPattern = "_sanitize$";
    in
    ''
      runHook preCheck

      ctest --test-dir . --output-on-failure -E '${skipPattern}'

      runHook postCheck
    '';

  doCheck = true;

  meta = {
    description = "Library for decoding ROCm thread trace data";
    homepage = "https://github.com/ROCm/rocm-systems/tree/develop/projects/rocprof-trace-decoder";
    license = lib.licenses.mit;
    teams = [ lib.teams.rocm ];
    platforms = lib.platforms.linux;
  };
})

{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmUpdateScript,
  cmake,
  pkg-config,
  libdrm,
  libmnl,
  libnl,
  python,
  wrapPython,
  autoPatchelfHook,
}:

let
  esmi_ib_src = fetchFromGitHub {
    owner = "amd";
    repo = "esmi_ib_library";
    # https://github.com/ROCm/rocm-systems/blob/therock-10.0/projects/amdsmi/CMakeLists.txt#L263
    rev = "d494a3194ceb4cc4dbb2debf9fcbe8773c6d3bef";
    hash = "sha256-StSYzyIujaH8UJIRpfJC0lf+oVT9fWflJgQONvRqu70=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "amdsmi";
  version = "10.1";
  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "rocm-systems";
    tag = "therock-${finalAttrs.version}";
    sparseCheckout = [
      "projects/amdsmi"
      "shared"
    ];
    hash = "sha256-CmCVPmqgU0HtqIBuJUs+Nr7LRKtngOaNNsWFek9Nino=";
  };
  sourceRoot = "${finalAttrs.src.name}/projects/amdsmi";

  postPatch = ''
    # Manually unpack esmi_ib_src and add amd_hsmp.h so execute-process git clone doesn't run
    cp -rf --no-preserve=mode ${esmi_ib_src} ./esmi_ib_library
    mkdir -p ./esmi_ib_library/include/asm
    cp ./include/amd_smi/impl/amd_hsmp.h ./esmi_ib_library/include/asm/amd_hsmp.h
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    wrapPython
    autoPatchelfHook
  ];

  buildInputs = [
    libdrm
    libmnl
    libnl
  ];

  cmakeFlags = [
    # Manually define CMAKE_INSTALL_<DIR>
    # See: https://github.com/NixOS/nixpkgs/pull/197838
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
  ];

  postInstall = ''
    mkdir -p $out/${python.sitePackages}
    ln -s $out/share/amd_smi/amdsmi $out/${python.sitePackages}/amdsmi

    makeWrapperArgs=(--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libdrm ]})
    wrapPythonProgramsIn $out
    rm $out/bin/amd-smi
    ln -sf $out/libexec/amdsmi_cli/amdsmi_cli.py $out/bin/amd-smi
  '';

  passthru.updateScript = rocmUpdateScript { inherit finalAttrs; };

  meta = {
    description = "System management interface for AMD GPUs supported by ROCm";
    homepage = "https://github.com/ROCm/rocm-systems/tree/develop/projects/amdsmi";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ lovesegfault ];
    teams = [ lib.teams.rocm ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "amd-smi";
  };
})

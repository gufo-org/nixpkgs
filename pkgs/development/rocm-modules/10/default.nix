{
  lib,
  config,
  callPackage,
  newScope,
  #boost179,
  #opencv,
  python3Packages,
  #openmpi,
  stdenv,
  pkgs,
}:

let
  outer = lib.makeScope newScope (
    self:
    let
      inherit (self) llvm;
      origStdenv = stdenv;
      pyPackages = python3Packages;
      #openmpi-orig = openmpi;
      rocmClangStdenv = llvm.rocmClangStdenv;
    in
    ## update script ##
    {
      rocmUpdateScript = self.callPackage ./update.nix { };
    }
    ## ROCm Compiler and dependencies ##
    // {
      inherit rocmClangStdenv;
      stdenv = rocmClangStdenv;

      rocm-device-libs = self.callPackage ./rocm-device-libs { };

      llvm = lib.recurseIntoAttrs (
        callPackage ./llvm/default.nix {
          # rocm-device-libs is used for .src only
          # otherwise would cause infinite recursion
          rocm-device-libs-src = self.rocm-device-libs.src;
        }
      );
      inherit (self.llvm) rocm-toolchain clang openmp;
    }
    ## clr ##
    // {
      rocm-cmake = self.callPackage ./rocm-cmake { stdenv = origStdenv; };

      # TODO: reintroduce isa compatibility patch?
      rocm-comgr = self.callPackage ./rocm-comgr { };

      rocm-core = self.callPackage ./rocm-core { stdenv = origStdenv; };

      rocminfo = self.callPackage ./rocminfo { stdenv = origStdenv; };

      rocprofiler-register = self.callPackage ./rocprofiler-register {
        inherit (llvm) clang;
      };

      rocm-runtime = self.callPackage ./rocm-runtime {
        stdenv = origStdenv;
      };

      rocm-smi = pyPackages.callPackage ./rocm-smi {
        inherit (self) rocmUpdateScript;
      };

      roctracer = self.callPackage ./roctracer { };

      hip-common = self.callPackage ./hip-common { };

      hipcc = self.callPackage ./hipcc { stdenv = origStdenv; };

      # TODO: impure-test opencl-cts and spriv fail on master
      clr = self.callPackage ./clr { };
    }
    ## packages ##
    // {

      #amdsmi = pyPackages.callPackage ./amdsmi {
      #  inherit (self) rocmUpdateScript;
      #};

      #aqlprofile = self.callPackage ./aqlprofile { };

      #rdc = self.callPackage ./rdc { };

      #rocm-docs-core = python3Packages.callPackage ./rocm-docs-core { };

      #aotriton = self.callPackage ./aotriton { stdenv = origStdenv; };

      #hipify = self.callPackage ./hipify {
      #  stdenv = origStdenv;
      #};

      ## hsakmt was merged into rocm-runtime
      #hsakmt = self.rocm-runtime;

      #rocprofiler = self.callPackage ./rocprofiler {
      #  inherit (llvm) clang;
      #};
      #rocprofiler-sdk = self.callPackage ./rocprofiler-sdk { };

      #rocprof-compute-viewer = self.callPackage ./rocprof-compute-viewer { };

      #rocprof-trace-decoder = self.callPackage ./rocprof-trace-decoder { };

      #rocgdb = self.callPackage ./rocgdb { };

      #rocdbgapi = self.callPackage ./rocdbgapi { };

      #rocr-debug-agent = self.callPackage ./rocr-debug-agent { };

      #rocprim = self.callPackage ./rocprim { };

      #rocsparse = self.callPackage ./rocsparse { };

      #rocthrust = self.callPackage ./rocthrust { };

      #rocrand = self.callPackage ./rocrand { };

      #hiprand = self.callPackage ./hiprand { };

      #rocfft = self.callPackage ./rocfft { };

      #mscclpp = self.callPackage ./mscclpp { };

      #rccl = self.callPackage ./rccl { };

      #rocshmem = self.callPackage ./rocshmem { };

      #hipcub = self.callPackage ./hipcub { };

      #hipsparse = self.callPackage ./hipsparse { };

      #hipfort = self.callPackage ./hipfort { };

      #hipfft = self.callPackage ./hipfft { };

      #hiprt = self.callPackage ./hiprt { };

      #tensile = pyPackages.callPackage ./tensile {
      #  inherit (self)
      #    rocmUpdateScript
      #    clr
      #    ;
      #};

      #rocblas = self.callPackage ./rocblas { };

      #rocsolver = self.callPackage ./rocsolver { };

      #rocwmma = self.callPackage ./rocwmma { };

      #rocalution = self.callPackage ./rocalution { };

      #rocmlir-rock = self.callPackage ./rocmlir {
      #  buildRockCompiler = true;
      #};
      #rocmlir = self.rocmlir-rock;

      #hipsolver = self.callPackage ./hipsolver { };

      #hipblas-common = self.callPackage ./hipblas-common { };

      #hipblas = self.callPackage ./hipblas { };

      #hipblaslt = self.callPackage ./hipblaslt { };

      #hipsparselt = self.callPackage ./hipsparselt { };

      #composable_kernel_base = self.callPackage ./composable_kernel/base.nix { };
      #composable_kernel = self.callPackage ./composable_kernel { };

      #ck4inductor = pyPackages.callPackage ./composable_kernel/ck4inductor.nix {
      #  inherit (self) composable_kernel rocm-toolchain;
      #};

      #half = self.callPackage ./half { };

      #miopen = self.callPackage ./miopen {
      #  boost = boost179.override { enableStatic = true; };
      #};

      #miopen-hip = self.miopen;

      #migraphx = self.callPackage ./migraphx { stdenv = origStdenv; };

      #rpp = self.callPackage ./rpp { };

      #rpp-hip = self.rpp.override { useCPU = false; };

      #rpp-cpu = self.rpp.override { useCPU = true; };

      #mivisionx = self.callPackage ./mivisionx {
      #  stdenv = origStdenv;
      #  opencv = opencv.override { enablePython = true; };
      #};

      #mivisionx-hip = self.mivisionx.override {
      #  rpp = self.rpp-hip;
      #  useOpenCL = false;
      #  useCPU = false;
      #};

      #mivisionx-cpu = self.mivisionx.override {
      #  rpp = self.rpp-cpu;
      #  useOpenCL = false;
      #  useCPU = true;
      #};

      ## Even if config.rocmSupport is false we need rocmSupport true
      ## version of ucc/ucx in openmpi in this package set
      #openmpi = openmpi-orig.override (
      #  prev:
      #  let
      #    ucx = prev.ucx.override {
      #      enableCuda = false;
      #      enableRocm = true;
      #      rocmPackages = self;
      #    };
      #  in
      #  {
      #    inherit ucx;
      #    ucc = prev.ucc.override {
      #      enableCuda = false;
      #      inherit ucx;
      #    };
      #  }
      #);
      #mpi = self.openmpi;

      meta = {
        # eval all pkgsRocm release attrs with
        # nix-eval-jobs --force-recurse pkgs/top-level/release.nix -I . --select "p: p.pkgsRocm" --no-instantiate
        release-packagePlatforms =
          let
            platforms = [
              "x86_64-linux"
            ];
            attrPaths = (builtins.fromJSON (builtins.readFile ./release-attrPaths.json)).attrPaths;
          in
          lib.foldl' (
            acc: path:
            if lib.hasAttrByPath (lib.splitString "." path) pkgs then
              lib.recursiveUpdate acc (lib.setAttrByPath (lib.splitString "." path) platforms)
            else
              acc
          ) { } attrPaths;
      };

      #rocm-bandwidth-test = self.callPackage ./rocm-bandwidth-test {
      #  rocmPackages = self;
      #};

      #rocm-tests = self.callPackage ./rocm-tests {
      #  rocmPackages = self;
      #};
    }
    ## legacy aliases ##
    // lib.optionalAttrs config.allowAliases {
      rpp-opencl = throw ''
        'rpp-opencl' has been removed as it has been broken for a year and has no consuming packages.
        Use 'rpp' or 'rpp-cpu' instead.
      ''; # Added 2026-03-08

      rocmPath = throw ''
        'rocm-path' has been removed. If a ROCM_PATH value is required in nixpkgs please
        construct one with the minimal set of required deps.
        For convenience use outside of nixpkgs consider one of the entries in
        'rocmPackages.meta'.
      ''; # Added 2025-09-30

      rocm-merged-llvm = throw ''
        'rocm-merged-llvm' has been removed.
        For 'libllvm' or 'libclang' use 'rocmPackages.llvm.libllvm/clang'.
        For a ROCm compiler toolchain use 'rocmPackages.rocm-toolchain'.
        If a package uses '$<TARGET_FILE:clang>' in CMake from 'libclang'
        it may be necessary to convince it to use 'rocm-toolchain' instead.
        'rocm-merged-llvm' avoided this at the cost of significantly bloating closure
        size.
      ''; # Added 2025-09-30

      hsa-amd-aqlprofile-bin = lib.warn ''
        'hsa-amd-aqlprofile-bin' has been replaced by 'aqlprofile'.
      '' self.aqlprofile; # Added 2025-08-27

      triton = throw ''
        'rocmPackages.triton' has been removed. Please use python3Packages.triton
      ''; # Added 2025-08-24

      rocm-thunk = throw ''
        'rocm-thunk' has been removed. It's now part of the ROCm runtime.
      ''; # Added 2025-3-16

      clang-ocl = throw ''
        'clang-ocl' has been deprecated upstream. Use ROCm's clang directly.
      ''; # Added 2025-3-16

      miopengemm = throw ''
        'miopengemm' has been deprecated.
      ''; # Added 2024-3-3

      miopen-opencl = throw ''
        'miopen-opencl' has been deprecated.
      ''; # Added 2024-3-3

      mivisionx-opencl = throw ''
        'mivisionx-opencl' has been deprecated.
        Other versions of mivisionx are still available.
      ''; # Added 2024-3-24
    }
  );
  scopeForArches =
    arches:
    outer.overrideScope (
      _final: prev: {
        clr = prev.clr.override {
          localGpuTargets = arches;
        };
      }
    );
in
outer
// lib.genAttrs outer.clr.gpuTargets (arch: scopeForArches [ arch ])
// {
  # TODO revisit in both 10 and 7
  # list is present in ~4? copies and separately in clr
  # https://github.com/NixOS/nixpkgs/commit/b17c41cc49a6cdf0364c48d55e2d69dc309b0c41
  # list matches while 7 included gfx versions not in the upstream list
  # https://rocm.docs.amd.com/en/docs-10.0.0/compatibility/compatibility-matrix.html?fam=instinct&gpu=amd-instinct-mi355x&os=ubuntu&gfx=gfx950
  gfx9 = scopeForArches [
    "gfx908"
    "gfx90a"
    "gfx942"
    "gfx950"
  ];
  gfx10 = scopeForArches [
    "gfx1030"
  ];
  gfx11 = scopeForArches [
    "gfx1100"
    "gfx1101"
    "gfx1102"
    "gfx1103"
    "gfx1150"
    "gfx1151"
    "gfx1152"
    "gfx1153"
  ];
  gfx12 = scopeForArches [
    "gfx1200"
    "gfx1201"
  ];
}

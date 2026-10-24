{
  lib,
  clr,
  composable_kernel_base,
}:

# TODO:
# https://github.com/ROCm/rocm-libraries/blob/therock-10.0/projects/composablekernel/Config.cmake.in
# https://github.com/ROCm/rocm-libraries/blob/6b41317a1b88c2f16d3576612fb947cf62908836/projects/composablekernel/library/src/tensor_operation_instance/gpu/CMakeLists.txt#L145C1-L151C1
# what to do with these:
# device_contraction_operations
# device_conv_operations "umbrella"
# device_mha_operations
# device_other_operations
# device_reduction_operations

# Notes on names:
# https://github.com/ROCm/rocm-libraries/pull/5945 split out instances used by multiple layouts into separate folders
# where the make target used to be 'device_{folder}_instance' in some cases it is now 'device_{folder}_{layout}_instance'
# miOpenReqLibsOnly layouts include only 'nhwgc' and 'ndhwgc' as of 10.0.
let
  inherit (composable_kernel_base) miOpenReqLibsOnly dlKernels;
  parts = {
    # will fail to find targets if there are no gfx9* targets in the list
    _mha = {
      enabled = !miOpenReqLibsOnly;
      # mha takes ~3hrs on 64 cores on an EPYC milan system at ~2.5GHz
      # big-parallel builders are one gen newer and clocked ~30% higher but only 24 cores
      # Should be <10h timeout but might be cutting it close
      # TODO: work out how to split this into smaller chunks instead of all 3k mha instances together
      # mha_0,1,2, search ninja target file for the individual instances, split by the index?
      # TODO: can we prune the generated instances down to only what in practice are used with popular models
      # when using flash-attention + MHA kernels?
      targets = [
        "device_mha_instance"
      ];
      extraCmakeFlags = [ "-DHIP_CLANG_NUM_PARALLEL_JOBS=2" ];
      onlyFor = [
        "gfx942"
        "gfx950"
        "gfx90a"
      ];
    };

    # custom targets see:
    # https://github.com/ROCm/rocm-libraries/blob/therock-10.0/projects/composablekernel/library/src/tensor_operation_instance/gpu/CMakeLists.txt
    gemm_multiply_multiply = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_multiply_multiply_instance"
      ];
      extraCmakeFlags = [ "-DHIP_CLANG_NUM_PARALLEL_JOBS=2" ];
      onlyFor = [
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
      ];
    };
    gemm_multiply_multiply_wp = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_multiply_multiply_wp_instance"
        "device_gemm_universal_preshuffle_instance"
      ];
      extraCmakeFlags = [ "-DHIP_CLANG_NUM_PARALLEL_JOBS=2" ];
      onlyFor = [
        "gfx942"
        "gfx950"
        "gfx1200"
        "gfx1201"
      ];
    };
    gemm_ab_scale = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_ab_scale_instance"
        "device_gemm_blockscale_wp_instance"
      ];
      onlyFor = [
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
      ];
    };
    gemm_mx = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_mx_instance"
      ];
      onlyFor = [
        "gfx950"
      ];
    };
    contraction = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_contraction_bilinear_instance"
        "device_contraction_scale_instance"
      ];
      onlyFor = [
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
      ];
    };
    gemm_bilinear = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_bilinear_instance"
      ];
      onlyFor = [
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
      ];
    };
    grouped_conv_bwd1 = {
      targets = [
        "device_grouped_conv2d_bwd_data_nhwgc_instance"
        "device_grouped_conv2d_bwd_weight_nhwgc_instance"
      ];
    };
    grouped_conv_bwd2= {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_grouped_conv1d_bwd_weight_gnwc_instance"
        "device_grouped_conv2d_bwd_data_gnhwc_instance"
        "device_grouped_conv2d_bwd_data_ngchw_instance"
        "device_grouped_conv2d_bwd_weight_gnhwc_instance"
        "device_grouped_conv2d_bwd_weight_ngchw_instance"
      ];
    };
    grouped_conv_fwd1= {
      targets = [
        "device_grouped_conv2d_fwd_bias_bnorm_clamp_nhwgc_instance"
        "device_grouped_conv2d_fwd_bias_clamp_nhwgc_instance"
        "device_grouped_conv2d_fwd_clamp_nhwgc_instance"
        "device_grouped_conv2d_fwd_dynamic_op_nhwgc_instance"
        "device_grouped_conv2d_fwd_nhwgc_instance"
      ];
    };
    grouped_conv_fwd2 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_grouped_conv1d_fwd_gnwc_instance"
        "device_grouped_conv2d_fwd_gnhwc_instance"
        "device_grouped_conv2d_fwd_ngchw_instance"
      ];
    };

    grouped_conv_bwd_3d1 = {
      targets = [
        "device_grouped_conv3d_bwd_data_bilinear_ndhwgc_instance"
        "device_grouped_conv3d_bwd_data_ndhwgc_instance"
        "device_grouped_conv3d_bwd_data_scale_ndhwgc_instance"
      ];
    };
    grouped_conv_bwd_3d2 = {
      targets = [
        "device_grouped_conv3d_bwd_weight_bilinear_ndhwgc_instance"
        "device_grouped_conv3d_bwd_weight_ndhwgc_instance"
        "device_grouped_conv3d_bwd_weight_scale_ndhwgc_instance"
      ];
    };
    grouped_conv_bwd_3d3 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_grouped_conv3d_bwd_data_gndhwc_instance"
        "device_grouped_conv3d_bwd_data_ngcdhw_instance"
        "device_grouped_conv3d_bwd_weight_gndhwc_instance"
        "device_grouped_conv3d_bwd_weight_ngcdhw_instance"
      ];
    };
    grouped_conv_fwd_3d1 = {
      targets = [
        "device_grouped_conv3d_fwd_bias_bnorm_clamp_ndhwgc_instance"
        "device_grouped_conv3d_fwd_bias_clamp_ndhwgc_instance"
        "device_grouped_conv3d_fwd_bilinear_ndhwgc_instance"
        "device_grouped_conv3d_fwd_clamp_ndhwgc_instance"
        "device_grouped_conv3d_fwd_convinvscale_ndhwgc_instance"
        "device_grouped_conv3d_fwd_convscale_add_ndhwgc_instance"
        "device_grouped_conv3d_fwd_convscale_ndhwgc_instance"
        "device_grouped_conv3d_fwd_ndhwgc_instance"
      ];
    };
    grouped_conv_fwd_3d2 = {
      targets = [
        "device_grouped_conv3d_fwd_convscale_relu_ndhwgc_instance"
        "device_grouped_conv3d_fwd_dynamic_op_ndhwgc_instance"
        "device_grouped_conv3d_fwd_scale_ndhwgc_instance"
        "device_grouped_conv3d_fwd_scaleadd_ab_ndhwgc_instance"
        "device_grouped_conv3d_fwd_scaleadd_scaleadd_relu_ndhwgc_instance"
      ];
    };
    grouped_conv_fwd_3d3 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_grouped_conv3d_fwd_gndhwc_instance"
        "device_grouped_conv3d_fwd_ngcdhw_instance"
      ];
    };
    grouped_conv_fwd_nd = {
      targets = [
        "device_grouped_convnd_bwd_weight_instance"
      ];
    };
    batched_gemm1 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_batched_gemm_instance"
        "device_batched_gemm_b_scale_instance"
        "device_batched_gemm_multi_d_instance"
        "device_batched_gemm_add_relu_gemm_add_instance"
        "device_batched_gemm_bias_permute_instance"
        "device_batched_gemm_gemm_instance"
        "device_batched_gemm_reduce_instance"
        "device_batched_gemm_softmax_gemm_instance"
      ];
    };
    batched_gemm2 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_batched_gemm_softmax_gemm_permute_instance"
        "device_grouped_gemm_instance"
        "device_grouped_gemm_bias_instance"
        "device_grouped_gemm_fastgelu_instance"
        "device_grouped_gemm_fixed_nk_instance"
        "device_grouped_gemm_fixed_nk_multi_abd_instance"
        "device_grouped_gemm_tile_loop_instance"
      ];
    };
    gemm_universal1 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_universal_instance"
        "device_gemm_universal_batched_instance"
      ];
    };
    gemm_universal2 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_universal_reduce_instance"
      ];
    };
    gemm_other1 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_instance"
        "device_gemm_b_scale_instance"
        "device_gemm_add_instance"
        "device_gemm_add_add_fastgelu_instance"
        "device_gemm_add_fastgelu_instance"
        "device_gemm_add_multiply_instance"
        "device_gemm_add_relu_instance"
      ];
    };
    gemm_other2 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_gemm_add_relu_add_layernorm_instance"
        "device_gemm_add_silu_instance"
        "device_gemm_bias_add_reduce_instance"
        "device_gemm_fastgelu_instance"
        "device_gemm_multi_abd_instance"
        "device_gemm_multiply_add_instance"
        "device_gemm_reduce_instance"
        "device_gemm_splitk_instance"
      ];
    };
    conv = {
      targets = [
        "device_conv1d_bwd_data_instance"
        "device_conv2d_bwd_data_instance"
        "device_conv2d_fwd_instance"
        "device_conv2d_fwd_bias_relu_instance"
        "device_conv2d_fwd_bias_relu_add_instance"
        "device_conv3d_bwd_data_instance"
      ];
    };
    pool = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_avg_pool2d_bwd_instance"
        "device_avg_pool3d_bwd_instance"
        "device_pool2d_fwd_instance"
        "device_pool3d_fwd_instance"
        "device_max_pool_bwd_instance"
      ];
    };
    other0 = {
      targets = [
        "device_quantization_instance"
      ];
    };
    other1 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_batchnorm_instance"
        "device_contraction_bilinear_instance"
        "device_contraction_scale_instance"
        "device_elementwise_instance"
        "device_elementwise_normalization_instance"
      ];
    };
    other2 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_column_to_image_instance"
        "device_image_to_column_instance"
        "device_permute_scale_instance"
        "device_reduce_instance"
      ];
    };
    other3 = {
      enabled = !miOpenReqLibsOnly;
      targets = [
        "device_normalization_bwd_data_instance"
        "device_normalization_bwd_gamma_beta_instance"
        "device_normalization_fwd_instance"
        "device_softmax_instance"
        "device_transpose_instance"
      ];
    };
    dl_kernels= {
      enabled = dlKernels;
      targets = [
        "device_batched_gemm_multi_d_instance"
        "device_grouped_conv1d_bwd_weight_gnwc_instance"
        "device_grouped_conv1d_bwd_weight_nwgc_instance"
        "device_grouped_conv2d_bwd_weight_nhwgc_instance"
        "device_grouped_conv2d_bwd_weight_gnhwc_instance"
        "device_grouped_conv2d_bwd_weight_ngchw_instance"
        "device_grouped_conv3d_bwd_weight_ndhwgc_instance"
        "device_grouped_conv3d_bwd_weight_gndhwc_instance"
        "device_grouped_conv3d_bwd_weight_ngcdhw_instance"
      ];
    };
  };
  tensorOpBuilder =
    {
      part,
      targets,
      extraCmakeFlags ? [ ],
      requiredSystemFeatures ? [ "big-parallel" ],
      enabled ? true,
      onlyFor ? [ ],
    }:
    let
      supported =
        enabled
        && (onlyFor == [ ] || (lib.lists.intersectLists composable_kernel_base.gpuTargets onlyFor) != [ ]);
    in
    if supported then
      (composable_kernel_base.overrideAttrs (old: {
        inherit requiredSystemFeatures;
        pname = "composable_kernel${clr.gpuArchSuffix}-${part}";
        makeTargets = targets;
        preBuild = ''
          echo "Building ${part}"
          makeFlagsArray+=($makeTargets)
          substituteInPlace $(find ./ -name "Makefile" -type f) \
            --replace-fail '.NOTPARALLEL:' '.UNUSED_NOTPARALLEL:'
        '';

        # Compile parallelism adjusted based on available RAM
        # Never uses less than NIX_BUILD_CORES/4, never uses more than NIX_BUILD_CORES
        # CK uses an unusually high amount of memory per core in the build step
        # Nix/nixpkgs doesn't really have any infra to tell it that this build is unusually memory hungry
        # So, bodge. Otherwise you end up having to build all of ROCm with a low core limit when
        # it's only this package that has trouble.
        preConfigure = old.preConfigure or "" + ''
          # clang 24 forwards NIX_LDFLAGS to the HIP device linker, so the
          # cc-wrapper's "-rpath $out/lib" ends up in each part's compressed
          # .hip_fatbin, where it can't be scrubbed, and becomes a disallowed
          # reference from the final CK. The parts only emit .o files, so drop it.
          for _v in NIX_LDFLAGS ''${!NIX_LDFLAGS_*}; do
            printf -v "$_v" '%s' "$(sed "s| *-rpath $out/lib||g" <<< "''${!_v-}")"
            export "$_v"
          done

          MEM_GB_TOTAL=$(awk '/MemTotal/ { printf "%d \n", $2/1024/1024 }' /proc/meminfo)
          MEM_GB_AVAILABLE=$(awk '/MemAvailable/ { printf "%d \n", $2/1024/1024 }' /proc/meminfo)
          APPX_GB=$((MEM_GB_AVAILABLE > MEM_GB_TOTAL ? MEM_GB_TOTAL : MEM_GB_AVAILABLE))
          MAX_CORES=$((1 + APPX_GB/3))
          MAX_CORES=$((MAX_CORES < NIX_BUILD_CORES/3 ? NIX_BUILD_CORES/3 : MAX_CORES))
          export NIX_BUILD_CORES="$((NIX_BUILD_CORES > MAX_CORES ? MAX_CORES : NIX_BUILD_CORES))"
          echo "Picked new core limit NIX_BUILD_CORES=$NIX_BUILD_CORES based on available mem: $APPX_GB GB"
          cmakeFlagsArray+=(
            "-DCK_PARALLEL_COMPILE_JOBS=$NIX_BUILD_CORES"
          )
        '';
        cmakeFlags = old.cmakeFlags ++ extraCmakeFlags;
        # Early exit after build phase with success, skips fixups etc
        # Will get copied back into /build of the final CK
        postBuild = ''
          find . -name "*.o" -type f | while read -r file; do
            mkdir -p "$out/$(dirname "$file")"
            cp --reflink=auto "$file" "$out/$file"
          done
          exit 0
        '';
        meta = old.meta // {
          broken = false;
        };
      }))
    else
      null;
  composable_kernel_parts = builtins.mapAttrs (
    part: targets: tensorOpBuilder (targets // { inherit part; })
  ) parts;
in

composable_kernel_base.overrideAttrs (
  finalAttrs: old: {
    pname = "composable_kernel${clr.gpuArchSuffix}";
    parts_dirs = builtins.filter (x: x != null) (builtins.attrValues composable_kernel_parts);
    disallowedReferences = builtins.filter (x: x != null) (builtins.attrValues composable_kernel_parts);
    preBuild = ''
      for dir in $parts_dirs; do
        find "$dir" -type f -name "*.o" | while read -r file; do
          # Extract the relative path by removing the output directory prefix
          rel_path="''${file#"$dir/"}"

          # Create parent directory if it doesn't exist
          mkdir -p "$(dirname "$rel_path")"

          # Copy the file back to its original location, give it a future timestamp
          # so make treats it as up to date
          cp --reflink=auto --no-preserve=all "$file" "$rel_path"
          touch -d "now +10 hours" "$rel_path"
        done
      done
    '';
    passthru = old.passthru // {
      parts = composable_kernel_parts;
    };
    meta = old.meta // {
      # Builds without any gfx9 fail
      broken = !finalAttrs.passthru.anySupportedGfxTarget;
    };
  }
)

{
  lib,
  pkgs,
  stdenv,
  cmake,
}:

stdenv.mkDerivation rec {
  pname = "libdivide";
  version = "5.4.0";

  src = pkgs.fetchFromGitHub {
    owner = "ridiculousfish";
    repo = "libdivide";
    tag = "v${version}";
    hash = "sha256-caEHdgSW3I0onp/XErXtduckpFCXwrcCvMctdtJKfh8=";
  };

  nativeBuildInputs = [ cmake ];

  meta = {
    description = "Fast integer division by constants";
    homepage = "https://github.com/ridiculousfish/libdivide";
    license = [
      lib.licenses.boost
      lib.licenses.zlib
    ];
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}


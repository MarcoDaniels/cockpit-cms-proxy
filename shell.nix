let
  pkgs = import (fetchTarball {
    name = "nixpkgs-22.11-darwin-2023-01-09";
    url = "https://github.com/NixOS/nixpkgs/archive/6713011f9e92.tar.gz";
    sha256 = "0fvz2phhvnh6pwz6bycmlm6wkn5aydpr2bsinw8hmv5hvvcx4hr1";
  }) { };

  rust-toolchain = pkgs.symlinkJoin {
    name = "rust-toolchain";
    paths = [ pkgs.rustc pkgs.cargo pkgs.rustPlatform.rustcSrc ];
  };

in pkgs.mkShell {
  RUST_BACKTRACE = 1;
  buildInputs = [ rust-toolchain pkgs.rustfmt ];
}

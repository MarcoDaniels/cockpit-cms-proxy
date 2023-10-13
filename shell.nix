let
  pkgs = import (fetchTarball {
    name = "nixpkgs-23.05-darwin-2023-10-05";
    url = "https://github.com/NixOS/nixpkgs/archive/1e9c7c0203be.tar.gz";
    sha256 = "10qbybc9k3dj1xap9n0i3z7pc3svzwhclgsyfzzsf8cfh8l518pn";
  }) { };

  inherit (pkgs.lib) optional optionals;

  erlang = pkgs.beam.interpreters.erlangR26;

  gleam = pkgs.stdenv.mkDerivation rec {
    name = "gleam-${version}";
    version = "v0.31.0";
    src = pkgs.fetchurl {
      url = "https://github.com/gleam-lang/gleam/releases/download/${version}/gleam-${version}-x86_64-apple-darwin.tar.gz";
      sha256 = "sha256-Ty7RKPJ9BZ/vE1ILM0J2N6Qv0sqFDJzlyAlYWJTXRbA=";
    };
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      tar -xf $src -C $out/bin
    '';
  };

in pkgs.mkShell rec {
  buildInputs = with pkgs;
  [
    gleam
    erlang
    rebar3
  ];
}

let
  pkgs = import (fetchTarball {
    name = "nixpkgs-22.11-darwin-2023-01-09";
    url = "https://github.com/NixOS/nixpkgs/archive/6713011f9e92.tar.gz";
    sha256 = "0fvz2phhvnh6pwz6bycmlm6wkn5aydpr2bsinw8hmv5hvvcx4hr1";
  }) { };

  start = pkgs.writeShellScriptBin "start" ''
    rm -rf dist/
    ${pkgs.nodePackages.typescript}/bin/tsc -p tsconfig.json
    ${pkgs.nodejs}/bin/node build/index.js
  '';

in pkgs.mkShell {
  buildInputs = [
    pkgs.nixfmt
    start
  ];
}

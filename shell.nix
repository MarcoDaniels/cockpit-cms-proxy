let
  pkgs = import (fetchTarball {
    name = "nixpkgs-22.11-darwin-2023-01-09";
    url = "https://github.com/NixOS/nixpkgs/archive/6713011f9e92.tar.gz";
    sha256 = "0fvz2phhvnh6pwz6bycmlm6wkn5aydpr2bsinw8hmv5hvvcx4hr1";
  }) { };

  startDev = pkgs.writeShellScriptBin "startDev" ''
    rm -rf dist
    ${pkgs.elmPackages.elm}/bin/elm make --optimize src/Main.elm --output=dist/elm.js
    cp src/index.js dist/index.js
    ${pkgs.nodejs-18_x}/bin/node ./dist/index.js $1
  '';

in pkgs.mkShell {
  buildInputs = [
    pkgs.nodejs-18_x
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-test
    pkgs.elm2nix

    startDev
  ];
}

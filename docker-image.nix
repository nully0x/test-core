{ pkgs ? import <nixpkgs> {} }:

let
  rustOverlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");
  pkgs = import <nixpkgs> { overlays = [ rustOverlay ]; };
  rust = pkgs.rust-bin.stable."1.80.0".default;

  hxckr-core = pkgs.rustPlatform.buildRustPackage {
    pname = "hxckr-core";
    version = "0.1.0";
    src = ./.;
    cargoLock.lockFile = ./Cargo.lock;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl pkgs.postgresql ];
  };

  entrypoint-script = pkgs.writeScriptBin "entrypoint.sh" (builtins.readFile ./entrypoint.dev.sh);

  app-dir = pkgs.runCommand "app-dir" {} ''
    mkdir -p $out/app/migrations
    cp -r ${./migrations}/* $out/app/migrations/
    cp ${entrypoint-script}/bin/entrypoint.sh $out/app/
    chmod +x $out/app/entrypoint.sh
  '';

in
pkgs.dockerTools.buildImage {
  name = "hxckr-core";
  tag = "latest";

  contents = [
    hxckr-core
    pkgs.diesel-cli
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.openssl
    pkgs.postgresql
    pkgs.cacert
    pkgs.libiconv
    app-dir
  ];

  config = {
    Cmd = [ "/app/entrypoint.sh" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PATH=/bin:${hxckr-core}/bin:${pkgs.diesel-cli}/bin:${pkgs.findutils}/bin"
      "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.openssl
        pkgs.postgresql
        pkgs.libiconv
      ]}"
    ];
    WorkingDir = "/app";
    ExposedPorts = {
      "4925/tcp" = {};
    };
  };
}

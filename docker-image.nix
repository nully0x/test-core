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

    nativeBuildInputs = [ pkgs.pkg-config pkgs.cargo-chef ];
    buildInputs = [ pkgs.openssl pkgs.postgresql ];

    # Use cargo-chef to optimize the build
    buildPhase = ''
      cargo chef prepare
      cargo chef cook --release
      cargo build --release
    '';
  };

  entrypoint-script = ./entrypoint.dev.sh;

in
pkgs.dockerTools.buildLayeredImage {
  name = "hxckr-core";
  tag = "latest";
  created = "now";

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
  ];

  extraCommands = ''
    mkdir -p app/migrations
    cp -r ${./migrations}/* app/migrations/
    cp ${entrypoint-script} app/entrypoint.sh
    chmod +x app/entrypoint.sh
  '';

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

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
    buildInputs = [ pkgs.openssl pkgs.libiconv];

    # Optimize the build
    RUSTFLAGS = "-C target-cpu=native -C opt-level=3";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
    CARGO_PROFILE_RELEASE_PANIC = "abort";
    CARGO_PROFILE_RELEASE_INCREMENTAL = "false";
    CARGO_PROFILE_RELEASE_DEBUG = "0";

    # Use all available cores
    NIX_BUILD_CORES = 0;
    preBuild = ''
      export CARGO_BUILD_JOBS=$NIX_BUILD_CORES
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
    pkgs.openssl
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
      "PATH=/bin:${hxckr-core}/bin:${pkgs.diesel-cli}/bin"
      "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.openssl
        pkgs.libiconv
      ]}"
    ];
    WorkingDir = "/app";
    ExposedPorts = {
      "4925/tcp" = {};
    };
  };
}

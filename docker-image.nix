{ pkgs ? import <nixpkgs> {} }:

let
  rustOverlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");
  pkgs = import <nixpkgs> { overlays = [ rustOverlay ]; };
  rust = pkgs.rust-bin.stable."1.80.0".default;

  buildFor = system:
    let
      pkgsCross = import <nixpkgs> {
        system = "x86_64-linux";
        crossSystem = pkgs.lib.systems.elaborate system;
        overlays = [ rustOverlay ];
      };
    in pkgsCross.rustPlatform.buildRustPackage {
      pname = "hxckr-core";
      version = "0.1.0";
      src = ./.;
      cargoLock.lockFile = ./Cargo.lock;

      nativeBuildInputs = [ pkgsCross.pkg-config ];
      buildInputs = [ pkgsCross.openssl pkgsCross.postgresql ];

      doCheck = false;

      RUSTFLAGS = "-C target-cpu=generic -C opt-level=3";
      CARGO_PROFILE_RELEASE_LTO = "thin";
      CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
      CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
      CARGO_PROFILE_RELEASE_PANIC = "abort";
      CARGO_PROFILE_RELEASE_INCREMENTAL = "false";
      CARGO_PROFILE_RELEASE_DEBUG = "0";

      stripAllList = [ "bin" ];

      NIX_BUILD_CORES = 0;
      preBuild = ''
        export CARGO_BUILD_JOBS=$NIX_BUILD_CORES
      '';
    };

  hxckr-core-amd64 = buildFor "x86_64-linux";
  hxckr-core-arm64 = buildFor "aarch64-linux";

  entrypoint-script = ./entrypoint.dev.sh;

  buildImage = arch: hxckr-core:
    pkgs.dockerTools.buildLayeredImage {
      name = "hxckr-core";
      tag = "${arch}-latest";
      created = "now";

      contents = [
        hxckr-core
        pkgs.diesel-cli
        pkgs.bash
        pkgs.coreutils
        pkgs.findutils
        pkgs.openssl
        pkgs.postgresql.lib
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
            pkgs.postgresql.lib
            pkgs.libiconv
          ]}"
        ];
        WorkingDir = "/app";
        ExposedPorts = {
          "4925/tcp" = {};
        };
      };
    };
in
{
  amd64 = buildImage "amd64" hxckr-core-amd64;
  arm64 = buildImage "arm64" hxckr-core-arm64;
}

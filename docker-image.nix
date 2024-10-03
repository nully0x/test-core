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

  diesel-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "diesel_cli";
    version = "2.2.4";
    src = pkgs.fetchFromGitHub {
      owner = "diesel-rs";
      repo = "diesel";
      rev = "v2.2.4";
      sha256 = "sha256-zS3MxI1cj6r0UGdlmtDu0aTBmjbHLz+BdogS2vFQAKo=";
    };
    cargoLock.lockFile = ./Cargo.lock;
    buildFeatures = [ "postgres" ];
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl pkgs.postgresql ];
  };

in
pkgs.dockerTools.buildLayeredImage {
  name = "hxckr-core";
  tag = "latest";
  created = "now";

  contents = [
    hxckr-core
    diesel-cli
    pkgs.bash
    pkgs.coreutils
    pkgs.openssl
    pkgs.postgresql
    pkgs.cacert
    pkgs.libiconv
  ];

  config = {
    Cmd = [ "${hxckr-core}/bin/hxckr-core" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PATH=/bin:${hxckr-core}/bin:${diesel-cli}/bin"
      "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
        pkgs.openssl
        pkgs.postgresql
        pkgs.libiconv
      ]}"
    ];
    WorkingDir = "/";
  };
}

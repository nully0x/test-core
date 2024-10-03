{ pkgs ? import <nixpkgs> {} }:

let
  rustOverlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");
  pkgs = import <nixpkgs> { overlays = [ rustOverlay ]; };
  rust = pkgs.rust-bin.stable."1.80.0".default;
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    rust
    pkg-config
    openssl
    postgresql
  ];

  RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";
}

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix";
    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";

    preferred-rust-manifest = {
      # 0.9
      # url = "https://static.rust-lang.org/dist/2023-05-27/channel-rust-nightly.toml";
      url = "https://static.rust-lang.org/dist/2024-11-22/channel-rust-nightly.toml";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, fenix, preferred-rust-manifest, devshell, flake-parts, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [
        "x86_64-linux"
      ];

      perSystem = { pkgs, system, ... }: let
        preferred_rustpkg = (fenix.packages.${system}.fromManifestFile preferred-rust-manifest).withComponents [
          "rust-src"
          "rustc"
          "rustc-dev"
          "llvm-tools"
          "cargo"
        ];
      in {
        devshells.default = {
          env = [
            { name = "LD_LIBRARY_PATH"; value = "${pkgs.stdenv.cc.cc.lib}/lib"; }
          ];

          packages = with pkgs; [
            clang
            libcxx
            preferred_rustpkg
          ];

        };
      };
    };
}

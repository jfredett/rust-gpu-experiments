{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix";
    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # The Rust version to compile the shader crates with
    gpu-rust-manifest = {
      # url = "https://static.rust-lang.org/dist/2023-05-27/channel-rust-nightly.toml";
      url = "https://static.rust-lang.org/dist/2024-11-22/channel-rust-nightly.toml";
      flake = false;
    };

    # The Rust version you want to build your package with.
    preferred-rust-manifest = {
      url = "https://static.rust-lang.org/dist/2025-02-12/channel-rust-nightly.toml";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, fenix, gpu-rust-manifest, preferred-rust-manifest, devshell, flake-parts, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [
        "x86_64-linux"
      ];

      perSystem = { pkgs, system, ... }: let
        gpu_rustpkg = (fenix.packages.${system}.fromManifestFile gpu-rust-manifest).withComponents [
          "rust-src"
          "rustc"
          "rustc-dev"
          "llvm-tools"
          "cargo"
        ];
        preferred_rustpkg = (fenix.packages.${system}.fromManifestFile preferred-rust-manifest).defaultToolchain;
      in {
        # Ideally set a `compilers/` dir with the two rusts in it?
        devshells.default = {
          env = [
            { name = "LD_LIBRARY_PATH"; value = "${pkgs.stdenv.cc.cc.lib}/lib"; }
          ];

          packages = with pkgs; [
            bacon
            clang
            libcxx
            cargo-llvm-cov
            cargo-mutants
            cargo-nextest
            cloc
            gnuplot
            imhex
            just
            linuxKernel.packages.linux_6_6.perf
            mold
            perf-tools
            gpu_rustpkg
          ];

        };
      };
    };
}

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix";
    devenv.url = "github:cachix/devenv";
    rust-manifest = {
      url = "https://static.rust-lang.org/dist/2023-05-27/channel-rust-nightly.toml";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, devenv, fenix, rust-manifest, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = f: builtins.listToAttrs (map (name: { inherit name; value = f name; }) systems);
    in
      {
      packages.x86_64-linux.devenv-up = self.devShells.x86_64-linux.default.config.procfileScript;
      devShells = forAllSystems
        (system: let
          pkgs = import nixpkgs { inherit system; };
          rustpkg = (fenix.packages.${system}.fromManifestFile rust-manifest).minimalToolchain;
        in {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;

            modules = [{
              languages.rust = {
                enable = true;
                mold.enable = true;
              };

              enterShell = ''
                export RUSTGPU_RUSTC=${rustpkg}/bin/rustc
                export RUSTC=scripts/rustc-proxy
              '';


              packages = with pkgs; [
                bacon
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
              ];
            }];
          };
        });
    };
}

# Experimenting with rust-gpu

[In this issue](https://github.com/Rust-GPU/cargo-gpu/issues/44) I ran into some problems due to `rustup` and `nixos`
not really playing nicely together.

This repository is trying to figure those problems out so I can make shaders compile and then maybe do math with them.

This repo contains a flake which:

1. Installs the latest 'nightly' provided by `fenix` to use as the 'normal' rust TC.
2. Grabs a specific nightly from `static.rust-lang.org`, in this case the one needed by rust-gpu to compile the 
    shader magic crate (spirv-builder).

Ideally it will eventually be a flake that -- when you run `cargo build`, just builds everything correctly.

This readme is more of a work log, so I can remember where I left things.

----


# 12-FEB-2025

## 1042

Right now, the place I am stuck is
[here](https://github.com/Rust-GPU/rust-gpu/blob/main/crates/rustc_codegen_spirv/build.rs#L22-L27). In particular, the
crate looks at `RUSTC` and compares it to an expected value. If this preferentially looked for `RUSTGPU_RUSTC` or some
other environment variable, I could set that the environment and then it would also need to set itself to use that RUSTC
for that project only.

I'm going to look through the `cargo-gpu` codebase, as it also must support multiple independent compilation (e.g.,
using nightly for my crate, but old-nightly for the spirv-builder.

I might be able to do this trickery in _my_ `build.rs` file, but I'm not quite sure how to do that, I haven't used
`build.rs` much before.

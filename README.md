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

# 13-FEB-2025

## 1634

I ripped out the `devenv` stuff for unrelated (AI) reasons.

## 2043

I got this sort of almost working, a bit. Here's the progress.


First, it's easy to get multiple different versions of rust via fenix in the flake. I just need to have it link the
executables in the path by some other name, which I'm pretty sure is possible. Once I get that, I need to figure out how
to get _only_ my shader crate to use the specific nightly, while the main crate uses the newer compiler. I think this
comes back to correctly setting `RUSTC` and maybe some other variables only during the `build.rs` stage for
`experiment-1`, which I don't know if dynamically setting a RUSTC while compiling with a RUSTC is possible, but that's
essentially what needs to happen. Alternatively, I could _add_ another env to the rust-gpu side and use that, but I
don't want to start compiling `rust-gpu` until I have to.

Getting the right compiler wasn't the whole problem, beause the `spirv-builder` crate also needs to be compiled with a
particularly old nightly at `0.9`, I tried going to `main` to see if I could get a more recent compiler that avoided the
need for the inline const in `experiment-1`, the consuming crate. This worked, sort of, I grabbed the compiler from
`main`'s toolchain file, but it seems to be missing the `spirv` arch, which I suspect is because there is a step I am
missing that the maintainer's know. This does mean I'm headed in the right direction to some extent, but I think there
is a better way, and that's to just make a flake where `cargo-gpu` works, then I can just re-use the work entirely. This
should be doable via the flake example at the bottom of [this page](https://nixos.wiki/wiki/Rust). I can still use
`fenix` for the main compiler, but this will allow `cargo-gpu` to install via rustup and should allow me to use it. If
not, then I can just fall back to rustup for GPU work, which is perfectly fine for my purposes.

I'm going to commit off this work and try that.


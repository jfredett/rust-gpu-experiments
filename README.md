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


# 14-FEB-2025

## 1202

I believe I got it working with the direct rustup install. I don't love this, because it means that the rust install is
not tied to the flake in any real way. From the above I should be able to at least ameliorate that via a toolchain file,
but it still feels a little lousy.

I think the `fenix` thing could work, but the more I look the more I think it needs to have changes on the
rust-gpu/spirv builder side to accomodate it. If the spirv-builder had some way to specify the compiler it should use at
invoke time, then it would be vanishingly easy to make things work with `fenix`.

I'm going to update my issue with the method I found. I am seeing an issue compiling `clap_lex` on this version, there
appears to be a 3-day-old (at TOW) issue that refers to this, so I think it's a known bug.


# 23-FEB-2025

## 1621

Took a little break to finish up some work on [hazel](https://github.com/jfredett/hazel), with that done I'm back on
this for a bit.

I made the change to update to the `6e2c84d` as suggested in [#44](https://github.com/Rust-GPU/cargo-gpu/issues/44).
Immediately ran into an issue with `bytemuck` having incompatible dependencies:

```shell
 ~/code/rust-gpu-ex :: main ≢  ~4                                                                                                                                                                                                  | 16:13:53 
➜ cargo gpu build shader-1/
🦀 Cloning `rust-gpu` repo...
🦀 Compiling shader-specific `spirv-builder-cli` for ./
    Updating git repository `https://github.com/Rust-GPU/rust-gpu.git`
    Updating crates.io index
error: failed to select a version for `bytemuck`.
    ... required by package `rustc_codegen_spirv v0.9.0 (https://github.com/Rust-GPU/rust-gpu.git?rev=6e2c84d#6e2c84d4)`
    ... which satisfies git dependency `rustc_codegen_spirv` of package `spirv-builder v0.9.0 (https://github.com/Rust-GPU/rust-gpu.git?rev=6e2c84d#6e2c84d4)`
    ... which satisfies git dependency `spirv-builder-pre-cli` of package `spirv-builder-cli v0.1.0 (/home/jfredett/.cache/rust-gpu/spirv-builder-cli/https___github_com_Rust-GPU_rust-gpu_git+6e2c84d+nightly-2024-11-22)`
versions that meet the requirements `^1.20.0` are: 1.21.0, 1.20.0

all possible versions conflict with previously selected packages.

  previously selected package `bytemuck v1.19.0`
    ... which satisfies dependency `bytemuck = "^1.12.3"` (locked to 1.19.0) of package `spirt v0.4.0`
    ... which satisfies dependency `spirt = "^0.4.0"` (locked to 0.4.0) of package `rustc_codegen_spirv v0.9.0 (https://github.com/Rust-GPU/rust-gpu.git?rev=6e2c84d#6e2c84d4)`
    ... which satisfies git dependency `rustc_codegen_spirv` of package `spirv-builder v0.9.0 (https://github.com/Rust-GPU/rust-gpu.git?rev=6e2c84d#6e2c84d4)`
    ... which satisfies git dependency `spirv-builder-pre-cli` of package `spirv-builder-cli v0.1.0 (/home/jfredett/.cache/rust-gpu/spirv-builder-cli/https___github_com_Rust-GPU_rust-gpu_git+6e2c84d+nightly-2024-11-22)`

failed to select a version for `bytemuck` which could resolve this conflict
[2025-02-23T21:15:07Z ERROR cargo_gpu] ...build error!
Error: ...build error!
```

A naive approach (just running `cargo update` and hoping) did not succeed. So I suppose next is to fork and see if I can
resolve the dependencies myself. As far as I can tell, the version requirements are just mismatched (one wants 1.18, one
wants 1.20), so time to patch.


## 1726

After a bit of work (and 3 forks, 2 of which were actually needed), I resolved the `bytemuck` dep issue to be greeted by
an `itoa` issue. I love dependency chasing.

```shell
➜ cargo clean ; cargo gpu build
     Removed 0 files
🦀 Cloning `rust-gpu` repo...
🦀 Compiling shader-specific `spirv-builder-cli` for ./
    Updating git repository `https://github.com/jfredett/rust-gpu.git`
    Updating crates.io index
    Updating git repository `https://github.com/jfredett/spirt`
    Updating git submodule `https://github.com/KhronosGroup/SPIRV-Headers`
error: failed to select a version for `itoa`.
    ... required by package `rustix v0.38.42`
    ... which satisfies dependency `rustix = "^0.38.42"` of package `rustc_codegen_spirv v0.9.0 (https://github.com/jfredett/rust-gpu.git?rev=c20f9357#c20f9357)`
    ... which satisfies git dependency `rustc_codegen_spirv` of package `spirv-builder v0.9.0 (https://github.com/jfredett/rust-gpu.git?rev=c20f9357#c20f9357)`
    ... which satisfies git dependency `spirv-builder-pre-cli` of package `spirv-builder-cli v0.1.0 (/home/jfredett/.cache/rust-gpu/spirv-builder-cli/https___github_com_jfredett_rust-gpu_git+c20f9357+nightly-2024-11-22)`
versions that meet the requirements `^1.0.13` are: 1.0.14, 1.0.13

all possible versions conflict with previously selected packages.

  previously selected package `itoa v1.0.11`
    ... which satisfies dependency `itoa = "^1.0"` (locked to 1.0.11) of package `serde_json v1.0.132`
    ... which satisfies dependency `serde_json = "^1.0.132"` (locked to 1.0.132) of package `spirv-builder-cli v0.1.0 (/home/jfredett/.cache/rust-gpu/spirv-builder-cli/https___github_com_jfredett_rust-gpu_git+c20f9357+nightly-2024-11-22)`

failed to select a version for `itoa` which could resolve this conflict
[2025-02-23T22:26:37Z ERROR cargo_gpu] ...build error!
Error: ...build error!
```

This was an easy resolve since the newer versions of rustix remove the itoa dep entirely.

After getting this sorted, I was able to get the thing to build to the point that I started generating new errors -- and
a lot of them. Most seem to stem from `spirt_passes` somewhere inside the linker of `rustc_codegen_spirv`. Lots of
unresolved imports and the like:

```bash
error[E0432]: unresolved imports `spirt::ControlNodeKind`, `spirt::DataInstFormDef`
 --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/controlflow.rs:7:41
  |
7 |     Attr, AttrSet, ConstDef, ConstKind, ControlNodeKind, DataInstFormDef, DataInstKind, DeclDef,
  |                                         ^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^
  |                                         |                |
  |                                         |                no `DataInstFormDef` in the root
  |                                         |                help: a similar name exists in the module: `DataInstDef`
  |                                         no `ControlNodeKind` in the root

error[E0432]: unresolved imports `spirt::ControlNode`, `spirt::ControlNodeKind`
 --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/debuginfo.rs:9:43
  |
9 |     Attr, AttrSetDef, ConstKind, Context, ControlNode, ControlNodeKind, DataInstKind, InternedStr,
  |                                           ^^^^^^^^^^^  ^^^^^^^^^^^^^^^ no `ControlNodeKind` in the root
  |                                           |
  |                                           no `ControlNode` in the root

error[E0432]: unresolved imports `spirt::ControlNode`, `spirt::ControlNodeKind`, `spirt::DataInstForm`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:13:59
   |
13 |     Attr, AttrSet, AttrSetDef, Const, ConstKind, Context, ControlNode, ControlNodeKind,
   |                                                           ^^^^^^^^^^^  ^^^^^^^^^^^^^^^ no `ControlNodeKind` in the root
   |                                                           |
   |                                                           no `ControlNode` in the root
14 |     DataInstDef, DataInstForm, DataInstKind, Diag, DiagLevel, ExportKey, Exportee, Func, FuncDecl,
   |                  ^^^^^^^^^^^^
   |                  |
   |                  no `DataInstForm` in the root
   |                  help: a similar name exists in the module: `DataInstDef`

error[E0432]: unresolved imports `spirt::ControlNodeKind`, `spirt::ControlRegion`
 --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:4:22
  |
4 | use spirt::{Context, ControlNodeKind, ControlRegion, FuncDefBody, SelectionKind, Value};
  |                      ^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^ no `ControlRegion` in the root
  |                      |
  |                      no `ControlNodeKind` in the root

error[E0432]: unresolved imports `spirt::ControlNode`, `spirt::ControlNodeDef`, `spirt::ControlNodeKind`, `spirt::ControlNodeOutputDecl`, `spirt::ControlRegion`, `spirt::ControlRegionInputDecl`, `spirt::DataInstFormDef`
 --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:7:42
  |
7 |     Const, ConstDef, ConstKind, Context, ControlNode, ControlNodeDef, ControlNodeKind,
  |                                          ^^^^^^^^^^^  ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^ no `ControlNodeKind` in the root
  |                                          |            |
  |                                          |            no `ControlNodeDef` in the root
  |                                          no `ControlNode` in the root
8 |     ControlNodeOutputDecl, ControlRegion, ControlRegionInputDecl, DataInst, DataInstDef,
  |     ^^^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^ no `ControlRegionInputDecl` in the root
  |     |                      |
  |     |                      no `ControlRegion` in the root
  |     no `ControlNodeOutputDecl` in the root
9 |     DataInstFormDef, DataInstKind, EntityOrientedDenseMap, FuncDefBody, SelectionKind, Type,
  |     ^^^^^^^^^^^^^^^ no `DataInstFormDef` in the root
  |
help: a similar name exists in the module
  |
8 |     NodeOutputDecl, ControlRegion, ControlRegionInputDecl, DataInst, DataInstDef,
  |     ~~~~~~~~~~~~~~
help: a similar name exists in the module
  |
8 |     ControlNodeOutputDecl, ControlRegion, RegionInputDecl, DataInst, DataInstDef,
  |                                           ~~~~~~~~~~~~~~~
help: a similar name exists in the module
  |
9 |     DataInstDef, DataInstKind, EntityOrientedDenseMap, FuncDefBody, SelectionKind, Type,
  |     ~~~~~~~~~~~

error[E0432]: unresolved imports `spirt::ControlNode`, `spirt::ControlNodeKind`, `spirt::ControlRegion`, `spirt::DataInstForm`, `spirt::DataInstFormDef`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:15:30
   |
15 |     AttrSet, Const, Context, ControlNode, ControlNodeKind, ControlRegion, DataInstDef,
   |                              ^^^^^^^^^^^  ^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^ no `ControlRegion` in the root
   |                              |            |
   |                              |            no `ControlNodeKind` in the root
   |                              no `ControlNode` in the root
16 |     DataInstForm, DataInstFormDef, DataInstKind, DeclDef, EntityOrientedDenseMap, Func,
   |     ^^^^^^^^^^^^  ^^^^^^^^^^^^^^^ no `DataInstFormDef` in the root
   |     |
   |     no `DataInstForm` in the root
   |
help: a similar name exists in the module
   |
16 |     DataInstDef, DataInstFormDef, DataInstKind, DeclDef, EntityOrientedDenseMap, Func,
   |     ~~~~~~~~~~~
help: a similar name exists in the module
   |
16 |     DataInstForm, DataInstDef, DataInstKind, DeclDef, EntityOrientedDenseMap, Func,
   |                   ~~~~~~~~~~~

error[E0407]: method `in_place_transform_control_node_def` is not a member of trait `Transformer`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/debuginfo.rs:59:5
    |
59  |       fn in_place_transform_control_node_def(
    |       ^  ----------------------------------- help: there is an associated function with a similar name: `in_place_transform_node_def`
    |  _____|
    | |
60  | |         &mut self,
61  | |         mut func_at_control_node: spirt::func_at::FuncAtMut<'_, ControlNode>,
62  | |     ) {
...   |
171 | |         func_at_control_node.inner_in_place_transform_with(self);
172 | |     }
    | |_____^ not a member of trait `Transformer`

error[E0407]: method `visit_data_inst_form_use` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:521:5
    |
521 |       fn visit_data_inst_form_use(&mut self, data_inst_form: DataInstForm) {
    |       ^  ------------------------ help: there is an associated function with a similar name: `visit_data_inst_def`
    |  _____|
    | |
522 | |         // NOTE(eddyb) this contains no deduplication because each `DataInstDef`
523 | |         // will have any diagnostics reported separately.
524 | |         self.visit_data_inst_form_def(&self.cx[data_inst_form]);
525 | |     }
    | |_____^ not a member of trait `Visitor`

error[E0407]: method `visit_control_node_def` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:580:5
    |
580 | /     fn visit_control_node_def(&mut self, func_at_control_node: FuncAt<'a, ControlNode>) {
581 | |         let original_use_stack_len = self.use_stack.len();
582 | |
583 | |         func_at_control_node.inner_visit_with(self);
...   |
604 | |         }
605 | |     }
    | |_____^ not a member of trait `Visitor`

error[E0407]: method `visit_data_inst_form_use` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:217:5
    |
217 |       fn visit_data_inst_form_use(&mut self, data_inst_form: DataInstForm) {
    |       ^  ------------------------ help: there is an associated function with a similar name: `visit_data_inst_def`
    |  _____|
    | |
218 | |         if self.seen_data_inst_forms.insert(data_inst_form) {
219 | |             self.visit_data_inst_form_def(&self.cx[data_inst_form]);
220 | |         }
221 | |     }
    | |_____^ not a member of trait `Visitor`

error[E0407]: method `visit_data_inst_form_use` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:256:9
    |
256 |         fn visit_data_inst_form_use(&mut self, _: DataInstForm) {}
    |         ^^^------------------------^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |         |  |
    |         |  help: there is an associated function with a similar name: `visit_data_inst_def`
    |         not a member of trait `Visitor`

error[E0407]: method `visit_control_region_def` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:260:9
    |
260 |           fn visit_control_region_def(&mut self, func_at_control_region: FuncAt<'a, ControlRegion>) {
    |           ^  ------------------------ help: there is an associated function with a similar name: `visit_region_def`
    |  _________|
    | |
261 | |             (self.visit_control_region)(&mut self.state, func_at_control_region);
262 | |             func_at_control_region.inner_visit_with(self);
263 | |         }
    | |_________^ not a member of trait `Visitor`

error[E0407]: method `visit_control_node_def` is not a member of trait `Visitor`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:264:9
    |
264 | /         fn visit_control_node_def(&mut self, func_at_control_node: FuncAt<'a, ControlNode>) {
265 | |             (self.visit_control_node)(&mut self.state, func_at_control_node);
266 | |             func_at_control_node.inner_visit_with(self);
267 | |         }
    | |_________^ not a member of trait `Visitor`

error[E0609]: no field `control_regions` on type `&mut FuncDefBody`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/controlflow.rs:200:45
    |
200 |             let region_def = &func_def_body.control_regions[region];
    |                                             ^^^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `body`, `unstructured_cfg`

error[E0609]: no field `control_nodes` on type `&mut FuncDefBody`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/controlflow.rs:202:55
    |
202 |                 Some(last_node) => &mut func_def_body.control_nodes[last_node],
    |                                                       ^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `body`, `unstructured_cfg`

error[E0560]: struct `spirt::func_at::FuncAt<'_, _>` has no field named `control_nodes`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/controlflow.rs:223:17
    |
223 |                 control_nodes: &EntityDefs::new(),
    |                 ^^^^^^^^^^^^^ `spirt::func_at::FuncAt<'_, _>` does not have this field
    |
    = note: available fields are: `regions`, `nodes`

error[E0560]: struct `spirt::func_at::FuncAt<'_, _>` has no field named `control_regions`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/controlflow.rs:224:17
    |
224 |                 control_regions: &EntityDefs::new(),
    |                 ^^^^^^^^^^^^^^^ `spirt::func_at::FuncAt<'_, _>` does not have this field
    |
    = note: available fields are: `regions`, `nodes`

error[E0599]: no variant named `SpvDebugLine` found for enum `spirt::Attr`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/debuginfo.rs:151:62
    |
151 |                         .filter(|attr| !matches!(attr, Attr::SpvDebugLine { .. }))
    |                                                              ^^^^^^^^^^^^ variant not found in `spirt::Attr`

error[E0599]: no variant named `SpvDebugLine` found for enum `spirt::Attr`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/debuginfo.rs:154:81
    |
154 | ...                   current_file_line_col.map(|(file, line, col)| Attr::SpvDebugLine {
    |                                                                           ^^^^^^^^^^^^ variant not found in `spirt::Attr`

error[E0599]: no variant named `SpvDebugLine` found for enum `spirt::Attr`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:210:24
    |
210 |                 &Attr::SpvDebugLine {
    |                        ^^^^^^^^^^^^ variant not found in `spirt::Attr`

error[E0609]: no field `form` on type `&DataInstDef`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:248:61
    |
248 |                     let custom_op = match cx[debug_inst_def.form].kind {
    |                                                             ^^^^ unknown field
    |
    = note: available fields are: `attrs`, `kind`, `inputs`, `output_type`

error[E0599]: no method named `visit_data_inst_form_def` found for mutable reference `&mut DiagnosticReporter<'a>` in the current scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:524:14
    |
524 |         self.visit_data_inst_form_def(&self.cx[data_inst_form]);
    |              ^^^^^^^^^^^^^^^^^^^^^^^^
    |
help: there is a method `visit_data_inst_def` with a similar name
    |
524 |         self.visit_data_inst_def(&self.cx[data_inst_form]);
    |              ~~~~~~~~~~~~~~~~~~~

error[E0599]: no method named `append_diag` found for struct `spirt::AttrSet` in the current scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:567:36
    |
567 |                 AttrSet::default().append_diag(
    |                 -------------------^^^^^^^^^^^ method not found in `AttrSet`

error[E0609]: no field `form` on type `&'a DataInstDef`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:625:43
    |
625 |                 } = self.cx[data_inst_def.form].kind
    |                                           ^^^^ unknown field
    |
    = note: available fields are: `attrs`, `kind`, `inputs`, `output_type`

error[E0599]: no method named `append_diag` found for struct `spirt::AttrSet` in the current scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:672:72
    |
672 | ...                   AttrSet::default().append_diag(
    |                       -------------------^^^^^^^^^^^ method not found in `AttrSet`

error[E0609]: no field `form` on type `&'a DataInstDef`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/diagnostics.rs:695:69
    |
695 |         if let DataInstKind::FuncCall(func) = self.cx[data_inst_def.form].kind {
    |                                                                     ^^^^ unknown field
    |
    = note: available fields are: `attrs`, `kind`, `inputs`, `output_type`

error[E0034]: multiple applicable items in scope
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:63:85
   |
63 | ...                   mem::take(&mut func.reborrow().at(case_to_fuse).def().children);
   |                                                                       ^^^ multiple `def` found
   |
   = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
   = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
   = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0034]: multiple applicable items in scope
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:72:67
   |
72 | ...                   func.reborrow().at(base_case).def().outputs.clone();
   |                                                     ^^^ multiple `def` found
   |
   = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
   = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
   = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0034]: multiple applicable items in scope
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:75:38
   |
75 | ...                   .into_iter()
   |                        ^^^^^^^^^ multiple `into_iter` found
   |
   = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, EntityList<DataInst>>`
   = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, EntityList<spirt::Node>>`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:78:52
   |
78 | ...                   Value::ControlNodeOutput {
   |                              ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0609]: no field `control_regions` on type `FuncAtMut<'_, ()>`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:89:38
   |
89 | ...                   func.control_regions[base_case]
   |                            ^^^^^^^^^^^^^^^ unknown field
   |
   = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0609]: no field `control_nodes` on type `FuncAtMut<'_, ()>`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/fuse_selects.rs:91:76
   |
91 | ...                   .append(children_of_case_to_fuse, func.control_nodes);
   |                                                              ^^^^^^^^^^^^^ unknown field
   |
   = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
  --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:86:45
   |
86 |                         let output = Value::ControlNodeOutput {
   |                                             ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:163:49
    |
163 |                         let body_input = Value::ControlRegionInput {
    |                                                 ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0560]: struct `DataInstDef` has no field named `form`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:213:29
    |
213 | ...                   form: cx.intern(DataInstFormDef {
    |                       ^^^^ `DataInstDef` does not have this field
    |
    = note: available fields are: `kind`, `output_type`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:382:32
    |
382 |                         Value::ControlRegionInput { region, .. } => region,
    |                                ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:383:32
    |
383 |                         Value::ControlNodeOutput { control_node, .. } => {
    |                                ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0609]: no field `form` on type `&DataInstDef`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:511:42
    |
511 |         let inst_form_def = &cx[inst_def.form];
    |                                          ^^^^ unknown field
    |
    = note: available fields are: `attrs`, `kind`, `inputs`, `output_type`

error[E0277]: the trait bound `PureOp: TryFrom<spirt::spv::Inst>` is not satisfied
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:513:22
    |
513 |             let op = PureOp::try_from(spv_inst)?;
    |                      ^^^^^^ the trait `From<spirt::spv::Inst>` is not implemented for `PureOp`
    |
    = help: the trait `TryFrom<spirt::spv::Inst>` is not implemented for `PureOp`
            but trait `TryFrom<&spirt::spv::Inst>` is implemented for it
    = help: for that trait implementation, expected `&spirt::spv::Inst`, found `spirt::spv::Inst`
    = note: required for `spirt::spv::Inst` to implement `Into<PureOp>`
    = note: required for `PureOp` to implement `TryFrom<spirt::spv::Inst>`

error[E0277]: `?` couldn't convert the error to `()`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:513:48
    |
513 |             let op = PureOp::try_from(spv_inst)?;
    |                                                ^ the trait `From<Infallible>` is not implemented for `()`
    |
    = note: the question mark operation (`?`) implicitly performs a conversion on the error value using the `From` trait
    = help: the following other types implement trait `From<T>`:
              `(T, T)` implements `From<[T; 2]>`
              `(T, T, T)` implements `From<[T; 3]>`
              `(T, T, T, T)` implements `From<[T; 4]>`
              `(T, T, T, T, T)` implements `From<[T; 5]>`
              `(T, T, T, T, T, T)` implements `From<[T; 6]>`
              `(T, T, T, T, T, T, T)` implements `From<[T; 7]>`
              `(T, T, T, T, T, T, T, T)` implements `From<[T; 8]>`
              `(T, T, T, T, T, T, T, T, T)` implements `From<[T; 9]>`
            and 5 others
    = note: required for `std::result::Result<Reducible, ()>` to implement `FromResidual<std::result::Result<Infallible, Infallible>>`

error[E0277]: the trait bound `PureOp: From<spirt::spv::Inst>` is not satisfied
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:513:22
    |
513 |             let op = PureOp::try_from(spv_inst)?;
    |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^ the trait `From<spirt::spv::Inst>` is not implemented for `PureOp`
    |
    = help: the trait `TryFrom<spirt::spv::Inst>` is not implemented for `PureOp`
            but trait `TryFrom<&spirt::spv::Inst>` is implemented for it
    = help: for that trait implementation, expected `&spirt::spv::Inst`, found `spirt::spv::Inst`
    = note: required for `spirt::spv::Inst` to implement `Into<PureOp>`
    = note: required for `PureOp` to implement `TryFrom<spirt::spv::Inst>`

error[E0560]: struct `DataInstDef` has no field named `form`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:537:13
    |
537 |             form: cx.intern(DataInstFormDef {
    |             ^^^^ `DataInstDef` does not have this field
    |
    = note: available fields are: `kind`, `output_type`

error[E0609]: no field `form` on type `&DataInstDef`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:661:75
    |
661 |         if let DataInstKind::SpvInst(input_spv_inst) = &cx[input_inst_def.form].kind {
    |                                                                           ^^^^ unknown field
    |
    = note: available fields are: `attrs`, `kind`, `inputs`, `output_type`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:745:20
    |
745 |             Value::ControlRegionInput {
    |                    ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:842:20
    |
842 |             Value::ControlNodeOutput {
    |                    ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:810:54
    |
810 | ...                   func.reborrow().at(node).def().kind,
    |                                                ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0609]: no field `control_nodes` on type `FuncAtMut<'_, ()>`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:815:46
    |
815 |                         let new_block = func.control_nodes.define(
    |                                              ^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0609]: no field `control_regions` on type `FuncAtMut<'_, ()>`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:825:30
    |
825 |                         func.control_regions[region]
    |                              ^^^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0609]: no field `control_nodes` on type `FuncAtMut<'_, ()>`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:827:58
    |
827 | ...                   .insert_last(new_block, func.control_nodes);
    |                                                    ^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0609]: no field `control_nodes` on type `FuncAtMut<'_, ()>`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:830:33
    |
830 |                 match &mut func.control_nodes[loop_body_last_block].kind {
    |                                 ^^^^^^^^^^^^^ unknown field
    |
    = note: available fields are: `regions`, `nodes`, `data_insts`, `position`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:837:29
    |
837 |                 Some(Value::ControlRegionInput {
    |                             ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:859:54
    |
859 | ...                   func.reborrow().at(case).def().outputs[output_idx as usize];
    |                                                ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:897:74
    |
897 |                     let per_case_outputs = &mut func.reborrow().at(case).def().outputs;
    |                                                                          ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/reduce.rs:901:29
    |
901 |                 Some(Value::ControlNodeOutput {
    |                             ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no method named `visit_data_inst_form_def` found for mutable reference `&mut ReachableUseCollector<'_>` in the current scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:219:18
    |
219 |             self.visit_data_inst_form_def(&self.cx[data_inst_form]);
    |                  ^^^^^^^^^^^^^^^^^^^^^^^^
    |
help: there is a method `visit_data_inst_def` with a similar name
    |
219 |             self.visit_data_inst_def(&self.cx[data_inst_form]);
    |                  ~~~~~~~~~~~~~~~~~~~

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:456:63
    |
456 |         let control_node_def = func_def_body.at(control_node).def();
    |                                                               ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `spirt::func_at::FuncAt<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `spirt::func_at::FuncAt<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `spirt::func_at::FuncAt<'a, spirt::Region>`

error[E0560]: struct `DataInstDef` has no field named `form`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:476:29
    |
476 | ...                   form: cx.intern(DataInstFormDef {
    |                       ^^^^ `DataInstDef` does not have this field
    |
    = note: available fields are: `kind`, `output_type`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:489:56
    |
489 |                     func_def_body.at_mut(control_node).def().kind = ControlNodeKind::Block {
    |                                                        ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:501:50
    |
501 |                     let original_output = Value::ControlNodeOutput {
    |                                                  ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:510:30
    |
510 | ...                   .def()
    |                        ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:514:56
    |
514 | ...                   func_def_body.at_mut(case).def().outputs.remove(new_idx);
    |                                                  ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:521:49
    |
521 |                         let new_output = Value::ControlNodeOutput {
    |                                                 ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:540:49
    |
540 |                     let original_input = Value::ControlRegionInput {
    |                                                 ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:547:71
    |
547 |                         match &mut func_def_body.at_mut(control_node).def().kind {
    |                                                                       ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `FuncAtMut<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `FuncAtMut<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `FuncAtMut<'a, spirt::Region>`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:561:48
    |
561 |                         let new_input = Value::ControlRegionInput {
    |                                                ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:312:27
    |
312 |             if let Value::ControlRegionInput {
    |                           ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlRegionInput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:329:28
    |
329 |                     Value::ControlRegionInput { region, input_idx } => {
    |                            ^^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0599]: no variant named `ControlNodeOutput` found for enum `spirt::Value`
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:339:28
    |
339 |                     Value::ControlNodeOutput {
    |                            ^^^^^^^^^^^^^^^^^ variant not found in `spirt::Value`

error[E0034]: multiple applicable items in scope
   --> /home/jfredett/.cargo/git/checkouts/rust-gpu-77e2b2b93eb09bab/f4beb73/crates/rustc_codegen_spirv/src/linker/spirt_passes/mod.rs:349:58
    |
349 | ...                   self.mark_used(func.at(case).def().outputs[output_idx as usize]);
    |                                                    ^^^ multiple `def` found
    |
    = note: candidate #1 is defined in an impl for the type `spirt::func_at::FuncAt<'a, DataInst>`
    = note: candidate #2 is defined in an impl for the type `spirt::func_at::FuncAt<'a, spirt::Node>`
    = note: candidate #3 is defined in an impl for the type `spirt::func_at::FuncAt<'a, spirt::Region>`

Some errors have detailed explanations: E0034, E0277, E0407, E0432, E0560, E0599, E0609.
For more information about an error, try `rustc --explain E0034`.
error: could not compile `rustc_codegen_spirv` (lib) due to 69 previous errors
[2025-02-23T22:41:53Z ERROR cargo_gpu] ...build error!
Error: ...build error!
```

Not sure if this is my change (to bump the bytemuck dep) or if it's one of the many other hacks I've been piling on
here; but this is probably interesting enough to report on the issue.


# 1-MAR-2025

## 1614

After some further discussion, I had a misunderstanding clarified, but have had no further success in getting this
version of things to compile either on the 0.9 version or on `main`. In particular, I get two distinct kinds of error:

### 0.9

I get an issue where `elsa` is pinned to 1.11, but it should be 1.6 to match the 0.9 versions, I'm not quite sure why
this happens, but the result is that the `0.9` version can't compile because it uses `inline_const`, which was unstable
at the time of the rust compiler needed.

I didn't try a clean rebuild there, that's still a possiblity, but my guess is that it was maybe a loose dep
specification somewhere in the chain (I believe in spirt) and I'd have to unwind that to figure out what's up.

### main

Using my forks of the main branch also didn't work, though for a less obvious reason, it appears the target isn't
supported? This doesn't make a tone of sense to me, but it does fail equivalently after a full clean (I tried it on a
separate VM just to rule out any machine-local stuff.

I might try this one more time w/ the official repos subbed in, just to be sure.

## 1637

This did not work. I truly have no idea why, and at this point, I'm not really interested in chasing this anymore. The
goal of this project was to experiment with Rust on the GPU. The experiment's result is "It's not straightforward right
now, come back later."

I might try getting this working on a non-nixos machine at some point, or I might just leave the GPU stuff to the
other wizards.

In principle, the current `flake.nix` should build this; I don't put any onus on the maintainers for it not working
here, but I do not really understand how I end up with such semi-random failures when matching, ostensibly, the versions
they need, copying code directly from `rust-gpu`.

It might be worthwhile to try rebuilding this repo again from scratch? I don't think I introduced anything weird in the
process.

Alternately, it might be worthwhile to try to build the `rust-gpu` workspace as a whole, it might at least reveal where
the issue is living. If I come back to this at some point, maybe I'll try that.

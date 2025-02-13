use spirv_builder::{MetadataPrintout, SpirvBuilder};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let rust_gpu_rustc = env!("RUSTGPU_RUSTC");

//    println!("cargo::rustc-env=RUSTC={}", rust_gpu_rustc);

    SpirvBuilder::new("../shader-1", target)
        .print_metadata(MetadataPrintout::Full)
        .build()?;
    Ok(())
}

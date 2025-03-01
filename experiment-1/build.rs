use spirv_builder::{MetadataPrintout, SpirvBuilder};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let target = "spirv-unknown-vulkan1.1";
    SpirvBuilder::new("../shader-1", target)
        .print_metadata(MetadataPrintout::Full)
        .build()?;
    Ok(())
}



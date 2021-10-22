use std::env;
use std::fs;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let pkg_name = env::var("CARGO_PKG_NAME").unwrap();

    println!("cargo:rerun-if-changed=src/lib.rs");

    let cbindgen_config: cbindgen::Config = toml::from_slice(&fs::read("cbindgen.toml").unwrap()).unwrap();

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_config(cbindgen_config)
        .with_language(cbindgen::Language::C)
        .generate()
        .unwrap()
        .write_to_file(format!("../VoiceAnalyzer/src/FFI/Rust/libvoice_analyzer_rust/{}.h", pkg_name));
}

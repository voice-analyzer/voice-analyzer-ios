use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let pkg_name = env::var("CARGO_PKG_NAME").unwrap();

    println!("cargo:rerun-if-changed=src/lib.rs");

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .unwrap()
        .write_to_file(format!("../VoiceAnalyzerRust/Sources/libvoice_analyzer_rust/{}.h", pkg_name));

    println!("cargo:rerun-if-changed=src/ffi/bindgen_wrapper.h");

    let bindings = bindgen::Builder::default()
        .header("src/ffi/bindgen_wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("error generating bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("error writing bindings");
}

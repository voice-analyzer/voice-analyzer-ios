use std::env;
use std::path::PathBuf;

fn main() {
    cc::Build::new()
        .file("c_src/libformants.c")
        .compile("formants");

    println!("cargo:rerun-if-changed=src/ffi/bindgen_wrapper.h");

    let bindings = bindgen::Builder::default()
        .header("src/ffi/bindgen_wrapper.h")
        .clang_arg("-Ic_src")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .use_core()
        .ctypes_prefix("cty")
        .generate()
        .expect("error generating bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("error writing bindings");
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_test() -> *const i8 {
    b"test from rust landy\0".as_ptr() as *const i8
}

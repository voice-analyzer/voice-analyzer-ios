pub mod analyzer;

#[allow(deref_nullptr, non_camel_case_types, non_snake_case, unused)]
pub mod bindings {
    include!(concat!(env!("OUT_DIR"), "/bindings.rs"));
}

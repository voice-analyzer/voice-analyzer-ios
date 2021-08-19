mod util;
mod yin;

use core::ptr::NonNull;

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct Pitch {
    value: f32,
    confidence: f32,
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_yin(
    p_samples: *const f32,
    samples_len: usize,
    sample_rate: u32,
    threshold: f32,
) -> Pitch {
    let samples = NonNull::new(p_samples as *mut _)
        .as_mut()
        .map(|p_samples| unsafe { std::slice::from_raw_parts(p_samples.as_ptr(), samples_len) })
        .unwrap_or(&[]);
    let pitch = yin::pitch(samples, sample_rate, threshold);
    pitch.unwrap_or_default()
}

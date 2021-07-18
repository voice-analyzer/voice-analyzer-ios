mod yin;
use std::cell::RefCell;

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct Pitch {
    value: f32,
    confidence: f32,
}

thread_local! {
    static YIN_BUFFER: RefCell<Vec<f32>> = <_>::default();
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_yin(samples: *const f32, samples_len: usize, sample_rate: u32, threshold: f32) -> Pitch {
    let samples = unsafe { std::slice::from_raw_parts(samples, samples_len) };
    YIN_BUFFER.with(|yin_buffer| {
        let mut yin_buffer = yin_buffer.borrow_mut();
        yin_buffer.clear();
        yin_buffer.reserve(samples_len / 2);

        let pitch = yin::pitch(&mut yin_buffer, samples, sample_rate, threshold);
        pitch.unwrap_or_default()
    })
}


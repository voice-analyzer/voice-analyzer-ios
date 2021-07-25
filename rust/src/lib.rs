#[macro_use]
mod util;

mod ffi;
mod irapt;
mod logger;
mod resample;
mod yin;

use core::iter;
use core::ptr::NonNull;

pub struct IraptState(irapt::State);

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct Pitch {
    pub value:      f32,
    pub confidence: f32,
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_irapt_new(sample_rate: f64) -> *mut IraptState {
    logger::set_logger();
    Box::into_raw(Box::new(IraptState(irapt::State::new(sample_rate))))
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_irapt_process(
    mut p_irapt: Option<NonNull<IraptState>>,
    p_samples: *const f32,
    samples_len: usize,
) -> Pitch {
    logger::set_logger();
    let samples = NonNull::new(p_samples as *mut _)
        .as_mut()
        .map(|p_samples| unsafe { std::slice::from_raw_parts(p_samples.as_ptr(), samples_len) })
        .unwrap_or(&[]);
    let irapt = p_irapt.as_mut().map(|p_irapt| unsafe { p_irapt.as_mut() });
    let pitch = irapt.and_then(|irapt| {
        let first_pitch = irapt.0.process(samples);
        first_pitch.into_iter().chain(iter::from_fn(|| irapt.0.process(&[]))).last()
    });
    pitch.unwrap_or_default()
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_irapt_drop(mut p_irapt: Option<NonNull<IraptState>>) {
    logger::set_logger();
    let _irapt = p_irapt.as_mut().map(|p_irapt| unsafe { Box::from_raw(p_irapt.as_ptr()) });
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_yin(p_samples: *const f32, samples_len: usize, sample_rate: u32, threshold: f32) -> Pitch {
    logger::set_logger();
    let samples = NonNull::new(p_samples as *mut _)
        .as_mut()
        .map(|p_samples| unsafe { std::slice::from_raw_parts(p_samples.as_ptr(), samples_len) })
        .unwrap_or(&[]);
    let pitch = yin::pitch(samples, sample_rate, threshold);
    pitch.unwrap_or_default()
}

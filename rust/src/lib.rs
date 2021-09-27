#[macro_use]
mod util;

mod analyzer;
mod ffi;
mod logger;
mod resample;
mod yin;

use core::ptr::NonNull;

use analyzer::Analyzer;
use itertools::Itertools;

//
// public API
//

pub const FORMANT_COUNT: usize = 2;

pub struct AnalyzerState(Analyzer);

#[repr(C)]
pub enum PitchEstimationAlgorithm {
    Irapt,
    Yin,
}

#[repr(C)]
pub enum FormantEstimationAlgorithm {
    None,
    LibFormants,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct AnalyzerOutput {
    pub pitch:    Pitch,
    pub formants: [Formant; FORMANT_COUNT],
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct Pitch {
    pub value:      f32,
    pub confidence: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct Formant {
    pub frequency: f32,
    pub bandwidth: f32,
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_analyzer_new(
    sample_rate: f64,
    pitch_estimation_algorithm: PitchEstimationAlgorithm,
    formant_estimation_algorithm: FormantEstimationAlgorithm,
) -> *mut AnalyzerState {
    logger::set_logger();
    Box::into_raw(Box::new(AnalyzerState(Analyzer::new(
        sample_rate,
        pitch_estimation_algorithm,
        formant_estimation_algorithm,
    ))))
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_analyzer_process(
    mut p_analyzer: Option<NonNull<AnalyzerState>>,
    p_samples: *const f32,
    samples_len: usize,
) -> AnalyzerOutput {
    logger::set_logger();
    let samples = NonNull::new(p_samples as *mut _)
        .as_mut()
        .map(|p_samples| unsafe { std::slice::from_raw_parts(p_samples.as_ptr(), samples_len) })
        .unwrap_or(&[]);
    let analyzer = p_analyzer.as_mut().map(|p_analyzer| unsafe { p_analyzer.as_mut() });
    let output = analyzer.and_then(|analyzer| analyzer.0.process(samples));
    output.unwrap_or_default()
}

#[no_mangle]
pub extern "C" fn voice_analyzer_rust_analyzer_drop(mut p_analyzer: Option<NonNull<AnalyzerState>>) {
    logger::set_logger();
    let _analyzer = p_analyzer.as_mut().map(|p_analyzer| unsafe { Box::from_raw(p_analyzer.as_ptr()) });
}

//
// Formants impls
//

impl AnalyzerOutput {
    pub fn new(pitch: Pitch, formants: Option<formants::Formants>) -> Self {
        let formants = formants
            .iter()
            .flat_map(AsRef::as_ref)
            .filter(|formant| formant.frequency.is_normal())
            .filter(|formant| formant.frequency > pitch.value * 1.5)
            .map(|formant| Formant {
                frequency: formant.frequency as f32,
                bandwidth: formant.bandwidth as f32,
            });
        let mut new_self = Self { pitch, ..<_>::default() };
        new_self.formants.iter_mut().set_from(formants);
        new_self
    }
}

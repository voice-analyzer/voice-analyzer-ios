use core::borrow::Borrow;
use core::convert::TryInto;
use core::fmt::Debug;
use core::ops::Deref;
use core::ptr::NonNull;
use core::slice;

use super::bindings::{
    formants_analyze, formants_destroy, formants_destroy_work, formants_make_work, formants_work_t,
};

pub struct FormantAnalyzer {
    work: NonNull<formants_work_t>,
    lpc_order: u32,
}

pub struct Formants {
    formants: NonNull<Formant>,
    len: usize,
}

pub use super::bindings::formant_t as Formant;

//
// FormantAnalyzer impls
//

impl FormantAnalyzer {
    /// Constructs a new `FormantAnalyzer`, with specified LPC order and chunk length.
    ///
    /// The `lpc_order` is a tuning parameter for the analysis. For the general case of any human speech, try `2.5 +
    /// sample_rate / 1000.0`.
    ///
    /// The `chunk_length` is the exact number of input samples to be supplied to each call to `analyze`.
    pub fn new(chunk_length: u32, lpc_order: u32) -> Self {
        let work =
            NonNull::new(unsafe { formants_make_work(chunk_length.into(), lpc_order.into()) })
                .unwrap();
        Self { work, lpc_order }
    }

    pub fn analyze(&mut self, input: &[f32], sample_rate: f32, safety_margin: f32) -> Formants {
        let mut formants_len = 0;
        let p_formants = unsafe {
            formants_analyze(
                self.work.as_ptr(),
                input.as_ptr(),
                input.len().try_into().unwrap(),
                self.lpc_order.into(),
                sample_rate,
                safety_margin,
                &mut formants_len,
            )
        };
        let formants = unsafe { Formants::new(p_formants, formants_len as usize) };
        formants.unwrap()
    }
}

impl Drop for FormantAnalyzer {
    fn drop(&mut self) {
        unsafe { formants_destroy_work(self.work.as_ptr()) };
    }
}

//
// Formants impls
//

impl Formants {
    unsafe fn new(p_formants: *mut Formant, len: usize) -> Option<Self> {
        NonNull::new(p_formants).map(|formants| Self { formants, len })
    }
}

impl AsRef<[Formant]> for Formants {
    fn as_ref(&self) -> &[Formant] {
        &**self
    }
}

impl Borrow<[Formant]> for Formants {
    fn borrow(&self) -> &[Formant] {
        &**self
    }
}

impl Debug for Formants {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        Debug::fmt(&**self, f)
    }
}

impl Deref for Formants {
    type Target = [Formant];

    fn deref(&self) -> &Self::Target {
        unsafe { slice::from_raw_parts(self.formants.as_ptr(), self.len) }
    }
}

impl Drop for Formants {
    fn drop(&mut self) {
        unsafe { formants_destroy(self.formants.as_ptr()) };
    }
}

use crate::ffi::bindings as sys;
use crate::util::vec_or_deque::VecOrDeque;

use core::fmt;
use std::collections::VecDeque;
use std::ffi::CStr;

pub struct BufferedResampler {
    resampler:   Resampler,
    ratio:       f64,
    unprocessed: VecDeque<f32>,
    resampled:   VecOrDeque<f32>,
}

pub struct Resampler {
    state: *mut sys::SRC_STATE,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ResamplerError(i32);

impl BufferedResampler {
    pub fn new(ratio: f64) -> Result<Self, ResamplerError> {
        Ok(Self {
            resampler: Resampler::new()?,
            ratio,
            unprocessed: VecDeque::with_capacity(4096),
            resampled: VecDeque::with_capacity(4096).into(),
        })
    }

    pub fn process(&mut self, samples: &[f32]) -> Result<&mut VecDeque<f32>, ResamplerError> {
        let resampled = self.resampled.to_vec_mut();
        if self.unprocessed.is_empty() {
            let processed_len = self.resampler.process(samples, resampled, self.ratio, false)?;
            self.unprocessed.extend(&samples[processed_len..]);
        } else {
            self.unprocessed.extend(samples);
            let processed_len = self
                .resampler
                .process(&self.unprocessed.as_slices().0, resampled, self.ratio, false)?;
            self.unprocessed.drain(..processed_len);

            let processed_len = self
                .resampler
                .process(self.unprocessed.make_contiguous(), resampled, self.ratio, false)?;
            self.unprocessed.drain(..processed_len);
        };
        Ok(self.resampled.to_deque_mut())
    }
}

impl Resampler {
    pub fn new() -> Result<Self, ResamplerError> {
        let mut error = 0;
        let state = unsafe { sys::src_new(sys::SRC_SINC_MEDIUM_QUALITY as i32, 1, &mut error) };
        ResamplerError::ok(error).map(|()| Self { state })
    }

    pub fn process(&mut self, input: &[f32], output: &mut Vec<f32>, src_ratio: f64, end_of_input: bool) -> Result<usize, ResamplerError> {
        let mut src_data = sys::SRC_DATA {
            data_in: input.as_ptr(),
            data_out: unsafe { output.as_mut_ptr().add(output.len()) },
            input_frames: input.len() as i64,
            output_frames: (output.capacity() - output.len()) as i64,
            input_frames_used: 0,
            output_frames_gen: 0,
            end_of_input: end_of_input as i32,
            src_ratio,
        };

        ResamplerError::ok(unsafe { sys::src_process(self.state, &mut src_data) })?;

        unsafe { output.set_len(output.len().saturating_add(src_data.output_frames_gen as usize)) };

        Ok(src_data.input_frames_used as usize)
    }
}

impl ResamplerError {
    fn ok(error: i32) -> Result<(), Self> {
        match error {
            0 => Ok(()),
            _ => Err(Self(error)),
        }
    }
}

impl fmt::Display for ResamplerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let error_str = match unsafe { sys::src_strerror(self.0) } {
            error_ptr if !error_ptr.is_null() => unsafe { CStr::from_ptr::<'static>(error_ptr) },
            _ => <_>::default(),
        };
        write!(f, "{}: {}", self.0, error_str.to_str().unwrap_or("???"))?;
        Ok(())
    }
}

impl Drop for Resampler {
    fn drop(&mut self) {
        unsafe { sys::src_delete(self.state) };
    }
}

use std::collections::VecDeque;

use rubato::{ResampleError, Resampler as _};

pub struct BufferedResampler {
    resampler: Resampler,
    unprocessed: Vec<f32>,
}

type Resampler = rubato::FftFixedOut<f32>;

impl BufferedResampler {
    pub fn new(sample_rate: usize, downsampled_rate: usize, chunk_size: usize) -> Self {
        let resampler = Resampler::new(sample_rate, downsampled_rate, chunk_size, 1, 1);
        Self {
            unprocessed: Vec::with_capacity(resampler.nbr_frames_needed()),
            resampler,
        }
    }

    pub fn process(&mut self, mut samples: &[f32], resampled: &mut VecDeque<f32>) -> Result<(), ResampleError> {
        if !self.unprocessed.is_empty() {
            let samples_needed = self
                .resampler
                .nbr_frames_needed()
                .checked_sub(self.unprocessed.len())
                .unwrap_or_else(|| unreachable!());
            if samples.len() >= samples_needed {
                let (samples_chunk, samples_rest) = samples.split_at(samples_needed);
                samples = samples_rest;
                self.unprocessed.extend(samples_chunk);
                let newly_resampled = self.resampler.process(&[self.unprocessed.drain(..)])?;
                let newly_resampled = newly_resampled.into_iter().next().unwrap_or_default();
                resampled.extend(newly_resampled);
            }
        }

        while samples.len() >= self.resampler.nbr_frames_needed() {
            let (samples_chunk, samples_rest) = samples.split_at(self.resampler.nbr_frames_needed());
            samples = samples_rest;
            let newly_resampled = self.resampler.process(&[samples_chunk])?;
            let newly_resampled = newly_resampled.into_iter().next().unwrap_or_default();
            resampled.extend(newly_resampled);
        }

        self.unprocessed.extend(samples);

        Ok(())
    }
}

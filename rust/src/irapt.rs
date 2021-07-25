use std::ops::RangeInclusive;

use crate::resample::BufferedResampler;
use crate::Pitch;

use irapt::Irapt;

const TARGET_DOWNSAMPLED_RATE: f64 = 12000.0;
const PITCH_RANGE: RangeInclusive<f64> = 50.0..=880.0;

pub struct State {
    downsampler: BufferedResampler,
    irapt:       Irapt,
}

impl State {
    pub fn new(sample_rate: f64) -> Self {
        let downsample_ratio = (sample_rate / TARGET_DOWNSAMPLED_RATE).round() as u8;
        let downsampled_rate = sample_rate / f64::from(downsample_ratio);
        let downsampler = BufferedResampler::new(f64::from(downsample_ratio).recip()).unwrap();
        let irapt = Irapt::new(irapt::Parameters {
            sample_rate: downsampled_rate,
            pitch_range: PITCH_RANGE,
            ..<_>::default()
        });
        Self { downsampler, irapt }
    }

    pub fn process(&mut self, samples: &[f32]) -> Option<Pitch> {
        let downsampled = self.downsampler.process(samples);
        let downsampled = downsampled.map_err(|error| log::error!("error resampling audio: {}", error)).ok()?;

        self.irapt.process(downsampled).map(|pitch| Pitch {
            value:      pitch.frequency as f32,
            confidence: pitch.energy as f32,
        })
    }
}

use std::collections::VecDeque;
use std::iter;
use std::ops::RangeInclusive;

use crate::resample::BufferedResampler;
use crate::{AnalyzerOutput, FormantEstimationAlgorithm, Pitch, PitchEstimationAlgorithm, yin};

use formants::FormantAnalyzer;
use irapt::Irapt;

const TARGET_DOWNSAMPLED_RATE: f64 = 12000.0;
const PITCH_RANGE: RangeInclusive<f64> = 50.0..=880.0;

const YIN_THRESHOLD: f32 = 0.20;
const YIN_LENGTH: u32 = 3600;

const FORMANTS_LPC_LENGTH: u32 = 3600;
const FORMANTS_SAFETY_MARGIN: f32 = 50.0;

const RESAMPLER_CHUNK_SIZE: usize = 60;

pub struct Analyzer {
    downsampled_rate: f64,
    downsampler:      BufferedResampler,
    downsampled:      VecDeque<f32>,
    pitch_analyzer:   PitchAnalyzer,
    formant_analyzer: Option<FormantAnalyzer>,
}

enum PitchAnalyzer {
    Irapt(Irapt),
    Yin,
}

impl Analyzer {
    pub fn new(
        sample_rate: f64,
        pitch_estimation_algorithm: PitchEstimationAlgorithm,
        formant_estimation_algorithm: FormantEstimationAlgorithm,
    ) -> Self {
        let downsample_ratio = (sample_rate / TARGET_DOWNSAMPLED_RATE).round() as u8;
        let downsampled_rate = sample_rate / f64::from(downsample_ratio);

        let downsampler = BufferedResampler::new(
            sample_rate as usize,
            downsampled_rate as usize,
            RESAMPLER_CHUNK_SIZE,
        );

        let pitch_analyzer = match pitch_estimation_algorithm {
            PitchEstimationAlgorithm::Irapt => PitchAnalyzer::Irapt(Irapt::new(irapt::Parameters {
                sample_rate: downsampled_rate,
                pitch_range: PITCH_RANGE,
                ..<_>::default()
            }).unwrap()),
            PitchEstimationAlgorithm::Yin => PitchAnalyzer::Yin,
        };

        let formant_analyzer = match formant_estimation_algorithm {
            FormantEstimationAlgorithm::LibFormants =>
                Some(FormantAnalyzer::new(FORMANTS_LPC_LENGTH, (2.5 + downsampled_rate / 1000.0) as u32)),
            FormantEstimationAlgorithm::None => None,
        };

        Self {
            downsampled_rate,
            downsampler,
            downsampled: VecDeque::with_capacity(downsampled_rate as usize / 2),
            pitch_analyzer,
            formant_analyzer,
        }
    }

    pub fn process(&mut self, samples: &[f32]) -> Option<AnalyzerOutput> {
        self.downsampler
            .process(samples, &mut self.downsampled)
            .map_err(|error| log::error!("error resampling audio: {}", error))
            .ok()?;

        let pitch = match &mut self.pitch_analyzer {
            PitchAnalyzer::Irapt(irapt) => iter::from_fn(|| irapt.process(&mut self.downsampled)).last().map(|pitch| Pitch {
                value: pitch.frequency as f32,
                confidence: pitch.energy as f32,
            }),
            PitchAnalyzer::Yin => {
                let max_len = usize::max(FORMANTS_LPC_LENGTH as usize, YIN_LENGTH as usize);
                if let Some(remove_len) = self.downsampled.len().checked_sub(max_len) {
                    self.downsampled.drain(..remove_len);
                }
                let pitch = yin::pitch(self.downsampled.make_contiguous(), self.downsampled_rate as u32, YIN_THRESHOLD);
                pitch
            }
        };

        let formant_analyzer = self.formant_analyzer.as_mut();
        pitch.map(|pitch| {
            let formants = formant_analyzer.map(|formant_analyzer| {
                formant_analyzer.analyze(self.downsampled.make_contiguous(), self.downsampled_rate as f32, FORMANTS_SAFETY_MARGIN)
            });
            AnalyzerOutput::new(pitch, formants)
        })
    }

    pub fn reset(&mut self) {
        match &mut self.pitch_analyzer {
            PitchAnalyzer::Irapt(irapt) => irapt.reset(),
            PitchAnalyzer::Yin => (),
        }
    }
}

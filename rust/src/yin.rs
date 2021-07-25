use std::iter;

use itertools::{zip, Itertools};

use crate::util::iter::last_two;
use crate::Pitch;

pub fn pitch(samples: &[f32], sample_rate: u32, threshold: f32) -> Option<Pitch> {
    let differences = difference(samples);
    let normalized = cumulative_mean_normalized_difference(differences);
    absolute_threshold(normalized, threshold).map(|(selected_index, (prev_value, selected_value, next_value))| Pitch {
        value:      sample_rate as f32 / parabolic_interpolation(selected_index, prev_value, selected_value, next_value),
        confidence: 1.0 - selected_value,
    })
}

fn difference(samples: &[f32]) -> impl Iterator<Item = f32> + '_ {
    let differences = (0..samples.len() / 2).into_iter().map(move |lag| {
        let delta = zip(samples, &samples[lag..]).map(|(a, b)| a - b);
        let delta_squared = delta.map(|delta| delta * delta);
        delta_squared.sum()
    });
    iter::once(0.0).chain(differences.skip(1))
}

fn cumulative_mean_normalized_difference<I: Iterator<Item = f32>>(differences: I) -> impl Iterator<Item = f32> {
    let mut differences = differences.enumerate();
    let mut running_sum = 0.0;
    let first = differences.next().map(|_| 1.0);
    let normalized_differences = differences.map(move |(index, difference)| {
        running_sum += difference;
        difference * index as f32 / running_sum
    });
    first.into_iter().chain(normalized_differences)
}

fn absolute_threshold<I: Iterator<Item = f32>>(normalized: I, threshold: f32) -> Option<(usize, (Option<f32>, f32, Option<f32>))> {
    let mut below_threshold = normalized.enumerate().skip(2).skip_while(|(_, value)| *value > threshold);
    let first_below_threshold = below_threshold.next();
    first_below_threshold.map(|(mut selected_index, mut selected_value)| {
        let mut below_threshold = below_threshold.peekable();
        let until_selected = below_threshold.peeking_take_while(|(index, value)| {
            if *value < selected_value {
                selected_value = *value;
                selected_index = *index;
                true
            } else {
                false
            }
        });
        let prev_value = last_two(until_selected).0.map(|(_, value)| value);
        let next_value = below_threshold.next().map(|(_, value)| value);
        (selected_index, (prev_value, selected_value, next_value))
    })
}

fn parabolic_interpolation(selected_index: usize, prev_value: Option<f32>, selected_value: f32, next_value: Option<f32>) -> f32 {
    let prev = prev_value.map(|prev_value| (selected_index - 1, prev_value));
    let next = next_value.map(|next_value| (selected_index + 1, next_value));
    match (prev, next) {
        (Some((_, prev_value)), Some((_, next_value))) => {
            selected_index as f32 + (next_value - prev_value) / (2.0 * (2.0 * selected_value - next_value - prev_value))
        }
        (Some((other_index, other_value)), None) | (None, Some((other_index, other_value))) if other_value > selected_value => {
            other_index as f32
        }
        _ => selected_index as f32,
    }
}

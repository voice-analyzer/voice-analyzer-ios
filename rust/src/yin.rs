use std::iter;

use itertools::{FoldWhile, Itertools, zip};

use crate::Pitch;

pub(crate) fn pitch(buffer: &mut Vec<f32>, samples: &[f32], sample_rate: u32, threshold: f32) -> Option<Pitch> {
    difference(buffer, samples);
    cumulative_mean_normalized_difference(buffer);
    absolute_threshold(buffer, threshold).map(|tau_estimate| {
        Pitch {
            value: sample_rate as f32 / parabolic_interpolation(buffer, tau_estimate),
            confidence: 1.0 - buffer[tau_estimate],
        }
    })
}

fn difference(buffer: &mut Vec<f32>, samples: &[f32]) {
    let tau_values = (0..samples.len() / 2).into_iter().map(|tau| {
        let delta = zip(samples, &samples[tau..]).map(|(a, b)| a - b);
        let delta_squared = delta.map(|delta| delta * delta);
        delta_squared.sum()
    });
    let tau_values = iter::once(0.0).chain(tau_values.skip(1));
    buffer.clear();
    buffer.extend(tau_values);
}

fn cumulative_mean_normalized_difference(buffer: &mut [f32]) {
    let mut tau_iter = buffer.iter_mut().enumerate();
    let mut running_sum = 0.0;
    tau_iter.next().map(|(_tau, tau_value)| *tau_value = 1.0);
    for (tau, tau_value) in tau_iter {
        running_sum += *tau_value;
        *tau_value *= tau as f32 / running_sum;
    }
}

fn absolute_threshold(buffer: &[f32], threshold: f32) -> Option<usize> {
    let mut tau_below_threshold = buffer.iter().enumerate().skip(2).skip_while(|(_, tau_value)| **tau_value > threshold);
    let first_tau_below_threshold = tau_below_threshold.next();
    let selected_tau = first_tau_below_threshold.map(|first| {
        tau_below_threshold.fold_while(first, |(tau, tau_value), (next_tau, next_tau_value)| {
            if next_tau_value < tau_value {
                FoldWhile::Continue((next_tau, next_tau_value))
            } else {
                FoldWhile::Done((tau, tau_value))
            }
        }).into_inner()
    });
    selected_tau.map(|(tau, _tau_value)| tau)
}

fn parabolic_interpolation(buffer: &[f32], tau_estimate: usize) -> f32 {
    let tau_estimate_value = buffer[tau_estimate];

    let prev = tau_estimate.checked_sub(1).and_then(|prev_index| buffer.get(prev_index).map(|prev_value| (prev_index, prev_value)));
    let next = tau_estimate.checked_add(1).and_then(|next_index| buffer.get(next_index).map(|next_value| (next_index, next_value)));
    match (prev, next) {
        (Some((_, prev_value)), Some((_, next_value))) =>
            tau_estimate as f32 + (next_value - prev_value) / (2.0 * (2.0 * tau_estimate_value - next_value - prev_value)),
        (Some((other_index, other_value)), None) | (None, Some((other_index, other_value)))
            if *other_value > tau_estimate_value =>
            other_index as f32,
        _ => tau_estimate as f32,
    }
}

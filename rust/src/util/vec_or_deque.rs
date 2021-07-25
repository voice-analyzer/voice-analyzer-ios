use core::mem;
use std::collections::VecDeque;

/// Wrapper which converts back and forth from [`Vec<T>`] and [`VecDeque<T>`] on-demand.
///
/// [`Vec<T>`]: std::collections::Vec
/// [`VecDeque<T>`]: std::collections::VecDeque
pub struct VecOrDeque<T> {
    inner: Inner<T>,
}

enum Inner<T> {
    Vec(Vec<T>),
    VecDeque(VecDeque<T>),
}

impl<T> VecOrDeque<T> {
    pub fn new() -> Self {
        Self::from(VecDeque::new())
    }

    pub fn to_deque_mut(&mut self) -> &mut VecDeque<T> {
        self.inner.to_deque_mut()
    }

    pub fn to_vec_mut(&mut self) -> &mut Vec<T> {
        self.inner.to_vec_mut()
    }
}

impl<T> Default for VecOrDeque<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T, V: Into<VecDeque<T>>> From<V> for VecOrDeque<T> {
    fn from(from: V) -> Self {
        Self {
            inner: Inner::VecDeque(from.into()),
        }
    }
}

impl<T> Inner<T> {
    pub fn to_deque_mut(&mut self) -> &mut VecDeque<T> {
        match self {
            Self::Vec(vec) => {
                *self = Self::VecDeque(mem::take(vec).into());
                match self {
                    Self::Vec(_) => unreachable!(),
                    Self::VecDeque(deque) => deque,
                }
            }
            Self::VecDeque(deque) => deque,
        }
    }

    pub fn to_vec_mut(&mut self) -> &mut Vec<T> {
        match self {
            Self::VecDeque(deque) => {
                *self = Self::Vec(mem::take(deque).into());
                match self {
                    Self::VecDeque(_) => unreachable!(),
                    Self::Vec(vec) => vec,
                }
            }
            Self::Vec(vec) => vec,
        }
    }
}

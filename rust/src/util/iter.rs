pub fn last_two<I: IntoIterator<Item = T>, T>(into_iter: I) -> (Option<T>, Option<T>) {
    let mut prev = None;
    let mut last = None;
    for item in into_iter {
        prev = last;
        last = Some(item);
    }
    (prev, last)
}

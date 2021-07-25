use log::{Level, LevelFilter, Metadata, Record};

pub fn set_logger() {
    let _ = log::set_logger(&Logger);
    log::set_max_level(LevelFilter::Info);
}

struct Logger;

impl log::Log for Logger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Info
    }

    fn log(&self, record: &Record) {
        if self.enabled(record.metadata()) {
            let module = record.module_path().unwrap_or_default();
            let line = record.line().unwrap_or_default();
            eprintln!("{:<5} {}:{} {}", record.level(), module, line, record.args());
        }
    }

    fn flush(&self) {}
}

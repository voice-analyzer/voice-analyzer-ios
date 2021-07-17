import libvoice_analyzer_rust

public func test() -> String {
    String(cString: voice_analyzer_rust_test())
}

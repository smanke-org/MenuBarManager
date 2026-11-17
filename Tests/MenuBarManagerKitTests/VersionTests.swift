import Testing
@testable import MenuBarManagerKit

@Test("Newer versions", arguments: [
    ("0.1.1", "0.1.0", true),
    ("1.10.0", "1.9.9", true),
    ("1.2.0", "1.1.9", true),
    ("0.1.0", "0.1.0", false),
    ("1.2", "1.2.0", false),
    ("0.9.9", "1.0.0", false),
])
func comparesVersions(_ candidate: String, _ current: String, newer: Bool) {
    #expect(Version.isNewer(candidate, than: current) == newer)
}

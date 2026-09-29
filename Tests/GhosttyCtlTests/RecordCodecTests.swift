import Testing

@testable import GhosttyCtl

@Suite("Record codec")
struct RecordCodecTests {
  struct EscapingCase: Sendable {
    let encoded: String
    let decoded: String
  }

  @Test(
    arguments: [
      EscapingCase(encoded: "Work\\tMain", decoded: "Work\tMain"),
      EscapingCase(encoded: "first\\nsecond", decoded: "first\nsecond"),
      EscapingCase(encoded: "old\\rnew", decoded: "old\rnew"),
      EscapingCase(encoded: "path\\\\name", decoded: "path\\name"),
    ])
  func listDecodesEscapedFields(_ sample: EscapingCase) throws {
    let record =
      "window-1\t\(sample.encoded)\ttab-1\tEditor\t1\ttrue\tterminal-1\tnvim\t/Users/me\tfalse"

    let terminal = try #require(RecordCodec.terminals(from: record).first)

    #expect(terminal.windowName == sample.decoded)
  }
}

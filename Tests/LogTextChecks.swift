import Foundation

@main
struct LogTextChecks {
    static func main() async throws {
        var parser = LogANSIParser()
        let plain = "  警告: C:\\Users\\example\nsecond line\tend"
        precondition(parser.parse(plain).map(\.text).joined() == plain)
        let colored = parser.parse("Training \u{001B}[33m---\u{001B}[35m100%\u{001B}[0m done")
        precondition(colored.map(\.text).joined() == "Training ---100% done")
        precondition(colored[1].color != nil && colored[2].color != colored[1].color && colored[3].color == nil)
        _ = parser.parse("\u{001B}[1;38;2;12;34;56mstart")
        let continued = parser.parse("continued")
        precondition(continued[0].bold && continued[0].color == 0x0c2238)
        let reset = parser.parse("\u{001B}[22;39mreset")
        precondition(!reset[0].bold && reset[0].color == nil)
        precondition(parser.parse("\u{001B}[38;5;196mred")[0].color == 0xff0000)
        let payload = Data(#"{"logs":[{"epoch":1,"message":"same","level":"INFO","timestamp":"2026-10-02"},{"epoch":0,"message":"same"}],"count":2}"#.utf8)
        let page = try JSONDecoder().decode(ExperimentLogPage.self, from: payload)
        let prepared = try await prepareLogLines(page.logs, parser: LogANSIParser())
        precondition(prepared.lines.map(\.number) == [1, 2])
        precondition(prepared.lines.map { $0.spans.map(\.text).joined() } == ["same", "same"])
        precondition(parser.parse("").isEmpty)
        print("PASS: response decoding, epoch ordering, repeated messages, whitespace/newlines, ANSI colors, true color, 256-color, reset and cross-record styling")
    }
}

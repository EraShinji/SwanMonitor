import Foundation

nonisolated struct LogTextSpan: Sendable, Equatable {
    let text: String
    let color: Int?
    let bold: Bool
}

nonisolated struct LogTextLine: Identifiable, Sendable {
    let epoch: Int
    let number: Int
    let spans: [LogTextSpan]
    var id: Int { epoch }
}

// Only SGR styling sequences are interpreted. Log text, whitespace and source
// newlines stay intact; an API record retains one gutter number when it wraps.
nonisolated struct LogANSIParser: Sendable {
    private var color: Int?
    private var bold = false

    private static let regex = try! NSRegularExpression(pattern: "\u{001B}\\[([0-9;]*)m")

    mutating func parse(_ message: String) -> [LogTextSpan] {
        let source = message as NSString
        let matches = Self.regex.matches(in: message, range: NSRange(location: 0, length: source.length))
        var spans: [LogTextSpan] = []
        var position = 0
        for match in matches {
            if match.range.location > position {
                spans.append(LogTextSpan(text: source.substring(with: NSRange(location: position, length: match.range.location - position)), color: color, bold: bold))
            }
            let codes = source.substring(with: match.range(at: 1)).split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
            var i = 0
            while i < codes.count {
                switch codes[i] {
                case 0: color = nil; bold = false
                case 1: bold = true
                case 22: bold = false
                case 39: color = nil
                case 30...37: color = Self.palette(codes[i] - 30)
                case 90...97: color = Self.palette(codes[i] - 90 + 8)
                case 38 where i + 2 < codes.count && codes[i + 1] == 5:
                    color = Self.palette(codes[i + 2]); i += 2
                case 38 where i + 4 < codes.count && codes[i + 1] == 2:
                    let rgb = codes[(i + 2)...(i + 4)]
                    if rgb.allSatisfy({ (0...255).contains($0) }) {
                        color = codes[i + 2] << 16 | codes[i + 3] << 8 | codes[i + 4]
                    }
                    i += 4
                default: break
                }
                i += 1
            }
            position = NSMaxRange(match.range)
        }
        if position < source.length {
            spans.append(LogTextSpan(text: source.substring(from: position), color: color, bold: bold))
        }
        return spans
    }

    private static func palette(_ index: Int) -> Int? {
        let basic = [0x30343B, 0xC43B3B, 0x258448, 0xB27813, 0x397AC4, 0xAB39CE, 0x148A94, 0xB8BDC5,
                     0x7D8590, 0xF06666, 0x47BB6B, 0xD5A02E, 0x669AF0, 0xCD65EA, 0x40BEC8, 0xEEEEEE]
        if (0..<16).contains(index) { return basic[index] }
        if (16..<232).contains(index) {
            let n = index - 16
            let levels = [0, 95, 135, 175, 215, 255]
            return levels[n / 36] << 16 | levels[n / 6 % 6] << 8 | levels[n % 6]
        }
        if (232..<256).contains(index) {
            let v = 8 + (index - 232) * 10
            return v << 16 | v << 8 | v
        }
        return nil
    }
}

nonisolated struct ExperimentLogPage: Decodable, Sendable {
    let logs: [ExperimentLogEntry]
    let count: Int
}

nonisolated struct ExperimentLogEntry: Decodable, Sendable, Identifiable {
    var id: Int { epoch }
    let epoch: Int
    let message: String
    let level: String?
    let tag: String?
    let timestamp: String?
}


@concurrent
nonisolated func prepareLogLines(_ entries: [ExperimentLogEntry], parser: LogANSIParser) async throws -> (lines: [LogTextLine], parser: LogANSIParser) {
    var parser = parser
    var lines: [LogTextLine] = []
    for entry in entries.sorted(by: { $0.epoch < $1.epoch }) {
        try Task.checkCancellation()
        guard entry.epoch >= 0, entry.epoch < Int.max else { throw URLError(.cannotParseResponse) }
        lines.append(LogTextLine(epoch: entry.epoch, number: entry.epoch + 1, spans: parser.parse(entry.message)))
    }
    return (lines, parser)
}

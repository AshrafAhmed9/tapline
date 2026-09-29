import Foundation

/// A minimal CSV reader. HUBU-FIS ships a plain, unquoted CSV, so this
/// doesn't need to handle embedded commas or quoted multi-line fields — if
/// it turns out to, `parse` fails loudly rather than silently misreading a
/// column, which matters a lot more here than in most CSV code.
enum CSV {
    struct Table {
        let header: [String]
        let rows: [[String: String]]
    }

    static func parse(url: URL) throws -> Table {
        let raw = try String(contentsOf: url, encoding: .utf8)
        // Swift's String is grapheme-cluster-based, and "\r\n" is a SINGLE
        // Character in Swift — splitting on "\n" alone silently never
        // matches inside a CRLF file (every real line ends up concatenated
        // into one). Normalize CRLF and lone CR to LF first.
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { return Table(header: [], rows: []) }
        let header = splitLine(lines.removeFirst())
        let rows: [[String: String]] = lines.compactMap { line in
            let fields = splitLine(line)
            guard fields.count == header.count else { return nil }
            return Dictionary(uniqueKeysWithValues: zip(header, fields))
        }
        return Table(header: header, rows: rows)
    }

    private static func splitLine(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

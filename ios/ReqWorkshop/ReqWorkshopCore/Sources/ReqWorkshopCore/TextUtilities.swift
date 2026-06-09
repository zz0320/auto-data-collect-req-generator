import Foundation

enum TextUtilities {
    static func normalizeDuplicateText(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .map(String.init)
            .joined()
    }

    static func normalizeTaskName(_ value: String) -> String {
        let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let patterns = [
            #"^(?:预训练|后训练|pretrain|posttrain)\s*[-_：:、]?\s*(.+)$"#,
            #"^[预后]\s*[-_：:、]\s*(.+)$"#,
        ]
        for pattern in patterns {
            if let match = stripped.firstMatch(pattern: pattern), match.count > 1 {
                return normalizeDuplicateText(match[1])
            }
        }
        return normalizeDuplicateText(stripped)
    }

    static func tokens(_ values: String...) -> Set<String> {
        let text = values.joined(separator: " ").lowercased()
        var result = Set<String>()
        for match in text.matches(pattern: #"[a-z0-9][a-z0-9_-]{1,}"#) {
            result.insert(match)
        }
        for run in text.matches(pattern: #"[\u{4e00}-\u{9fff}]{2,}"#) {
            result.insert(run)
            let chars = Array(run)
            for size in [2, 3] where chars.count >= size {
                for index in 0...(chars.count - size) {
                    result.insert(String(chars[index..<(index + size)]))
                }
            }
        }
        return result
    }

    static func actionKey(from label: String) -> String? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.range(of: #"^\d+(?:\.\d+)?\s*s$"#, options: .regularExpression) != nil {
            return nil
        }
        let prefix = normalized.split(whereSeparator: { $0 == "（" || $0 == "(" }).first.map(String.init) ?? normalized
        return prefix.isEmpty ? nil : prefix
    }

    static func actionKeys(from steps: String) -> [String] {
        steps.matches(pattern: #"<([^<>]+)>"#)
            .compactMap(actionKey)
            .filter { ReqConstants.canonicalActions[$0] != nil }
            .uniqued()
    }

    static func lineCount(from steps: String) -> Int {
        let lines = steps.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.isEmpty ? actionKeys(from: steps).count : lines.count
    }

    static func stripListPrefix(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"^\s*(?:\d+[.、)）]?|[-*]+)\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    func matches(pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            let selected = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
            guard let swiftRange = Range(selected, in: self) else { return nil }
            return String(self[swiftRange])
        }
    }

    func firstMatch(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let swiftRange = Range(match.range(at: index), in: self) else { return nil }
            return String(self[swiftRange])
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

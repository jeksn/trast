public enum FuzzyMatch {
    public static func matchedIndices(query: String, target: String) -> [Int]? {
        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())
        guard !queryChars.isEmpty else { return [] }
        guard !targetChars.isEmpty else { return nil }

        var indices: [Int] = []
        var searchIndex = 0
        for char in queryChars {
            var matched = false
            while searchIndex < targetChars.count {
                if targetChars[searchIndex] == char {
                    matched = true
                    indices.append(searchIndex)
                    searchIndex += 1
                    break
                }
                searchIndex += 1
            }
            guard matched else { return nil }
        }
        return indices
    }

    public static func score(query: String, target: String) -> Int? {
        guard let indices = matchedIndices(query: query, target: target) else { return nil }
        guard !indices.isEmpty else { return 0 }

        var total = 0
        for (i, idx) in indices.enumerated() {
            if i > 0 && idx == indices[i - 1] + 1 {
                total += 6
            } else {
                total += 2
            }
            if idx == 0 { total += 4 }
        }
        return total
    }

    public static func ranked<T>(_ items: [T], query: String, text: (T) -> String) -> [T] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        return items
            .compactMap { item -> (T, Int)? in
                score(query: query, target: text(item)).map { (item, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return text(lhs.0).localizedCaseInsensitiveCompare(text(rhs.0)) == .orderedAscending
            }
            .map(\.0)
    }
}

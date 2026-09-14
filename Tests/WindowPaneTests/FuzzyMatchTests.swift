import WindowPaneCore

enum FuzzyMatchTests {
    static func runAll(_ t: TestRunner) {
        t.run("FuzzyMatch.subsequenceMatches") {
            t.check(FuzzyMatch.score(query: "lh", target: "Left Half") != nil, "lh should match Left Half")
            t.check(FuzzyMatch.score(query: "mxmz", target: "Maximize") != nil, "mxmz should match Maximize")
        }

        t.run("FuzzyMatch.nonMatchReturnsNil") {
            t.check(FuzzyMatch.score(query: "xz", target: "Left Half") == nil, "xz should not match")
        }

        t.run("FuzzyMatch.emptyQueryScoresZero") {
            t.check(FuzzyMatch.score(query: "", target: "Left Half") == 0, "empty query should score 0")
        }

        t.run("FuzzyMatch.emptyTargetWithQueryReturnsNil") {
            t.check(FuzzyMatch.score(query: "a", target: "") == nil, "empty target should not match")
        }

        t.run("FuzzyMatch.prefixBeatsScattered") {
            let prefix = FuzzyMatch.score(query: "lef", target: "Left Half") ?? 0
            let scattered = FuzzyMatch.score(query: "lf", target: "Left Half") ?? 0
            t.check(prefix > scattered, "prefix \(prefix) should beat scattered \(scattered)")
        }

        t.run("FuzzyMatch.consecutiveBeatsGaps") {
            let consecutive = FuzzyMatch.score(query: "left", target: "Left Half") ?? 0
            let gapped = FuzzyMatch.score(query: "lft", target: "Left Half") ?? 0
            t.check(consecutive > gapped, "consecutive \(consecutive) should beat gapped \(gapped)")
        }

        t.run("FuzzyMatch.rankedPutsBestMatchFirst") {
            let items = ["Maximize", "Half Left", "Left Half"]
            let ranked = FuzzyMatch.ranked(items, query: "left") { $0 }
            t.check(ranked.first == "Left Half", "got \(String(describing: ranked.first))")
        }

        t.run("FuzzyMatch.rankedWithEmptyQueryKeepsOrder") {
            let items = ["A", "B", "C"]
            t.check(FuzzyMatch.ranked(items, query: "") { $0 } == items, "order should be preserved")
        }

        t.run("FuzzyMatch.rankedFiltersNonMatches") {
            let ranked = FuzzyMatch.ranked(["Left Half", "Maximize"], query: "max") { $0 }
            t.check(ranked == ["Maximize"], "got \(ranked)")
        }

        t.run("FuzzyMatch.matchedIndicesSubsequence") {
            let indices = FuzzyMatch.matchedIndices(query: "lh", target: "Left Half")
            t.check(indices == [0, 5], "got \(String(describing: indices))")
        }

        t.run("FuzzyMatch.matchedIndicesConsecutive") {
            let indices = FuzzyMatch.matchedIndices(query: "lef", target: "Left Half")
            t.check(indices == [0, 1, 2], "got \(String(describing: indices))")
        }

        t.run("FuzzyMatch.matchedIndicesEmptyQuery") {
            t.check(FuzzyMatch.matchedIndices(query: "", target: "Left Half") == [], "empty query should return empty")
        }

        t.run("FuzzyMatch.matchedIndicesNonMatchReturnsNil") {
            t.check(FuzzyMatch.matchedIndices(query: "xz", target: "Left Half") == nil, "non-match should return nil")
        }

        t.run("FuzzyMatch.scoreUnchangedAfterRefactor") {
            t.check(FuzzyMatch.score(query: "lh", target: "Left Half") != nil, "lh should still match")
            t.check(FuzzyMatch.score(query: "lef", target: "Left Half")! > FuzzyMatch.score(query: "lf", target: "Left Half")!, "prefix bonus preserved")
        }
    }
}

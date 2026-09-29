import Foundation

/// Small, dependency-free stats so `tapbench` doesn't need to pull in a
/// numerics package for two formulas.
enum Statistics {
    static func zScores(_ values: [Double]) -> [Double] {
        guard values.count > 1 else { return values.map { _ in 0 } }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let sd = sqrt(variance)
        guard sd > 0 else { return values.map { _ in 0 } }
        return values.map { ($0 - mean) / sd }
    }

    /// Spearman rank correlation between two equal-length arrays.
    static func spearman(_ a: [Double], _ b: [Double]) -> Double? {
        guard a.count == b.count, a.count > 1 else { return nil }
        let ra = ranks(of: a)
        let rb = ranks(of: b)
        return pearson(ra, rb)
    }

    private static func ranks(of values: [Double]) -> [Double] {
        let sortedIndices = values.indices.sorted { values[$0] < values[$1] }
        var ranks = [Double](repeating: 0, count: values.count)
        var i = 0
        while i < sortedIndices.count {
            var j = i
            while j + 1 < sortedIndices.count, values[sortedIndices[j + 1]] == values[sortedIndices[i]] {
                j += 1
            }
            let averageRank = Double(i + j) / 2.0 + 1.0
            for k in i...j { ranks[sortedIndices[k]] = averageRank }
            i = j + 1
        }
        return ranks
    }

    private static func pearson(_ a: [Double], _ b: [Double]) -> Double? {
        guard a.count == b.count, a.count > 1 else { return nil }
        let n = Double(a.count)
        let meanA = a.reduce(0, +) / n
        let meanB = b.reduce(0, +) / n
        var num = 0.0, denomA = 0.0, denomB = 0.0
        for i in 0..<a.count {
            let da = a[i] - meanA
            let db = b[i] - meanB
            num += da * db
            denomA += da * da
            denomB += db * db
        }
        let denom = sqrt(denomA * denomB)
        return denom > 0 ? num / denom : nil
    }

    /// AUC via the Mann-Whitney U statistic: probability a random positive
    /// scores higher than a random negative.
    static func auc(scores: [Double], isPositive: [Bool]) -> Double? {
        guard scores.count == isPositive.count else { return nil }
        let nPos = isPositive.filter { $0 }.count
        let nNeg = isPositive.count - nPos
        guard nPos > 0, nNeg > 0 else { return nil }

        let combined = zip(scores, isPositive).map { $0 }
        let sortedByScore = combined.enumerated().sorted { $0.element.0 < $1.element.0 }

        var ranks = [Double](repeating: 0, count: combined.count)
        var i = 0
        while i < sortedByScore.count {
            var j = i
            while j + 1 < sortedByScore.count, sortedByScore[j + 1].element.0 == sortedByScore[i].element.0 {
                j += 1
            }
            let averageRank = Double(i + j) / 2.0 + 1.0
            for k in i...j { ranks[sortedByScore[k].offset] = averageRank }
            i = j + 1
        }

        let sumPositiveRanks = zip(ranks, isPositive).filter(\.1).map(\.0).reduce(0, +)
        let u = sumPositiveRanks - Double(nPos * (nPos + 1)) / 2.0
        return u / Double(nPos * nNeg)
    }
}

import CoreGraphics
import Foundation

/// Pure grid math: how to split a rectangle into `n` tiles that fill it completely.
enum Layout {
    /// Windows per row, top to bottom. Tries every row count and keeps the one whose
    /// tiles are closest to square (so 8 windows on a 16:9 screen → 4×2, 6 → 3×2).
    /// When `n` doesn't divide evenly, the leftover row gets wider tiles so the
    /// screen is still fully covered (7 → 4 + 3).
    static func rows(count n: Int, in size: CGSize) -> [Int] {
        guard n > 0, size.width > 0, size.height > 0 else { return [] }
        var best = [n]
        var bestScore = Double.infinity
        for r in 1...n {
            let base = n / r, extra = n % r
            let rows = (0..<r).map { $0 < extra ? base + 1 : base }
            let tileHeight = Double(size.height) / Double(r)
            var score = 0.0
            for cols in rows {
                let aspect = Double(size.width) / Double(cols) / tileHeight
                score += Double(cols) * abs(log(aspect))
            }
            score /= Double(n)
            if score < bestScore - 1e-9 {
                best = rows
                bestScore = score
            }
        }
        return best
    }

    /// Tile frames in reading order (row by row, left to right), snapped to whole points.
    static func frames(count n: Int, in rect: CGRect, gap: CGFloat) -> [CGRect] {
        let rows = rows(count: n, in: rect.size)
        let inner = rect.insetBy(dx: gap, dy: gap)
        var frames: [CGRect] = []
        for (r, cols) in rows.enumerated() {
            let y0 = edge(r, of: rows.count, from: inner.minY, span: inner.height, gap: gap)
            let y1 = edge(r + 1, of: rows.count, from: inner.minY, span: inner.height, gap: gap) - (r + 1 < rows.count ? gap : 0)
            for c in 0..<cols {
                let x0 = edge(c, of: cols, from: inner.minX, span: inner.width, gap: gap)
                let x1 = edge(c + 1, of: cols, from: inner.minX, span: inner.width, gap: gap) - (c + 1 < cols ? gap : 0)
                frames.append(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
            }
        }
        return frames
    }

    /// Start of slot `i` when `span` is cut into `count` equal slots separated by `gap`.
    private static func edge(_ i: Int, of count: Int, from origin: CGFloat, span: CGFloat, gap: CGFloat) -> CGFloat {
        let slot = (span + gap) / CGFloat(count)
        return (origin + CGFloat(i) * slot).rounded()
    }
}

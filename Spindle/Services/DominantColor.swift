import CoreGraphics
import Foundation

nonisolated struct RGBColor: Sendable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
}

/// Finds the colour that best represents a cover: the most vivid hue, not the
/// plain average (which turns every colourful cover into mud).
nonisolated enum DominantColor {
    private static let sampleSide = 32
    private static let hueBuckets = 12

    static func compute(from image: CGImage) -> RGBColor? {
        let side = sampleSide
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let raw = context.data
        else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        let bytesPerRow = context.bytesPerRow
        let pixels = raw.bindMemory(to: UInt8.self, capacity: bytesPerRow * side)

        var buckets = [Bucket](repeating: Bucket(), count: hueBuckets)
        var overall = Bucket()

        for y in 0..<side {
            for x in 0..<side {
                let offset = y * bytesPerRow + x * 4
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha > 0.1 else { continue }
                let r = min(1, Double(pixels[offset]) / 255 / alpha)
                let g = min(1, Double(pixels[offset + 1]) / 255 / alpha)
                let b = min(1, Double(pixels[offset + 2]) / 255 / alpha)

                overall.add(r, g, b, weight: 1)

                let maxC = max(r, g, b)
                let delta = maxC - min(r, g, b)
                let saturation = maxC == 0 ? 0 : delta / maxC
                guard saturation > 0.2, maxC > 0.25 else { continue }

                let hue = hue(r, g, b, maxC: maxC, delta: delta)
                let index = min(hueBuckets - 1, Int(hue * Double(hueBuckets)))
                buckets[index].add(r, g, b, weight: saturation * (0.4 + maxC))
            }
        }

        if let best = buckets.max(by: { $0.weight < $1.weight }), best.weight > 0 {
            return best.mean
        }
        return overall.weight > 0 ? overall.mean : nil
    }

    /// Hue in 0..<1.
    private static func hue(_ r: Double, _ g: Double, _ b: Double, maxC: Double, delta: Double) -> Double {
        guard delta > 0 else { return 0 }
        var h: Double
        if maxC == r {
            h = (g - b) / delta
        } else if maxC == g {
            h = 2 + (b - r) / delta
        } else {
            h = 4 + (r - g) / delta
        }
        h /= 6
        return h < 0 ? h + 1 : h
    }

    private struct Bucket {
        var weight = 0.0
        var r = 0.0
        var g = 0.0
        var b = 0.0

        mutating func add(_ red: Double, _ green: Double, _ blue: Double, weight w: Double) {
            weight += w
            r += red * w
            g += green * w
            b += blue * w
        }

        var mean: RGBColor { RGBColor(red: r / weight, green: g / weight, blue: b / weight) }
    }
}

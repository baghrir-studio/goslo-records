import SwiftUI
import UIKit

/// An RGBA color for drawing pixel by pixel.
struct PixelColor: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8 = 255

    static let clear = PixelColor(r: 0, g: 0, b: 0, a: 0)
    static let outline = PixelColor(hex: "#0a0a0c")

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0xFF00FF
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8) & 0xFF)
        b = UInt8(value & 0xFF)
    }

    /// factor < 1 darkens, > 1 lightens.
    func shaded(_ factor: Double) -> PixelColor {
        func channel(_ v: UInt8) -> UInt8 { UInt8(min(255, max(0, Double(v) * factor))) }
        return PixelColor(r: channel(r), g: channel(g), b: channel(b), a: a)
    }

    var isClear: Bool { a == 0 }
}

/// A small pixel buffer. Every sprite is drawn here, then turned into a UIImage.
final class PixelCanvas {
    let width: Int
    let height: Int
    private(set) var pixels: [PixelColor]

    init(width: Int, height: Int, fill: PixelColor = .clear) {
        self.width = width
        self.height = height
        pixels = Array(repeating: fill, count: width * height)
    }

    subscript(x: Int, y: Int) -> PixelColor {
        get { (0..<width).contains(x) && (0..<height).contains(y) ? pixels[y * width + x] : .clear }
        set {
            guard (0..<width).contains(x), (0..<height).contains(y) else { return }
            pixels[y * width + x] = newValue
        }
    }

    /// Inclusive rectangle from (x0, y0) to (x1, y1).
    func fill(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: PixelColor) {
        guard x0 <= x1, y0 <= y1 else { return }
        for y in y0...y1 { for x in x0...x1 { self[x, y] = color } }
    }

    func dot(_ x: Int, _ y: Int, _ color: PixelColor) {
        self[x, y] = color
    }

    func circle(cx: Int, cy: Int, radius: Int, _ color: PixelColor) {
        for y in (cy - radius)...(cy + radius) {
            for x in (cx - radius)...(cx + radius) where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius {
                self[x, y] = color
            }
        }
    }

    /// Draws another canvas on top (clear pixels ignored).
    func stamp(_ other: PixelCanvas, at ox: Int, _ oy: Int) {
        for y in 0..<other.height {
            for x in 0..<other.width where !other[x, y].isClear {
                self[ox + x, oy + y] = other[x, y]
            }
        }
    }

    /// Dark outline around shapes (gives the sprite its retro look).
    func outlined(_ color: PixelColor = .outline) -> PixelCanvas {
        let result = PixelCanvas(width: width, height: height)
        result.pixels = pixels
        for y in 0..<height {
            for x in 0..<width where self[x, y].isClear {
                let touches = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { !self[x + $0.0, y + $0.1].isClear }
                if touches { result[x, y] = color }
            }
        }
        return result
    }

    func mirrored() -> PixelCanvas {
        let result = PixelCanvas(width: width, height: height)
        for y in 0..<height { for x in 0..<width { result[width - 1 - x, y] = self[x, y] } }
        return result
    }

    func makeImage() -> UIImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(width * height * 4)
        for pixel in pixels {
            // Premultiplied alpha.
            let alpha = Double(pixel.a) / 255
            bytes += [UInt8(Double(pixel.r) * alpha), UInt8(Double(pixel.g) * alpha), UInt8(Double(pixel.b) * alpha), pixel.a]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return UIImage(cgImage: image)
    }
}

/// Deterministic noise per position (stable texture across renders).
struct PixelNoise {
    private var state: UInt64

    init(_ x: Int, _ y: Int, salt: Int = 0) {
        state = UInt64(bitPattern: Int64(x &* 73_856_093 ^ y &* 19_349_663 ^ salt &* 83_492_791)) | 1
    }

    mutating func next(_ upperBound: Int) -> Int {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Int(state % UInt64(max(1, upperBound)))
    }

    mutating func chance(_ percent: Int) -> Bool { next(100) < percent }
}

/// Cache of generated images (sprites, map, interiors).
@MainActor
enum PixelCache {
    private static var images: [String: UIImage] = [:]

    static func image(_ key: String, make: () -> UIImage) -> UIImage {
        if let cached = images[key] { return cached }
        let image = make()
        images[key] = image
        return image
    }
}

/// Displays a pixel image enlarged without smoothing.
struct PixelImage: View {
    let image: UIImage
    var width: CGFloat
    var height: CGFloat

    init(_ image: UIImage, width: CGFloat, height: CGFloat? = nil) {
        self.image = image
        self.width = width
        self.height = height ?? width * image.size.height / max(1, image.size.width)
    }

    var body: some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .frame(width: width, height: height)
    }
}

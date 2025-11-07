//
//  Image2Color.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import SwiftUI
import AppKit
import Cocoa
import Foundation
import CoreImage
import CoreGraphics
import CoreImage.CIFilterBuiltins

// Cache for average colors to avoid recalculation
private class AverageColorCache {
    static let shared = AverageColorCache()
    private var cache: [String: NSColor] = [:]
    private let queue = DispatchQueue(label: "com.boringnotch.colorCache", attributes: .concurrent)
    private let maxCacheSize = 20

    func get(for key: String) -> NSColor? {
        queue.sync { cache[key] }
    }

    func set(_ color: NSColor, for key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.cache[key] = color
            // Trim cache if it grows too large
            if self.cache.count > self.maxCacheSize {
                let keysToRemove = Array(self.cache.keys.prefix(5))
                keysToRemove.forEach { self.cache.removeValue(forKey: $0) }
            }
        }
    }
}

extension NSImage {

    // Performance-optimized version with downsampling and caching
    func averageColor(completion: @escaping (NSColor?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Generate cache key from image data
            guard let tiffData = self.tiffRepresentation else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let cacheKey = String(tiffData.hashValue)

            // Check cache first
            if let cachedColor = AverageColorCache.shared.get(for: cacheKey) {
                DispatchQueue.main.async { completion(cachedColor) }
                return
            }

            guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // OPTIMIZATION: Downsample to max 80x80 for faster processing
            let maxDimension: CGFloat = 80
            let originalWidth = cgImage.width
            let originalHeight = cgImage.height
            let scale = min(maxDimension / CGFloat(originalWidth), maxDimension / CGFloat(originalHeight), 1.0)
            let width = Int(CGFloat(originalWidth) * scale)
            let height = Int(CGFloat(originalHeight) * scale)
            let totalPixels = width * height

            guard let context = CGContext(data: nil,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Draw downsampled image
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            guard let data = context.data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let pointer = data.bindMemory(to: UInt32.self, capacity: totalPixels)

            var totalRed: UInt64 = 0
            var totalGreen: UInt64 = 0
            var totalBlue: UInt64 = 0

            // OPTIMIZATION: Process fewer pixels due to downsampling
            for i in 0..<totalPixels {
                let color = pointer[i]
                totalRed += UInt64(color & 0xFF)
                totalGreen += UInt64((color >> 8) & 0xFF)
                totalBlue += UInt64((color >> 16) & 0xFF)
            }

            let averageRed = CGFloat(totalRed) / CGFloat(totalPixels) / 255.0
            let averageGreen = CGFloat(totalGreen) / CGFloat(totalPixels) / 255.0
            let averageBlue = CGFloat(totalBlue) / CGFloat(totalPixels) / 255.0

            let minBrightness: CGFloat = 0.5
            let isNearBlack = averageRed < 0.03 && averageGreen < 0.03 && averageBlue < 0.03

            var finalColor: NSColor

            if isNearBlack {
                finalColor = NSColor(white: minBrightness, alpha: 1.0)
            } else {
                var color = NSColor(red: averageRed, green: averageGreen, blue: averageBlue, alpha: 1.0)

                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0

                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

                if brightness < minBrightness {
                    let saturationScale = brightness / minBrightness
                    color = NSColor(hue: hue,
                                    saturation: saturation * saturationScale,
                                    brightness: minBrightness,
                                    alpha: alpha)
                }

                finalColor = color
            }

            // Cache the result
            AverageColorCache.shared.set(finalColor, for: cacheKey)

            DispatchQueue.main.async { completion(finalColor) }
        }
    }
    
    func getBrightness() -> CGFloat {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent
        
        guard let outputImage = filter.outputImage else {
            return 0
        }
        
        let context = CIContext(options: nil)
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let brightness = (0.2126 * CGFloat(bitmap[0]) + 0.7152 * CGFloat(bitmap[1]) + 0.0722 * CGFloat(bitmap[2])) / 255.0
        
        return brightness
    }
}

extension NSColor {
    // Performance optimization: Check if two colors are approximately equal
    func isApproximatelyEqual(to other: NSColor, tolerance: CGFloat = 0.05) -> Bool {
        guard let rgb1 = self.usingColorSpace(.sRGB),
              let rgb2 = other.usingColorSpace(.sRGB) else {
            return false
        }

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        rgb1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        rgb2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return abs(r1 - r2) < tolerance &&
               abs(g1 - g2) < tolerance &&
               abs(b1 - b2) < tolerance
    }
}

extension Color {
    func ensureMinimumBrightness(factor: CGFloat) -> Color {
        guard factor >= 0 && factor <= 1 else {
            return self // Return original color if factor is out of bounds
        }

        let nsColor = NSColor(self)

        // Convert to RGB color space
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return self // Return original color if conversion fails
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate perceived brightness using the formula: (0.299*R + 0.587*G + 0.114*B)
        let perceivedBrightness = (0.2126 * red + 0.7152 * green + 0.0722 * blue)

        let scale = factor / perceivedBrightness
        red = min(red * scale, 1.0)
        green = min(green * scale, 1.0)
        blue = min(blue * scale, 1.0)

        return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }
}

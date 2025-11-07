//
//  FluidGlassMaterial.swift
//  boringNotch
//
//  A dynamic, glass-like material with fluid highlights
//  that react to motion and state.
//

import SwiftUI

struct FluidGlassMaterial: View {
    @EnvironmentObject var vm: BoringViewModel

    // Overall brightness of highlights (0...1)
    var intensity: CGFloat = 0.65
    // Amount of fluid motion (0...1)
    var fluidity: CGFloat = 0.75
    // Whether to animate actively
    var isActive: Bool = true
    // External signal to amplify motion (e.g., drag/gesture magnitude)
    var amplitude: CGFloat = 0

    // OPTIMIZATION: Reduced base speed for smoother, less CPU-intensive animations
    private var baseSpeed: Double { isActive ? 0.5 : 0.1 }

    // OPTIMIZATION: Reduced FPS from 30 to 20 (33% less CPU usage)
    private var animationTimeInterval: TimeInterval {
        isActive ? 1.0/20.0 : 1.0/6.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: animationTimeInterval)) { timeline in
            contentView(timeline: timeline)
        }
    }

    @ViewBuilder
    private func contentView(timeline: TimelineView<some TimelineSchedule, some View>.Context) -> some View {
        GeometryReader { geo in
            ZStack {
                // Base frosted glass
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Caustic-like flowing highlights
                Canvas { ctx, size in
                    drawFluidEffects(ctx: ctx, size: size, timeline: timeline)
                }
                .blendMode(.softLight)
                .opacity(0.85) // OPTIMIZATION: Slightly reduced opacity
                .allowsHitTesting(false)
                .drawingGroup() // OPTIMIZATION: Enable Metal acceleration

                // Specular highlight that shifts subtly with the mouse
                SpecularHighlight(intensity: intensity)
                    .allowsHitTesting(false)
                    .blendMode(.screen)

                // Edge fresnel: subtle inner glow at edges
                edgeFresnelView
            }
        }
    }
    
    private func drawFluidEffects(ctx: GraphicsContext, size: CGSize, timeline: TimelineView<some TimelineSchedule, some View>.Context) {
        let t = timeline.date.timeIntervalSinceReferenceDate

        // Parameters scale with size and external amplitude
        let amp = 1 + min(1.5, Double(amplitude) / 18.0)
        let localFluidity = max(0.1, min(1.0, Double(fluidity)))
        let speed = baseSpeed * localFluidity * amp

        // Draw multiple elongated ellipses as moving reflective streaks
        drawStreaks(ctx: ctx, size: size, t: t, speed: speed)
        
        // Subtle vertical shimmers
        drawVerticalShimmers(ctx: ctx, size: size, t: t, speed: speed)
    }
    
    private func drawStreaks(ctx: GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let w = size.width
        let h = size.height
        let minDimension = min(w, h)

        // OPTIMIZATION: Reduced max streaks from 10 to 6 for better performance
        let maxStreaks = 6
        let minStreaks = 3
        let streakCount = Int(max(minStreaks, min(maxStreaks, Int(floor(minDimension / 50)))))

        for i in 0..<streakCount {
            let phase: Double = Double(i) * 0.37
            let timeOffset = t * speed + phase
            let progress = fmod(timeOffset, 1.0)

            let x: CGFloat = w * progress
            // OPTIMIZATION: Pre-calculate sin value once
            let sinValue = sin((t * speed * 2.1) + Double(i))
            let verticalOscillation = 0.35 + 0.3 * sinValue
            let y: CGFloat = h * verticalOscillation

            let baseEllipseW = w * 0.35 + CGFloat(i) * 8
            let maxEllipseW = w * 0.8
            let ellipseW: CGFloat = max(100, min(maxEllipseW, baseEllipseW))

            let baseEllipseH = h * 0.18 + CGFloat(i) * 2
            let maxEllipseH = h * 0.45
            let ellipseH: CGFloat = max(18, min(maxEllipseH, baseEllipseH))

            let path = Path(ellipseIn: CGRect(x: x - ellipseW / 2, y: y - ellipseH / 2, width: ellipseW, height: ellipseH))

            // Tint and gradient for a reflective feel
            let progressOffset = abs(progress - 0.5) * 1.8
            let alphaMultiplier = 1.0 - progressOffset
            let alpha: CGFloat = intensity * 0.18 * CGFloat(alphaMultiplier)

            let gradient = Gradient(colors: [
                .white.opacity(alpha * 0.85),
                .white.opacity(alpha * 0.25),
                .clear
            ])

            let startPoint = CGPoint(x: x - ellipseW / 2, y: y)
            let endPoint = CGPoint(x: x + ellipseW / 2, y: y)
            let style = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: startPoint, endPoint: endPoint
            )
            ctx.fill(path, with: style)
        }
    }
    
    private func drawVerticalShimmers(ctx: GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let w = size.width
        let h = size.height
        let columnCount = 3
        
        for j in 0..<columnCount {
            let columnProgress: Double = Double(j) / Double(columnCount)
            let phase: Double = t * speed * 0.6 + Double(j) * 0.9
            let oscillation = 0.05 * sin(phase)
            let basePosition = columnProgress * 0.8 + 0.1
            let x: CGFloat = w * (basePosition + oscillation)
            
            let rectWidth: CGFloat = max(2, w * 0.008)
            let rect = CGRect(x: x - 1, y: 0, width: rectWidth, height: h)
            let path = Path(rect)
            
            let alpha: CGFloat = intensity * 0.06
            let gradient = Gradient(colors: [
                .white.opacity(alpha * 0.0),
                .white.opacity(alpha * 1.0),
                .white.opacity(alpha * 0.0),
            ])
            
            let gradientStart = CGPoint(x: rect.minX, y: rect.minY)
            let gradientEnd = CGPoint(x: rect.maxX, y: rect.maxY)
            let style = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: gradientStart, endPoint: gradientEnd
            )
            ctx.fill(path, with: style)
        }
    }
    
    @ViewBuilder
    private var edgeFresnelView: some View {
        GeometryReader { localGeo in
            let minDimension = min(localGeo.size.height, localGeo.size.width)
            let radius: CGFloat = minDimension * 0.22
            let lineWidth: CGFloat = max(1, minDimension * 0.012)
            let paddingAmount: CGFloat = max(1, minDimension * 0.01)
            
            let edgeGradient = LinearGradient(
                colors: [
                    .white.opacity(intensity * 0.16),
                    .white.opacity(intensity * 0.05),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(edgeGradient, lineWidth: lineWidth)
                .padding(paddingAmount)
                .blendMode(.screen)
                .opacity(0.9)
        }
        .allowsHitTesting(false)
    }
}

private struct SpecularHighlight: View {
    var intensity: CGFloat
    @State private var localMouse: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cx: CGFloat = size.width * 0.5
            let cy: CGFloat = size.height * 0.25

            // Animate highlight gently based on mouse proximity to the view center
            let mouse = NSEvent.mouseLocation
            // Convert global mouse to an arbitrary oscillation to avoid NSWindow dependency
            let dx: CGFloat = CGFloat(sin(mouse.x * 0.01))
            let dy: CGFloat = CGFloat(cos(mouse.y * 0.01))

            let highlightOffsetX = dx * size.width * 0.12
            let highlightOffsetY = dy * size.height * 0.10
            let highlightCenter = CGPoint(
                x: cx + highlightOffsetX,
                y: cy + highlightOffsetY
            )

            let centerNormalized = UnitPoint(
                x: highlightCenter.x / size.width,
                y: highlightCenter.y / size.height
            )
            
            let minDimension = min(size.width, size.height)
            let startRadius: CGFloat = max(8, minDimension * 0.08)
            let endRadius: CGFloat = max(60, minDimension * 0.65)

            RadialGradient(
                colors: [
                    .white.opacity(intensity * 0.22),
                    .white.opacity(intensity * 0.08),
                    .clear
                ],
                center: centerNormalized,
                startRadius: startRadius,
                endRadius: endRadius
            )
        }
    }
}

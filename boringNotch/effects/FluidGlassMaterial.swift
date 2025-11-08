//
//  FluidGlassMaterial.swift
//  boringNotch
//
//  Apple Liquid Glassマテリアル - 動きと状態に反応する流動的なハイライトを持つ、
//  ダイナミックなガラスのようなマテリアル。AppleのLiquid Glassデザインの完全再現。
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

    private var baseSpeed: Double { isActive ? 0.5 : 0.12 }

    private var animationTimeInterval: TimeInterval {
        isActive ? 1.0/60.0 : 1.0/12.0
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
                // Layer 1: Base ultra-thin material for deep background blur
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .opacity(0.85)

                // Layer 2: Secondary material for depth
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.7)

                // Layer 3: Liquid glass refraction layer
                Canvas { ctx, size in
                    drawLiquidGlassRefraction(ctx: ctx, size: size, timeline: timeline)
                }
                .blendMode(.overlay)
                .opacity(0.4)
                .allowsHitTesting(false)

                // Layer 4: Fluid flowing highlights
                Canvas { ctx, size in
                    drawFluidEffects(ctx: ctx, size: size, timeline: timeline)
                }
                .blendMode(.plusLighter)
                .opacity(0.6)
                .allowsHitTesting(false)

                // Layer 5: Subtle specular highlight
                SpecularHighlight(intensity: intensity * 0.7)
                    .allowsHitTesting(false)
                    .blendMode(.screen)
                    .opacity(0.5)

                // Layer 6: Edge fresnel with refraction
                edgeFresnelView

                // Layer 7: Depth shadow for material thickness
                depthShadowView
            }
        }
    }
    
    // MARK: - リキッドグラス屈折レイヤー

    private func drawLiquidGlassRefraction(ctx: GraphicsContext, size: CGSize, timeline: TimelineView<some TimelineSchedule, some View>.Context) {
        let t = timeline.date.timeIntervalSinceReferenceDate
        let speed = baseSpeed * 0.3

        // Draw organic, flowing shapes that simulate glass refraction
        let waveCount = 4
        for i in 0..<waveCount {
            let phase = Double(i) * 1.57 // π/2 offset
            let waveProgress = sin(t * speed + phase)

            let centerX = size.width * (0.3 + 0.4 * CGFloat(i) / CGFloat(waveCount))
            let centerY = size.height * (0.4 + 0.2 * CGFloat(waveProgress))

            let radiusW = size.width * (0.25 + 0.1 * CGFloat(cos(t * speed * 1.3 + phase)))
            let radiusH = size.height * (0.35 + 0.15 * CGFloat(sin(t * speed * 0.9 + phase)))

            let path = Path(ellipseIn: CGRect(
                x: centerX - radiusW / 2,
                y: centerY - radiusH / 2,
                width: radiusW,
                height: radiusH
            ))

            let gradient = Gradient(colors: [
                .white.opacity(0.12),
                .white.opacity(0.06),
                .white.opacity(0.02),
                .clear
            ])

            let style = GraphicsContext.Shading.radialGradient(
                gradient,
                center: CGPoint(x: centerX, y: centerY),
                startRadius: 0,
                endRadius: max(radiusW, radiusH) / 2
            )

            ctx.fill(path, with: style)
        }
    }

    // MARK: - 流体エフェクト

    private func drawFluidEffects(ctx: GraphicsContext, size: CGSize, timeline: TimelineView<some TimelineSchedule, some View>.Context) {
        let t = timeline.date.timeIntervalSinceReferenceDate

        // Parameters scale with size and external amplitude
        let amp = 1 + min(1.2, Double(amplitude) / 20.0)
        let localFluidity = max(0.1, min(1.0, Double(fluidity)))
        let speed = baseSpeed * localFluidity * amp

        // Draw smooth, flowing liquid streaks
        drawLiquidStreaks(ctx: ctx, size: size, t: t, speed: speed)

        // Subtle vertical shimmer columns
        drawVerticalShimmers(ctx: ctx, size: size, t: t, speed: speed)

        // Organic ripple effects
        drawRippleEffect(ctx: ctx, size: size, t: t, speed: speed)
    }
    
    // MARK: - リキッドストリーク（滑らかに流れるハイライト）

    private func drawLiquidStreaks(ctx: GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let w = size.width
        let h = size.height
        let minDimension = min(w, h)

        // Fewer, more elegant streaks
        let streakCount = max(3, min(6, Int(minDimension / 60)))

        for i in 0..<streakCount {
            let phase: Double = Double(i) * 0.52
            let timeOffset = t * speed * 0.8 + phase
            let progress = fmod(timeOffset, 1.0)

            // Smooth horizontal movement
            let x: CGFloat = w * progress

            // Organic vertical oscillation with multiple harmonics
            let oscillation1 = sin((t * speed * 1.8) + Double(i) * 0.7)
            let oscillation2 = sin((t * speed * 0.9) + Double(i) * 1.3) * 0.5
            let verticalOscillation = 0.4 + 0.25 * (oscillation1 + oscillation2)
            let y: CGFloat = h * verticalOscillation

            // Smoother, more organic ellipse sizing
            let sizePhase = sin(t * speed * 0.6 + phase)
            let ellipseW: CGFloat = w * (0.3 + 0.15 * CGFloat(sizePhase))
            let ellipseH: CGFloat = h * (0.15 + 0.08 * CGFloat(cos(t * speed * 0.7 + phase)))

            let path = Path(ellipseIn: CGRect(
                x: x - ellipseW / 2,
                y: y - ellipseH / 2,
                width: ellipseW,
                height: ellipseH
            ))

            // Softer, more subtle gradient
            let fadeIn = 1.0 - pow(abs(progress - 0.5) * 2, 1.5)
            let alpha: CGFloat = intensity * 0.12 * CGFloat(fadeIn)

            let gradient = Gradient(colors: [
                .white.opacity(alpha * 0.9),
                .white.opacity(alpha * 0.4),
                .white.opacity(alpha * 0.1),
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

    // MARK: - 波紋エフェクト

    private func drawRippleEffect(ctx: GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5

        // Create expanding ripples
        let rippleCount = 3
        for i in 0..<rippleCount {
            let phase = Double(i) * 0.666 // Stagger ripples
            let rippleProgress = fmod(t * speed * 0.4 + phase, 1.0)

            let radius = max(size.width, size.height) * CGFloat(rippleProgress) * 0.8
            let fadeOut = 1.0 - pow(rippleProgress, 2.0)

            let ripplePath = Path(ellipseIn: CGRect(
                x: centerX - radius,
                y: centerY - radius,
                width: radius * 2,
                height: radius * 2
            ))

            let alpha = intensity * 0.08 * CGFloat(fadeOut)

            let gradient = Gradient(colors: [
                .clear,
                .white.opacity(alpha * 0.6),
                .white.opacity(alpha),
                .white.opacity(alpha * 0.6),
                .clear
            ])

            let style = GraphicsContext.Shading.radialGradient(
                gradient,
                center: CGPoint(x: centerX, y: centerY),
                startRadius: radius * 0.85,
                endRadius: radius
            )

            ctx.stroke(ripplePath, with: style, lineWidth: 2)
        }
    }
    
    // MARK: - 垂直シマー

    private func drawVerticalShimmers(ctx: GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let w = size.width
        let h = size.height
        let columnCount = 5

        for j in 0..<columnCount {
            let columnProgress: Double = Double(j) / Double(columnCount)
            let phase: Double = t * speed * 0.5 + Double(j) * 1.2

            // More subtle horizontal oscillation
            let oscillation = 0.03 * sin(phase)
            let basePosition = columnProgress * 0.9 + 0.05
            let x: CGFloat = w * (basePosition + oscillation)

            // Variable shimmer width
            let widthVariation = 1.0 + 0.5 * sin(t * speed * 0.8 + Double(j))
            let rectWidth: CGFloat = max(1.5, w * 0.006 * CGFloat(widthVariation))

            let rect = CGRect(x: x - rectWidth / 2, y: 0, width: rectWidth, height: h)
            let path = Path(rect)

            // Pulsing opacity
            let pulse = 0.7 + 0.3 * sin(t * speed * 1.1 + Double(j) * 0.8)
            let alpha: CGFloat = intensity * 0.05 * CGFloat(pulse)

            let gradient = Gradient(colors: [
                .white.opacity(0),
                .white.opacity(alpha * 0.3),
                .white.opacity(alpha),
                .white.opacity(alpha * 0.3),
                .white.opacity(0)
            ])

            let gradientStart = CGPoint(x: x, y: 0)
            let gradientEnd = CGPoint(x: x, y: h)
            let style = GraphicsContext.Shading.linearGradient(
                gradient, startPoint: gradientStart, endPoint: gradientEnd
            )
            ctx.fill(path, with: style)
        }
    }
    
    // MARK: - エッジフレネル（ガラス端の屈折）

    @ViewBuilder
    private var edgeFresnelView: some View {
        GeometryReader { localGeo in
            let minDimension = min(localGeo.size.height, localGeo.size.width)
            let radius: CGFloat = minDimension * 0.22
            let lineWidth: CGFloat = max(1.5, minDimension * 0.015)
            let paddingAmount: CGFloat = max(0.5, minDimension * 0.008)

            // Multiple edge layers for depth
            ZStack {
                // Outer edge - bright highlight
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(intensity * 0.25),
                                .white.opacity(intensity * 0.12),
                                .white.opacity(intensity * 0.06),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth * 0.8
                    )
                    .padding(paddingAmount)
                    .blendMode(.screen)

                // Inner edge - subtle glow
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(intensity * 0.08),
                                .white.opacity(intensity * 0.04),
                                .clear
                            ],
                            startPoint: .bottomTrailing,
                            endPoint: .topLeading
                        ),
                        lineWidth: lineWidth * 1.5
                    )
                    .padding(paddingAmount * 2)
                    .blendMode(.plusLighter)
                    .opacity(0.6)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 深度シャドウ（マテリアルの厚みシミュレーション）

    @ViewBuilder
    private var depthShadowView: some View {
        GeometryReader { localGeo in
            let minDimension = min(localGeo.size.height, localGeo.size.width)
            let radius: CGFloat = minDimension * 0.22

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.12),
                            .black.opacity(0.05),
                            .clear,
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
                .opacity(0.4)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - スペキュラーハイライト（微細な光の反射）

private struct SpecularHighlight: View {
    var intensity: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            GeometryReader { geo in
                let size = geo.size
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Primary highlight position with gentle drift
                let cx: CGFloat = size.width * (0.5 + 0.08 * CGFloat(sin(t * 0.3)))
                let cy: CGFloat = size.height * (0.3 + 0.05 * CGFloat(cos(t * 0.4)))

                // Mouse-reactive offset (subtle)
                let mouse = NSEvent.mouseLocation
                let dx: CGFloat = CGFloat(sin(mouse.x * 0.008)) * 0.03
                let dy: CGFloat = CGFloat(cos(mouse.y * 0.008)) * 0.03

                let highlightCenter = CGPoint(
                    x: cx + dx * size.width,
                    y: cy + dy * size.height
                )

                let centerNormalized = UnitPoint(
                    x: highlightCenter.x / size.width,
                    y: highlightCenter.y / size.height
                )

                let minDimension = min(size.width, size.height)
                let startRadius: CGFloat = max(5, minDimension * 0.05)
                let endRadius: CGFloat = max(40, minDimension * 0.55)

                ZStack {
                    // Main specular highlight
                    RadialGradient(
                        colors: [
                            .white.opacity(intensity * 0.18),
                            .white.opacity(intensity * 0.08),
                            .white.opacity(intensity * 0.03),
                            .clear
                        ],
                        center: centerNormalized,
                        startRadius: startRadius,
                        endRadius: endRadius
                    )

                    // Secondary softer highlight
                    RadialGradient(
                        colors: [
                            .white.opacity(intensity * 0.08),
                            .white.opacity(intensity * 0.02),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.5),
                        startRadius: minDimension * 0.1,
                        endRadius: minDimension * 0.7
                    )
                    .opacity(0.7)
                }
            }
        }
    }
}

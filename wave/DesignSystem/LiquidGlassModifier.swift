//
//  LiquidGlassModifier.swift
//  wave
//
//  Created by Design System Lead & UI/UX Architect.
//

import SwiftUI

// MARK: - Real Liquid Glass Surface (iOS 26+)

/// Applies the real iOS 26 Liquid Glass material via `.glassEffect()`.
/// Enhanced with specular edge reflection and natural depth shadow.
struct LiquidGlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil
    var tintOpacity: Double = 0.08
    var specularHighlight: Bool = true
    var shadowRadius: CGFloat = 14

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(Color.waveSurfaceElevated)
                .clipShape(shape)
                .overlay(shape.stroke(Color.waveBorder, lineWidth: 1))
        } else if #available(iOS 26, *) {
            content
                .background {
                    if let tint {
                        shape.fill(tint.opacity(tintOpacity))
                    }
                }
                .glassEffect(.regular, in: shape)
                .overlay {
                    if specularHighlight {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    }
                }
                .shadow(color: Color.black.opacity(0.14), radius: shadowRadius, x: 0, y: 6)
        } else {
            // iOS 16–25 fallback: frosted Material, no Liquid Glass.
            content
                .background(.ultraThinMaterial, in: shape)
                .background {
                    if let tint {
                        shape.fill(tint.opacity(tintOpacity))
                    }
                }
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.14), radius: shadowRadius, x: 0, y: 6)
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Applies real Liquid Glass surface with specular highlights and soft shadow.
    func liquidGlassSurface(
        cornerRadius: CGFloat = 20,
        tint: Color? = nil,
        tintOpacity: Double = 0.08,
        specularHighlight: Bool = true,
        shadowRadius: CGFloat = 14
    ) -> some View {
        self.modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                tintOpacity: tintOpacity,
                specularHighlight: specularHighlight,
                shadowRadius: shadowRadius
            )
        )
    }

    /// Applies real Liquid Glass to a Capsule shape — for dock bars and pill controls.
    func liquidGlassCapsule(
        tint: Color? = nil,
        tintOpacity: Double = 0.08,
        specularHighlight: Bool = true,
        shadowRadius: CGFloat = 14
    ) -> some View {
        self.modifier(
            LiquidGlassCapsuleModifier(
                tint: tint,
                tintOpacity: tintOpacity,
                specularHighlight: specularHighlight,
                shadowRadius: shadowRadius
            )
        )
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    var tint: Color? = nil
    var tintOpacity: Double = 0.08
    var specularHighlight: Bool = true
    var shadowRadius: CGFloat = 14
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = Capsule()
        if reduceTransparency {
            content
                .background(Color.waveSurfaceElevated)
                .clipShape(shape)
                .overlay(shape.stroke(Color.waveBorder, lineWidth: 1))
        } else if #available(iOS 26, *) {
            content
                .background {
                    if let tint {
                        shape.fill(tint.opacity(tintOpacity))
                    }
                }
                .glassEffect(.regular, in: shape)
                .overlay {
                    if specularHighlight {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    }
                }
                .shadow(color: Color.black.opacity(0.14), radius: shadowRadius, x: 0, y: 6)
        } else {
            // iOS 16–25 fallback: frosted Material, no Liquid Glass.
            content
                .background(.ultraThinMaterial, in: shape)
                .background {
                    if let tint {
                        shape.fill(tint.opacity(tintOpacity))
                    }
                }
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.14), radius: shadowRadius, x: 0, y: 6)
        }
    }
}

// MARK: - GlassEffectContainer convenience

/// A container that lets enclosed `.glassEffect()` views morph fluidly into each other.
/// Wraps SwiftUI's `GlassEffectContainer` — use this for groups of glass buttons/controls.
struct WaveGlassContainer<Content: View>: View {
    let content: Content
    let spacing: CGFloat

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

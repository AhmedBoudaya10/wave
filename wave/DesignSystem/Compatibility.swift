//
//  Compatibility.swift
//  wave
//
//  iOS 16+ fallbacks: Liquid Glass only on iOS 26+, haptics/symbols only on iOS 17+.
//

import SwiftUI

extension View {
    // MARK: - Glass fallbacks (iOS 26+ only)

    @ViewBuilder
    func waveGlassCircle(tint: Color) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(tint), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func waveGlassRounded(tint: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                .regular.tint(tint),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    // MARK: - Symbol / transition fallbacks (iOS 17+ only)

    @ViewBuilder
    func compatBounce<Value: Equatable>(value: Value) -> some View {
        if #available(iOS 17, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatSymbolReplaceTransition() -> some View {
        if #available(iOS 17, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    @ViewBuilder
    func compatVariableColorWaveform() -> some View {
        if #available(iOS 17, *) {
            self.symbolEffect(.variableColor.cumulative, isActive: true)
        } else {
            self
        }
    }

    // MARK: - Haptics fallbacks (iOS 17+ only)

    @ViewBuilder
    func compatImpactLight<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17, *) {
            self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatImpactLight<T: Equatable>(trigger: T, intensity: Double) -> some View {
        if #available(iOS 17, *) {
            self.sensoryFeedback(.impact(weight: .light, intensity: intensity), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatImpactMedium<T: Equatable>(trigger: T, intensity: Double = 0.85) -> some View {
        if #available(iOS 17, *) {
            self.sensoryFeedback(.impact(weight: .medium, intensity: intensity), trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatSuccess<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17, *) {
            self.sensoryFeedback(.success, trigger: trigger)
        } else {
            self
        }
    }

    // MARK: - Other version-gated modifiers

    @ViewBuilder
    func compatScrollEdgeTop() -> some View {
        if #available(iOS 26, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    func compatPresentationMaterial() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.ultraThinMaterial)
        } else {
            self
        }
    }
}

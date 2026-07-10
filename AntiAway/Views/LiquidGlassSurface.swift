import SwiftUI

/// Uses the system's Liquid Glass when running on macOS Tahoe or later while
/// preserving a native material fallback for supported earlier macOS releases.
struct LiquidGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

extension View {
    func liquidGlassSurface() -> some View {
        modifier(LiquidGlassSurface())
    }
}

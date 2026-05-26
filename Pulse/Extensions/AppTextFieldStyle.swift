import SwiftUI

enum AppTextFieldVariant {
    case standalone
    case inset
}

private struct AppTextFieldStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let variant: AppTextFieldVariant
    let isFocused: Bool

    func body(content: Content) -> some View {
        switch variant {
        case .standalone:
            content
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    isFocused
                                        ? Color.appAccent.opacity(0.5)
                                        : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear),
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: colorScheme == .light ? Color.black.opacity(0.04) : Color.clear,
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                }
        case .inset:
            content
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isFocused ? Color.appAccent.opacity(0.5) : Color.clear,
                                    lineWidth: 1
                                )
                        }
                }
        }
    }
}

extension View {
    func appTextFieldStyle(_ variant: AppTextFieldVariant = .standalone, isFocused: Bool = false) -> some View {
        modifier(AppTextFieldStyleModifier(variant: variant, isFocused: isFocused))
    }
}

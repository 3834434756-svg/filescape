import SwiftUI

/// 全局视觉主题：深空底 + 玻璃卡片 + 类型色点缀。
enum Theme {
    static let bg0 = Color(red: 0.043, green: 0.051, blue: 0.078)
    static let bg1 = Color(red: 0.082, green: 0.094, blue: 0.133)
    static let bg2 = Color(red: 0.118, green: 0.133, blue: 0.180)

    static let stroke = Color.white.opacity(0.09)
    static let strokeStrong = Color.white.opacity(0.18)

    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.36)

    static let accent = Color(red: 0.42, green: 0.68, blue: 1.00)

    /// 深空背景：中心略亮的径向渐变，让画布有纵深感。
    static var backdrop: some View {
        ZStack {
            bg0
            RadialGradient(
                colors: [Color(red: 0.13, green: 0.16, blue: 0.26).opacity(0.85), .clear],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 20,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

/// 玻璃质感卡片容器。
struct GlassPanel: ViewModifier {
    var radius: CGFloat = 18
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(strong ? Theme.bg2 : Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassPanel(radius: CGFloat = 18, strong: Bool = false) -> some View {
        modifier(GlassPanel(radius: radius, strong: strong))
    }
}

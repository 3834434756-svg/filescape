import SwiftUI

enum RadialAction: String, CaseIterable, Identifiable {
    case open, preview, rename, duplicate, moveUp, delete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open:      return "打开"
        case .preview:   return "预览"
        case .rename:    return "重命名"
        case .duplicate: return "复制一份"
        case .moveUp:    return "移到上级"
        case .delete:    return "删除"
        }
    }

    var symbol: String {
        switch self {
        case .open:      return "arrow.down.forward.square"
        case .preview:   return "eye"
        case .rename:    return "pencil"
        case .duplicate: return "plus.square.on.square"
        case .moveUp:    return "arrow.up.to.line"
        case .delete:    return "trash"
        }
    }

    var danger: Bool { self == .delete }
}

/// 长按卡片弹出的环形操作菜单。
/// 用圆形排布代替系统 ActionSheet —— 手指按下的位置就是圆心，视线不用跑。
struct RadialMenu: View {
    let item: FileItem
    let onDismiss: () -> Void
    let onAction: (RadialAction) -> Void

    @State private var appeared = false

    private var actions: [RadialAction] {
        item.isDirectory
            ? [.open, .rename, .duplicate, .moveUp, .delete]
            : [.preview, .rename, .duplicate, .moveUp, .delete]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.66)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Image(systemName: item.kind.symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(item.kind.tint)
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 54)
                    Text(item.sizeText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }

                ZStack {
                    Circle()
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                        .frame(width: 184, height: 184)

                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        button(action)
                            .offset(radialOffset(index: index, total: actions.count))
                            .scaleEffect(appeared ? 1 : 0.35)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.68)
                                    .delay(Double(index) * 0.035),
                                value: appeared
                            )
                    }
                }
                .frame(width: 250, height: 250)
            }
        }
        .onAppear { appeared = true }
    }

    private func radialOffset(index: Int, total: Int) -> CGSize {
        let angle = Double(index) / Double(max(total, 1)) * 2 * Double.pi - Double.pi / 2
        let radius: CGFloat = 92
        return CGSize(width: CGFloat(cos(angle)) * radius, height: CGFloat(sin(angle)) * radius)
    }

    private func button(_ action: RadialAction) -> some View {
        Button {
            onAction(action)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: action.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(action.danger
                                     ? Color(red: 1.0, green: 0.36, blue: 0.36)
                                     : Theme.textPrimary)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Theme.bg2))
                    .overlay(
                        Circle().strokeBorder(
                            action.danger
                                ? Color(red: 1.0, green: 0.36, blue: 0.36).opacity(0.45)
                                : Theme.strokeStrong,
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)

                Text(action.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

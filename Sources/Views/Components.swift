import SwiftUI

/// 确定性伪随机：同样的输入永远得到同样的 [0,1) 值。
/// 画布上的"手抖"偏移必须可复现，否则每次刷新卡片都会乱跳。
func hash01(_ s: String, _ salt: Int) -> CGFloat {
    var h: UInt64 = 5381
    for b in s.utf8 {
        h = (h &* 33) &+ UInt64(b)
    }
    h = h &+ UInt64(bitPattern: Int64(salt)) &* 2654435761
    h ^= h >> 33
    h = h &* 0xff51afd7ed558ccd
    h ^= h >> 33
    return CGFloat(h % 100_000) / 100_000.0
}

/// 顶部浮出的提示条。
struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glassPanel(radius: 22, strong: true)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }
}

/// 圆形图标按钮。
struct CircleIconButton: View {
    let symbol: String
    var active: Bool = false
    var tint: Color = Theme.accent
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(active ? Color.black : Theme.textPrimary)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(active ? tint : Color.white.opacity(0.07))
                )
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 四种浏览视角的切换轨道。
struct ModeRail: View {
    @EnvironmentObject var store: FileStore

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        store.viewMode = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 11, weight: .bold))
                        Text(mode.label)
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(store.viewMode == mode ? Color.black : Theme.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(store.viewMode == mode ? Theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

/// 空状态。
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 统一的卡片交互：单击选中，双击打开（文件夹进入 / 文件预览）。
/// 四个视图共用，保证手感一致。
private struct FileInteraction: ViewModifier {
    let item: FileItem
    @EnvironmentObject var store: FileStore

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                store.enter(item)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.selection = (store.selection?.id == item.id) ? nil : item
                }
            }
    }
}

extension View {
    func fileInteraction(_ item: FileItem) -> some View {
        modifier(FileInteraction(item: item))
    }
}

/// 类型色点 + 文字的小标签。
struct KindTag: View {
    let kind: FileKind
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(kind.tint)
                .frame(width: 7, height: 7)
            Text(kind.label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

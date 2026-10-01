import SwiftUI
import UIKit

/// 星图 —— 主视角。
///
/// 不做文件夹列表，而是把文件按类型聚成"星团"，散落在可缩放平移的画布上。
/// 每个星团的圆心按类型数量均分在一个大圆上，团内成员再绕小圆排布，
/// 位置由 `hash01` 决定，保证同一批文件每次渲染都在同一处。
struct CanvasView: View {
    @EnvironmentObject var store: FileStore

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var radialItem: FileItem?

    private let cardW: CGFloat = 132
    private let cardH: CGFloat = 122

    var body: some View {
        GeometryReader { geo in
            let items = store.visibleItems
            let positions = layout(items: items, size: geo.size)

            ZStack {
                // ── 内容层：随缩放/平移变换
                ZStack {
                    starField
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { fit(items: items, size: geo.size) }

                    ForEach(items) { item in
                        if let p = positions[item.id] {
                            card(item, at: p)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(dragGesture.simultaneously(with: magnifyGesture))

                // ── 浮层：不随画布变换
                if items.isEmpty {
                    EmptyStateView(
                        symbol: store.searchText.isEmpty ? "tray" : "magnifyingglass",
                        title: store.searchText.isEmpty ? "这里是空的" : "没有匹配的文件",
                        hint: store.searchText.isEmpty
                            ? "点右下角「+」从 iCloud 或「文件」App 导入，\n也可以用数据线连电脑把文件拖进来"
                            : "换个关键词试试"
                    )
                }

                zoomControls(items: items, size: geo.size)

                if let item = radialItem {
                    RadialMenu(
                        item: item,
                        onDismiss: { radialItem = nil },
                        onAction: { action in
                            radialItem = nil
                            perform(action, on: item)
                        }
                    )
                }
            }
            .onAppear {
                fit(items: items, size: geo.size)
            }
        }
        // 换目录时整棵子树重建，重新触发下面的取景
        .id(store.currentDirectory.path)
    }

    // MARK: - 卡片

    private func card(_ item: FileItem, at point: CGPoint) -> some View {
        FileCardView(item: item, selected: store.selection?.id == item.id, style: .canvas)
            .position(point)
            .onTapGesture(count: 2) {
                store.enter(item)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.selection = (store.selection?.id == item.id) ? nil : item
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                radialItem = item
            }
    }

    // MARK: - 手势

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in baseOffset = offset }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(baseScale * value, 0.35), 3.0)
            }
            .onEnded { _ in baseScale = scale }
    }

    // MARK: - 取景

    private func zoomControls(items: [FileItem], size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 9) {
                    CircleIconButton(symbol: "plus", size: 34) {
                        applyScale(scale + 0.25)
                    }
                    CircleIconButton(symbol: "minus", size: 34) {
                        applyScale(scale - 0.25)
                    }
                    CircleIconButton(symbol: "scope", size: 34) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            fit(items: items, size: size)
                        }
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 96)
            }
        }
    }

    private func applyScale(_ newValue: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            scale = min(max(newValue, 0.35), 3.0)
            baseScale = scale
        }
    }

    /// 按内容包围盒自动取景，保证一屏能看到全部卡片。
    private func fit(items: [FileItem], size: CGSize) {
        let positions = layout(items: items, size: size)
        guard !positions.isEmpty else { return }

        let xs = positions.values.map(\.x)
        let ys = positions.values.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return }

        let boxW = (maxX - minX) + cardW
        let boxH = (maxY - minY) + cardH
        guard boxW > 0, boxH > 0 else { return }

        let fitted = min(size.width / boxW, size.height / boxH) * 0.9
        scale = min(max(fitted, 0.35), 1.6)
        baseScale = scale

        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2
        offset = CGSize(width: (size.width / 2 - cx) * scale,
                        height: (size.height / 2 - cy) * scale)
        baseOffset = offset
    }

    // MARK: - 布局

    private func layout(items: [FileItem], size: CGSize) -> [String: CGPoint] {
        guard !items.isEmpty, size.width > 0 else { return [:] }

        let groups = Dictionary(grouping: items, by: { $0.kind })
        let kinds = FileKind.allCases.filter { !(groups[$0] ?? []).isEmpty }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var out: [String: CGPoint] = [:]
        let clusterCount = kinds.count
        let ringR = clusterCount <= 1 ? 0 : min(size.width, size.height) * 0.21

        for (ci, kind) in kinds.enumerated() {
            let members = groups[kind] ?? []

            var clusterCenter = center
            if clusterCount > 1 {
                let angle = Double(ci) / Double(clusterCount) * 2 * Double.pi - Double.pi / 2
                clusterCenter = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * ringR,
                    y: center.y + CGFloat(sin(angle)) * ringR
                )
            }

            let count = members.count
            let innerR: CGFloat = count <= 1 ? 0 : min(104, 20 + CGFloat(count) * 6)

            for (mi, item) in members.enumerated() {
                let t = Double(mi) / Double(max(count, 1))
                let angle = t * 2 * Double.pi + Double(ci) * 0.8
                let jx = (hash01(item.id, 11) - 0.5) * 24
                let jy = (hash01(item.id, 22) - 0.5) * 24
                out[item.id] = CGPoint(
                    x: clusterCenter.x + CGFloat(cos(angle)) * innerR + jx,
                    y: clusterCenter.y + CGFloat(sin(angle)) * innerR + jy
                )
            }
        }
        return out
    }

    // MARK: - 背景星点

    private var starField: some View {
        Canvas { ctx, size in
            for i in 0..<110 {
                let x = hash01("star-x-\(i)", 3) * size.width
                let y = hash01("star-y-\(i)", 4) * size.height
                let r = 0.5 + hash01("star-r-\(i)", 5) * 1.5
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.06 + hash01("star-o-\(i)", 6) * 0.22))
                )
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - 环形菜单动作

    private func perform(_ action: RadialAction, on item: FileItem) {
        switch action {
        case .open:
            store.enter(item)
        case .preview:
            store.previewTarget = item
        case .rename:
            store.sheet = .rename(item)
        case .duplicate:
            store.duplicate(item)
        case .moveUp:
            let parent = store.currentDirectory.deletingLastPathComponent()
            store.move(item, into: parent)
        case .delete:
            store.deleteTarget = item
        }
    }
}

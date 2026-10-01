import SwiftUI

/// 类型看板：每个文件类型一张大卡，直接看总量和构成。
/// 点进去才是该类型的完整列表 —— 先给结论，再给细节。
struct KindBoardView: View {
    @EnvironmentObject var store: FileStore
    @State private var expanded: FileKind?

    private let columns = [
        GridItem(.flexible(), spacing: 13),
        GridItem(.flexible(), spacing: 13)
    ]

    var body: some View {
        Group {
            if store.kindGroups.isEmpty {
                EmptyStateView(
                    symbol: "square.stack.3d.up",
                    title: "没有可分类的内容",
                    hint: "当前目录是空的，或搜索没有命中"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(store.kindGroups, id: \.kind) { group in
                            panel(kind: group.kind, items: group.items)
                        }
                    }
                    .padding(15)
                }
            }
        }
        .sheet(item: $expanded) { kind in
            KindDetailSheet(kind: kind)
                .environmentObject(store)
        }
    }

    private func panel(kind: FileKind, items: [FileItem]) -> some View {
        let bytes = items.reduce(Int64(0)) { $0 + $1.size }

        return Button {
            expanded = kind
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(kind.tint)
                    Text(kind.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(items.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(kind.tint)
                }

                mosaic(items: items, tint: kind.tint)

                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    /// 最多展示 4 个成员的小拼贴。
    @ViewBuilder
    private func mosaic(items: [FileItem], tint: Color) -> some View {
        let preview = Array(items.prefix(4))
        HStack(spacing: 6) {
            ForEach(preview) { item in
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.16))
                    Image(systemName: item.kind.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(height: 46)
            }
            if preview.count < 4 {
                ForEach(0..<(4 - preview.count), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .frame(height: 46)
                }
            }
        }
    }
}

/// 单个类型的完整文件列表。
private struct KindDetailSheet: View {
    let kind: FileKind
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss

    private var items: [FileItem] {
        store.visibleItems.filter { $0.kind == kind }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 11)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(items) { item in
                            FileCardView(
                                item: item,
                                selected: store.selection?.id == item.id,
                                style: .chrono
                            )
                            .fileInteraction(item)
                        }
                    }
                    .padding(15)
                }
            }
            .navigationTitle("\(kind.label) · \(items.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

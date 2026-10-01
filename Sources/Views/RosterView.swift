import SwiftUI

/// 清单：四个视角里唯一的"传统"视图。
/// 前三个负责好看和快速定位，这个负责精确和高效 —— 扫一遍看全部。
struct RosterView: View {
    @EnvironmentObject var store: FileStore

    var body: some View {
        Group {
            if store.visibleItems.isEmpty {
                EmptyStateView(
                    symbol: "list.bullet",
                    title: "没有内容",
                    hint: "当前目录是空的"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        summaryHeader
                        ForEach(store.visibleItems) { item in
                            row(item)
                            Rectangle()
                                .fill(Theme.stroke)
                                .frame(height: 1)
                                .padding(.leading, 62)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 8) {
            Text("\(store.visibleItems.count) 项")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("·")
                .foregroundStyle(Theme.textTertiary)
            Text(store.totalSizeText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func row(_ item: FileItem) -> some View {
        let isSelected = store.selection?.id == item.id

        return HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(item.kind.tint.opacity(0.15))
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(item.kind.tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(item.sizeText)  ·  \(item.modifiedText)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(isSelected ? Theme.bg2 : Color.clear)
        .contentShape(Rectangle())
        .fileInteraction(item)
        .contextMenu {
            Button {
                store.enter(item)
            } label: {
                Label(item.isDirectory ? "打开" : "预览",
                      systemImage: item.isDirectory ? "folder" : "eye")
            }
            Button {
                store.sheet = .rename(item)
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button {
                store.duplicate(item)
            } label: {
                Label("复制一份", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(role: .destructive) {
                store.deleteTarget = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

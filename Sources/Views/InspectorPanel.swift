import SwiftUI

/// 文件详情面板。
struct InspectorPanel: View {
    let item: FileItem
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        infoGrid
                        actions
                    }
                    .padding(18)
                }
            }
            .navigationTitle("详情")
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

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [item.kind.tint.opacity(0.28), item.kind.tint.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: item.kind.symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(item.kind.tint)
            }
            .frame(width: 84, height: 84)

            Text(item.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
        }
    }

    private var infoGrid: some View {
        VStack(spacing: 0) {
            row("类型", item.isDirectory ? "文件夹" : (item.ext.isEmpty ? "未知" : item.ext))
            divider
            row("大小", item.sizeText)
            divider
            row("修改时间", item.modifiedText)
            divider
            row("所属分类", item.kind.label)
            divider
            row("位置", item.url.deletingLastPathComponent().lastPathComponent)
        }
        .glassPanel(radius: 18)
    }

    private var divider: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 14)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            actionRow("eye", "预览", tint: Theme.accent) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    store.previewTarget = item
                }
            }
            actionRow("pencil", "重命名", tint: Theme.accent) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    store.sheet = .rename(item)
                }
            }
            actionRow("plus.square.on.square", "复制一份", tint: Theme.accent) {
                store.duplicate(item)
                dismiss()
            }
            actionRow("arrow.up.to.line", "移到上一级", tint: Theme.accent) {
                let parent = store.currentDirectory.deletingLastPathComponent()
                store.move(item, into: parent)
                dismiss()
            }
            actionRow("trash", "删除", tint: Color(red: 1.0, green: 0.36, blue: 0.36)) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    store.deleteTarget = item
                }
            }
        }
    }

    private func actionRow(_ symbol: String, _ label: String,
                           tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .glassPanel(radius: 15)
        }
        .buttonStyle(.plain)
    }
}

/// 新建文件夹输入面板。
struct NewFolderSheet: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.backdrop

            VStack(alignment: .leading, spacing: 16) {
                Text("新建文件夹")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 9) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    TextField("文件夹名称", text: $text)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(commit)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

                HStack(spacing: 11) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                        .buttonStyle(.plain)

                    Button(action: commit) {
                        Text("创建")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .onAppear {
            text = "新建文件夹"
            focused = true
        }
    }

    private func commit() {
        store.createFolder(named: text)
        dismiss()
    }
}

/// 重命名输入面板。
struct RenameSheet: View {
    let item: FileItem

    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.backdrop

            VStack(alignment: .leading, spacing: 16) {
                Text("重命名")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 9) {
                    Image(systemName: item.kind.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.kind.tint)
                    TextField("新名称", text: $text)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(commit)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

                if !item.isDirectory && !item.ext.isEmpty {
                    Text("扩展名 .\(item.ext.lowercased()) 会自动保留")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }

                HStack(spacing: 11) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                        .buttonStyle(.plain)

                    Button(action: commit) {
                        Text("保存")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
            }
            .padding(20)
        }
        .onAppear {
            text = item.isDirectory
                ? item.name
                : item.url.deletingPathExtension().lastPathComponent
            focused = true
        }
    }

    private func commit() {
        store.rename(item, to: text)
        dismiss()
    }
}

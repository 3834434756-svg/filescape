import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: FileStore

    @State private var searching = false

    var body: some View {
        ZStack {
            Theme.backdrop

            VStack(spacing: 0) {
                topBar
                modeRow
                Rectangle().fill(Theme.stroke).frame(height: 1)
                content
            }

            if let item = store.selection {
                selectionBar(item)
            } else {
                fab
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 110)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.selection?.id)
        .animation(.easeOut(duration: 0.25), value: store.toast)
        .sheet(item: $store.sheet) { route in
            sheetContent(route)
        }
        .fullScreenCover(item: $store.previewTarget) { item in
            PreviewSheet(url: item.url)
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "删除「\(store.deleteTarget?.name ?? "")」？",
            isPresented: Binding(
                get: { store.deleteTarget != nil },
                set: { if !$0 { store.deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let target = store.deleteTarget {
                    store.delete(target)
                }
                store.deleteTarget = nil
            }
            Button("取消", role: .cancel) { store.deleteTarget = nil }
        } message: {
            Text("此操作不可撤销。")
        }
        .alert("出错了", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - 顶栏

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 10) {
            if searching {
                searchField
            } else {
                if !store.isAtRoot {
                    CircleIconButton(symbol: "chevron.left") { store.goUp() }
                }
                breadcrumb
                Spacer(minLength: 8)
                CircleIconButton(symbol: "magnifyingglass") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        searching = true
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // 这个属性返回"搜索框 + 取消按钮"两个平级视图，交给外层 HStack 排布，
    // 所以必须标 @ViewBuilder —— 否则 some View 的计算属性只能有一个顶层表达式。
    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)

            TextField("搜索当前目录", text: $store.searchText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))

        Button("取消") {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                searching = false
                store.searchText = ""
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Theme.accent)
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(store.breadcrumb.enumerated()), id: \.offset) { index, name in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Button {
                        store.jump(to: index)
                    } label: {
                        Text(name)
                            .font(.system(
                                size: 14,
                                weight: index == store.breadcrumb.count - 1 ? .bold : .medium
                            ))
                            .foregroundStyle(
                                index == store.breadcrumb.count - 1
                                    ? Theme.textPrimary
                                    : Theme.textSecondary
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(index == store.breadcrumb.count - 1)
                }
            }
        }
        .frame(maxWidth: 230, alignment: .leading)
    }

    // MARK: - 视角切换行

    private var modeRow: some View {
        HStack(spacing: 10) {
            ModeRail()
            Spacer(minLength: 0)
            sortMenu
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases) { order in
                Button {
                    store.setSort(order)
                } label: {
                    Label(order.label,
                          systemImage: store.sortOrder == order ? "checkmark" : order.symbol)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        switch store.viewMode {
        case .canvas: CanvasView()
        case .chrono: ChronoView()
        case .kinds:  KindBoardView()
        case .roster: RosterView()
        }
    }

    // MARK: - 悬浮操作

    private var fab: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Menu {
                    Button {
                        store.sheet = .importer
                    } label: {
                        Label("从「文件」导入", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        store.sheet = .newFolder
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Theme.accent))
                        .shadow(color: Theme.accent.opacity(0.45), radius: 16, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 32)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func selectionBar(_ item: FileItem) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(item.sizeText)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: 70, alignment: .leading)

                Rectangle().fill(Theme.stroke).frame(width: 1, height: 26)

                barButton("info.circle", "详情") { store.sheet = .inspector(item) }
                barButton("pencil", "重命名") { store.sheet = .rename(item) }
                barButton("plus.square.on.square", "复制") { store.duplicate(item) }
                barButton("trash", "删除", danger: true) { store.deleteTarget = item }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassPanel(radius: 26, strong: true)
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func barButton(_ symbol: String, _ label: String,
                           danger: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .foregroundStyle(danger ? Color(red: 1.0, green: 0.36, blue: 0.36) : Theme.textPrimary)
            .frame(width: 42)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 模态内容

    @ViewBuilder
    private func sheetContent(_ route: SheetRoute) -> some View {
        switch route {
        case .inspector(let item):
            InspectorPanel(item: item)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .rename(let item):
            RenameSheet(item: item)
                .environmentObject(store)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)

        case .newFolder:
            NewFolderSheet()
                .environmentObject(store)
                .presentationDetents([.height(230)])
                .presentationDragIndicator(.visible)

        case .importer:
            DocumentPicker { urls in
                store.sheet = nil
                store.importFiles(urls)
            }
            .ignoresSafeArea()
        }
    }
}

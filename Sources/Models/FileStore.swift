import SwiftUI
import Combine

enum SortOrder: String, CaseIterable, Identifiable {
    case name, newest, oldest, largest, kind

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name:    return "名称"
        case .newest:  return "最新优先"
        case .oldest:  return "最早优先"
        case .largest: return "体积优先"
        case .kind:    return "按类型"
        }
    }

    var symbol: String {
        switch self {
        case .name:    return "textformat.abc"
        case .newest:  return "arrow.down"
        case .oldest:  return "arrow.up"
        case .largest: return "arrow.up.left.and.arrow.down.right"
        case .kind:    return "square.stack.3d.up"
        }
    }
}

/// 当前弹出的模态面板。集中管理，避免同一个视图挂多个 `.sheet` 互相覆盖。
enum SheetRoute: Identifiable {
    case inspector(FileItem)
    case rename(FileItem)
    case newFolder
    case importer

    var id: String {
        switch self {
        case .inspector(let i): return "inspector-\(i.id)"
        case .rename(let i):    return "rename-\(i.id)"
        case .newFolder:        return "newFolder"
        case .importer:         return "importer"
        }
    }
}

/// 四种浏览方式 —— 刻意都不做成"文件夹下钻"。
enum ViewMode: String, CaseIterable, Identifiable {
    case canvas, chrono, kinds, roster

    var id: String { rawValue }

    var label: String {
        switch self {
        case .canvas: return "星图"
        case .chrono: return "时间"
        case .kinds:  return "类型"
        case .roster: return "清单"
        }
    }

    var symbol: String {
        switch self {
        case .canvas: return "circle.hexagongrid.fill"
        case .chrono: return "clock.arrow.circlepath"
        case .kinds:  return "square.stack.3d.up.fill"
        case .roster: return "list.bullet.indent"
        }
    }
}

/// 刻意不加 `@MainActor`：`@main App` 的隐式 `init` 是 nonisolated，
/// 在属性初始化器里构造一个 MainActor 隔离的类会编译失败。
/// 所有写操作都从 UI 路径触发，本身就在主线程。
final class FileStore: ObservableObject {

    @Published private(set) var rootURL: URL
    @Published private(set) var path: [URL] = []
    @Published private(set) var items: [FileItem] = []

    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .name
    @Published var viewMode: ViewMode = .canvas

    @Published var selection: FileItem?
    @Published var sheet: SheetRoute?
    @Published var previewTarget: FileItem?
    @Published var deleteTarget: FileItem?
    @Published var toast: String?
    @Published var errorMessage: String?

    private let fm = FileManager.default
    private var toastTask: Task<Void, Never>?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        rootURL = docs
        seedIfNeeded()
        reload()
    }

    // MARK: - 派生状态

    var currentDirectory: URL { path.last ?? rootURL }

    var isAtRoot: Bool { path.isEmpty }

    var breadcrumb: [String] {
        ["本机"] + path.map { $0.lastPathComponent }
    }

    var visibleItems: [FileItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var kindGroups: [(kind: FileKind, items: [FileItem])] {
        FileKind.allCases.compactMap { kind in
            let bucket = visibleItems.filter { $0.kind == kind }
            return bucket.isEmpty ? nil : (kind, bucket)
        }
    }

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    // MARK: - 导航

    func reload() {
        let dir = currentDirectory
        do {
            let urls = try fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey
                ],
                options: [.skipsHiddenFiles]
            )
            items = urls.map { FileItem(url: $0) }
            applySort()
        } catch {
            items = []
            errorMessage = "无法读取该目录：\(error.localizedDescription)"
        }
    }

    func enter(_ item: FileItem) {
        guard item.isDirectory else {
            previewTarget = item
            return
        }
        path.append(item.url)
        selection = nil
        reload()
    }

    func goUp() {
        guard !path.isEmpty else { return }
        path.removeLast()
        selection = nil
        reload()
    }

    func jump(to depth: Int) {
        guard depth >= 0, depth <= path.count else { return }
        if depth < path.count {
            path = Array(path.prefix(depth))
        }
        selection = nil
        reload()
    }

    func setSort(_ order: SortOrder) {
        sortOrder = order
        applySort()
    }

    private func applySort() {
        switch sortOrder {
        case .name:
            items.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        case .newest:
            items.sort { $0.modified > $1.modified }
        case .oldest:
            items.sort { $0.modified < $1.modified }
        case .largest:
            items.sort { $0.size > $1.size }
        case .kind:
            items.sort { a, b in
                if a.kind == b.kind { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
                return a.kind.rawValue < b.kind.rawValue
            }
        }
    }

    // MARK: - 文件操作

    func createFolder(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = name.isEmpty ? "新建文件夹" : name
        let dst = uniqueDestination(for: final)
        do {
            try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            reload()
            notify("已创建「\(dst.lastPathComponent)」")
        } catch {
            errorMessage = "创建文件夹失败：\(error.localizedDescription)"
        }
    }

    func rename(_ item: FileItem, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != item.name else { return }

        // 保留原扩展名：用户改名时一般不想动后缀
        var finalName = name
        let oldExt = item.url.pathExtension
        if !item.isDirectory, !oldExt.isEmpty,
           (name as NSString).pathExtension.isEmpty {
            finalName = "\(name).\(oldExt)"
        }

        let dst = item.url.deletingLastPathComponent().appendingPathComponent(finalName)
        guard !fm.fileExists(atPath: dst.path) else {
            errorMessage = "已存在同名项目「\(finalName)」"
            return
        }
        do {
            try fm.moveItem(at: item.url, to: dst)
            if selection?.id == item.id { selection = nil }
            reload()
            notify("已重命名为「\(finalName)」")
        } catch {
            errorMessage = "重命名失败：\(error.localizedDescription)"
        }
    }

    func delete(_ item: FileItem) {
        do {
            try fm.removeItem(at: item.url)
            if selection?.id == item.id { selection = nil }
            reload()
            notify("已删除「\(item.name)」")
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func duplicate(_ item: FileItem) {
        let base = item.url.deletingPathExtension().lastPathComponent
        let ext = item.url.pathExtension
        let candidateName = ext.isEmpty ? "\(base) 副本" : "\(base) 副本.\(ext)"
        let dst = uniqueDestination(for: candidateName)
        do {
            try fm.copyItem(at: item.url, to: dst)
            reload()
            notify("已复制为「\(dst.lastPathComponent)」")
        } catch {
            errorMessage = "复制失败：\(error.localizedDescription)"
        }
    }

    func move(_ item: FileItem, into directory: URL) {
        guard directory != item.url.deletingLastPathComponent() else { return }
        // 防止把文件夹拖进自己内部
        guard !directory.path.hasPrefix(item.url.path + "/") else {
            errorMessage = "不能把文件夹移动到它自己里面"
            return
        }
        let dst = directory.appendingPathComponent(item.name)
        guard !fm.fileExists(atPath: dst.path) else {
            errorMessage = "目标位置已有「\(item.name)」"
            return
        }
        do {
            try fm.moveItem(at: item.url, to: dst)
            if selection?.id == item.id { selection = nil }
            reload()
            notify("已移动到「\(directory.lastPathComponent)」")
        } catch {
            errorMessage = "移动失败：\(error.localizedDescription)"
        }
    }

    func importFiles(_ urls: [URL]) {
        var copied = 0
        var failed = 0
        for src in urls {
            let scoped = src.startAccessingSecurityScopedResource()
            defer { if scoped { src.stopAccessingSecurityScopedResource() } }

            let dst = uniqueDestination(for: src.lastPathComponent)
            do {
                try fm.copyItem(at: src, to: dst)
                copied += 1
            } catch {
                failed += 1
            }
        }
        reload()
        if failed == 0 {
            notify("已导入 \(copied) 个项目")
        } else {
            errorMessage = "导入 \(copied) 个成功，\(failed) 个失败"
        }
    }

    /// 在沙盒内找一个不冲突的目标路径。
    private func uniqueDestination(for name: String) -> URL {
        let dir = currentDirectory
        var candidate = dir.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension
        var i = 2
        while i < 1000 {
            let next = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
            candidate = dir.appendingPathComponent(next)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
        return dir.appendingPathComponent("\(UUID().uuidString)-\(name)")
    }

    // MARK: - 提示

    func notify(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - 首次启动放一点内容，避免空画布

    private func seedIfNeeded() {
        let marker = rootURL.appendingPathComponent(".filescape_seeded")
        guard !fm.fileExists(atPath: marker.path) else { return }

        let readme = rootURL.appendingPathComponent("关于 Filescape.txt")
        let text = """
        Filescape —— 一种不一样的看文件方式。

        这里没有"文件夹列表"，文件是散落在星图上的卡片。
        · 捏合缩放星图，拖动平移
        · 点卡片看详情，双击文件夹进入
        · 长按卡片弹出环形操作菜单
        · 左上角切换「星图 / 时间 / 类型 / 清单」四种视角

        想放文件进来：点右下角「+」，从 iCloud 或「文件」App 导入。
        也可以用数据线连电脑，在 Finder / 爱思助手里找到 Filescape，
        直接把文件拖进这个目录。

        说明：iOS 沙盒机制下，本 App 只能访问自己的目录。
        这不是权限没开，而是系统不允许任何 App 读别人的文件。
        """
        try? text.write(to: readme, atomically: true, encoding: .utf8)

        let sample = rootURL.appendingPathComponent("示例文件夹")
        try? fm.createDirectory(at: sample, withIntermediateDirectories: true)
        try? "把文件整理进这里试试。".write(
            to: sample.appendingPathComponent("说明.md"),
            atomically: true,
            encoding: .utf8
        )

        try? Data().write(to: marker)
    }
}

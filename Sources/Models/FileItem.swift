import Foundation

/// 一个文件 / 文件夹在界面上的表示。
struct FileItem: Identifiable, Hashable {
    /// 用完整路径作为稳定标识 —— 同一目录内路径唯一。
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    let kind: FileKind

    var ext: String {
        url.pathExtension.uppercased()
    }

    var sizeText: String {
        if isDirectory { return "文件夹" }
        if size < 1024 { return "\(size) B" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// 展示用的类型标签，比 rawValue 更友好。
    var typeBadge: String {
        if isDirectory { return "DIR" }
        let e = url.pathExtension.uppercased()
        return e.isEmpty ? "FILE" : e
    }

    var modifiedText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: modified)
    }

    /// 相对今天的时间描述，用于时间轴分组。
    var dayBucket: Date {
        Calendar.current.startOfDay(for: modified)
    }

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey
        ])
        let isDir = values?.isDirectory ?? false

        self.id = url.path
        self.url = url
        self.name = values?.name ?? url.lastPathComponent
        self.isDirectory = isDir
        self.modified = values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        self.kind = FileKind.detect(url: url, isDirectory: isDir)
        // 目录拿不到有意义的 fileSize，递归统计一次（限制深度避免卡顿）。
        // 这里必须在初始化时一次算完 —— `size` 是 let，不能先赋默认值再覆盖。
        self.size = isDir
            ? FileItem.directorySize(url: url, depth: 0)
            : Int64(values?.fileSize ?? 0)
    }

    private static func directorySize(url: URL, depth: Int) -> Int64 {
        guard depth < 3 else { return 0 }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for entry in entries {
            let v = try? entry.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if v?.isDirectory == true {
                total += directorySize(url: entry, depth: depth + 1)
            } else {
                total += Int64(v?.fileSize ?? 0)
            }
        }
        return total
    }
}

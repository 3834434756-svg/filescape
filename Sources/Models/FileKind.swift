import SwiftUI

/// 文件类型分类。用于画布上的分簇、类型看板、以及配色。
enum FileKind: String, CaseIterable, Identifiable {
    case folder, image, video, audio, document, archive, code, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .folder:   return "文件夹"
        case .image:    return "图片"
        case .video:    return "视频"
        case .audio:    return "音频"
        case .document: return "文档"
        case .archive:  return "压缩包"
        case .code:     return "代码"
        case .other:    return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .folder:   return "folder.fill"
        case .image:    return "photo.fill"
        case .video:    return "video.fill"
        case .audio:    return "waveform"
        case .document: return "doc.text.fill"
        case .archive:  return "shippingbox.fill"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .other:    return "doc.fill"
        }
    }

    /// 画布与看板的主色。每个类型一个明确色相，方便在空间里靠颜色定位。
    var tint: Color {
        switch self {
        case .folder:   return Color(red: 0.38, green: 0.62, blue: 1.00)
        case .image:    return Color(red: 1.00, green: 0.42, blue: 0.60)
        case .video:    return Color(red: 0.70, green: 0.42, blue: 1.00)
        case .audio:    return Color(red: 0.24, green: 0.84, blue: 0.74)
        case .document: return Color(red: 1.00, green: 0.70, blue: 0.28)
        case .archive:  return Color(red: 0.95, green: 0.55, blue: 0.32)
        case .code:     return Color(red: 0.40, green: 0.88, blue: 0.52)
        case .other:    return Color(red: 0.58, green: 0.62, blue: 0.70)
        }
    }

    private static let table: [String: FileKind] = {
        var m: [String: FileKind] = [:]
        func put(_ k: FileKind, _ exts: [String]) { for e in exts { m[e] = k } }
        put(.image,    ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "svg", "ico", "raw", "dng"])
        put(.video,    ["mp4", "mov", "m4v", "avi", "mkv", "flv", "wmv", "webm", "3gp", "ts"])
        put(.audio,    ["mp3", "m4a", "aac", "wav", "flac", "aiff", "ogg", "opus", "wma", "caf"])
        put(.document, ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key",
                        "txt", "rtf", "rtfd", "md", "csv", "epub", "mobi"])
        put(.archive,  ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "ipa", "apk", "jar", "dmg", "iso"])
        put(.code,     ["swift", "m", "mm", "h", "hpp", "c", "cpp", "cc", "cs", "java", "kt", "js", "jsx",
                        "ts", "tsx", "py", "rb", "go", "rs", "php", "sh", "zsh", "bash", "yml", "yaml",
                        "json", "xml", "plist", "html", "htm", "css", "scss", "sql", "lua", "toml", "ini"])
        return m
    }()

    static func detect(url: URL, isDirectory: Bool) -> FileKind {
        if isDirectory { return .folder }
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return .other }
        return table[ext] ?? .other
    }
}

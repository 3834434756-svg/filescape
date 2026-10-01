import UIKit
import QuickLookThumbnailing

/// 缩略图生成 + 内存缓存。
/// 用 QuickLookThumbnailing 而不是自己按类型分支，这样 PDF / Office / 视频封面都能出图。
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSString, UIImage>()
    /// 记录正在生成的 key，避免同一张图被并发重复生成。
    private var inflight = Set<String>()
    private let lock = NSLock()

    private init() {
        cache.countLimit = 400
    }

    func cached(for url: URL, size: CGSize) -> UIImage? {
        cache.object(forKey: key(url, size))
    }

    func thumbnail(for url: URL, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let k = key(url, size)

        if let hit = cache.object(forKey: k) {
            completion(hit)
            return
        }

        lock.lock()
        if inflight.contains(k as String) {
            lock.unlock()
            completion(nil)
            return
        }
        inflight.insert(k as String)
        lock.unlock()

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let self else { return }
            self.lock.lock()
            self.inflight.remove(k as String)
            self.lock.unlock()

            let image = rep?.uiImage
            if let image {
                self.cache.setObject(image, forKey: k)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func key(_ url: URL, _ size: CGSize) -> NSString {
        "\(url.path)|\(Int(size.width))x\(Int(size.height))" as NSString
    }
}

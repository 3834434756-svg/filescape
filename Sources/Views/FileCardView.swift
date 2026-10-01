import SwiftUI
import UIKit

/// 单个文件的卡片。画布、类型看板都用它，尺寸由 `style` 决定。
struct FileCardView: View {
    let item: FileItem
    var selected: Bool = false
    var style: CardStyle = .canvas

    @State private var thumb: UIImage?

    enum CardStyle {
        case canvas, board, chrono

        var width: CGFloat {
            switch self {
            case .canvas: return 132
            case .board:  return 148
            case .chrono: return 118
            }
        }

        var thumbHeight: CGFloat {
            switch self {
            case .canvas: return 74
            case .board:  return 88
            case .chrono: return 62
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailArea
            caption
        }
        .padding(9)
        .frame(width: style.width)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? Theme.bg2 : Theme.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            selected ? item.kind.tint : Theme.stroke,
                            lineWidth: selected ? 1.6 : 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.38), radius: 12, y: 6)
        .onAppear(perform: loadThumbnail)
    }

    private var thumbnailArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [item.kind.tint.opacity(0.22), item.kind.tint.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let thumb {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else {
                Image(systemName: item.kind.symbol)
                    .font(.system(size: style.thumbHeight * 0.36, weight: .medium))
                    .foregroundStyle(item.kind.tint)
            }

            // 右下角类型角标
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(item.typeBadge)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(item.kind.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.black.opacity(0.55))
                        )
                        .padding(6)
                }
            }
        }
        .frame(height: style.thumbHeight)
        .clipped()
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Text(item.sizeText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                if item.isDirectory {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func loadThumbnail() {
        guard !item.isDirectory else { return }
        // 只有这几种类型值得生成预览图，纯文本/代码生成出来是白纸，没意义
        guard item.kind == .image || item.kind == .video || item.kind == .document else { return }

        let side = style.thumbHeight * 2
        ThumbnailProvider.shared.thumbnail(
            for: item.url,
            size: CGSize(width: side, height: side)
        ) { image in
            self.thumb = image
        }
    }
}

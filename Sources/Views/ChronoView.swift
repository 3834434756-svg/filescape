import SwiftUI

/// 时间视角：按"天"把文件切成横带，越新的越靠上。
/// 不做目录层级，只回答一个问题 —— "我最近动过什么"。
struct ChronoView: View {
    @EnvironmentObject var store: FileStore

    /// 用结构体而不是元组：`ForEach` 的 `id:` 需要能取到稳定的 key path，
    /// 具名元组的 key path 在这里不可靠。
    private struct DayBucket: Identifiable {
        let date: Date
        let items: [FileItem]
        var id: Date { date }
    }

    private var buckets: [DayBucket] {
        let groups = Dictionary(grouping: store.visibleItems, by: { $0.dayBucket })
        return groups
            .map { DayBucket(date: $0.key, items: $0.value.sorted { $0.modified > $1.modified }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if buckets.isEmpty {
                EmptyStateView(
                    symbol: "clock",
                    title: "没有可显示的内容",
                    hint: "换个目录或清空搜索条件"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(buckets) { bucket in
                            band(bucket.date, bucket.items)
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
        }
    }

    private func band(_ date: Date, _ items: [FileItem]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                // 时间轴上的节点
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 5))

                Text(dayLabel(date))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(items.count) 项")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        FileCardView(
                            item: item,
                            selected: store.selection?.id == item.id,
                            style: .chrono
                        )
                        .fileInteraction(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }

        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days) 天前" }

        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = cal.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "M 月 d 日"
            : "yyyy 年 M 月 d 日"
        return f.string(from: date)
    }
}

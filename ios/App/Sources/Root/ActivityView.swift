import SwiftUI
import SwiftData
import DesignSystem
import GlassesKit
import Inject

/// The Activity tab — a dashboard over the real vision history: a 14-day activity
/// chart, headline counts, and the most recent records. No mocked metrics.
struct ActivityView: View {
    @EnvironmentObject private var glasses: GlassesService
    @Query(sort: \VisionRecord.createdAt, order: .reverse) private var records: [VisionRecord]
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Activity")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.Palette.textPrimary)

                    HStack(spacing: Theme.Spacing.md) {
                        StatCard(value: "\(records.count)", label: "Total", systemImage: "square.stack.3d.up")
                        StatCard(value: "\(weekCount)", label: "This week", systemImage: "calendar")
                        StatCard(
                            value: connectionValue,
                            label: "Glasses",
                            tint: glasses.hasActiveDevice ? Theme.Palette.positive : Theme.Palette.textSecondary,
                            systemImage: "eyeglasses"
                        )
                    }

                    AreaChartCard(title: "Last 14 days", points: dailyPoints)

                    if !records.isEmpty {
                        HStack {
                            Text("Recent")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            NavigationLink { RecordsView() } label: {
                                Text("See all")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(records.prefix(6)) { record in
                                NavigationLink { RecordDetailView(record: record) } label: {
                                    recordRow(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, 96)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
        .enableInjection()
    }

    // MARK: Derived data (all real)

    private var weekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return records.filter { $0.createdAt >= cutoff }.count
    }

    private var connectionValue: String {
        if glasses.hasActiveDevice { return "Live" }
        if glasses.registration == .registered { return "Linked" }
        return "Off"
    }

    /// Record counts per day for the last 14 days (oldest → newest).
    private var dailyPoints: [(date: Date, value: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var counts: [Date: Int] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.createdAt)
            if let diff = cal.dateComponents([.day], from: day, to: today).day, diff >= 0, diff < 14 {
                counts[day, default: 0] += 1
            }
        }
        return (0..<14).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return (date: day, value: counts[day] ?? 0)
        }
    }

    private func recordRow(_ record: VisionRecord) -> some View {
        GlassCard(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                if let data = record.thumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.Palette.surfaceHigh))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.kind.title)
                        .font(Theme.Font.readout(11))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(record.result)
                        .lineLimit(2)
                        .font(Theme.Font.body(14))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }
}

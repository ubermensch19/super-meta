import SwiftUI
import Charts

// MARK: - Glass card

/// The go-to light-mode card: white surface, rounded, hairline border, soft shadow.
public struct GlassCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = Theme.Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}

// MARK: - Stat card

/// A big-number stat in a glass card — value + label, with an optional icon and caption.
public struct StatCard: View {
    private let value: String
    private let label: String
    private let caption: String?
    private let tint: Color
    private let systemImage: String?

    public init(
        value: String,
        label: String,
        caption: String? = nil,
        tint: Color = Theme.Palette.textPrimary,
        systemImage: String? = nil
    ) {
        self.value = value
        self.label = label
        self.caption = caption
        self.tint = tint
        self.systemImage = systemImage
    }

    public var body: some View {
        GlassCard(padding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: 5) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Text(label.uppercased())
                        .font(Theme.Font.readout(10))
                        .tracking(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let caption {
                    Text(caption)
                        .font(Theme.Font.body(12))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Floating tab bar

/// One entry in the floating tab bar.
public struct TabBarItem: Identifiable {
    public let id = UUID()
    public let systemImage: String
    public let title: String
    public init(systemImage: String, title: String) {
        self.systemImage = systemImage
        self.title = title
    }
}

/// A floating pill nav — the selected item expands into a dark "ink" pill with a
/// label; the rest are white glass circles. Meant to be overlaid at the bottom.
public struct FloatingTabBar: View {
    private let items: [TabBarItem]
    @Binding private var selection: Int

    public init(items: [TabBarItem], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isSelected = index == selection
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                        if isSelected {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white : Theme.Palette.textSecondary)
                    .padding(.horizontal, isSelected ? Theme.Spacing.lg : 0)
                    .frame(height: 54)
                    .frame(minWidth: isSelected ? nil : 54)
                    .background(pillBackground(isSelected: isSelected))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Theme.Palette.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func pillBackground(isSelected: Bool) -> some View {
        if isSelected {
            Capsule(style: .continuous).fill(Theme.Palette.ink)
        } else {
            Circle().fill(Color.clear)
        }
    }
}

// MARK: - Area chart card

/// A soft-gradient area chart in a glass card — for daily activity counts.
public struct AreaChartCard: View {
    private let title: String
    private let points: [(date: Date, value: Int)]

    public init(title: String, points: [(date: Date, value: Int)]) {
        self.title = title
        self.points = points
    }

    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if points.allSatisfy({ $0.value == 0 }) {
                    Text("No activity yet")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    Chart {
                        ForEach(points, id: \.date) { point in
                            AreaMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Count", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.Palette.ink.opacity(0.22), Theme.Palette.ink.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Count", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.Palette.ink)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Theme.Palette.border)
                            AxisValueLabel().foregroundStyle(Theme.Palette.textMuted)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                .foregroundStyle(Theme.Palette.textMuted)
                        }
                    }
                    .frame(height: 140)
                }
            }
        }
    }
}

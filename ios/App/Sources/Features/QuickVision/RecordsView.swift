import SwiftUI
import SwiftData
import DesignSystem

struct RecordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VisionRecord.createdAt, order: .reverse) private var records: [VisionRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No records yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Vision results you generate will appear here.")
                }
                .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            recordRow(record)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(records[index]) }
                    }
                    .listRowBackground(Theme.Palette.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }

    private func recordRow(_ record: VisionRecord) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            if let data = record.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(record.kind.title).font(Theme.Font.readout(11)).foregroundStyle(Theme.Palette.accent)
                Text(record.result).lineLimit(2).font(Theme.Font.body(14)).foregroundStyle(Theme.Palette.textPrimary)
                Text(record.createdAt, style: .date).font(Theme.Font.readout(10)).foregroundStyle(Theme.Palette.textMuted)
            }
        }
    }
}

struct RecordDetailView: View {
    let record: VisionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let data = record.thumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                Text(record.prompt).font(Theme.Font.readout(12)).foregroundStyle(Theme.Palette.textSecondary)
                Divider().overlay(Theme.Palette.border)
                Text(record.result).font(Theme.Font.body(15)).foregroundStyle(Theme.Palette.textPrimary)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .navigationTitle(record.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }
}

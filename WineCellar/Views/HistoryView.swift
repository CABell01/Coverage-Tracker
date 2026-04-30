import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DrinkingLog.dateConsumed, order: .reverse) private var logs: [DrinkingLog]

    var body: some View {
        Group {
            if logs.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Wines you drink will appear here with your ratings and notes.")
                }
            } else {
                List(logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(log.wineName)
                                .font(.headline)
                            Spacer()
                            Text(log.dateConsumed.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("\(log.producer) \(String(log.vintage))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= log.rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(star <= log.rating ? .yellow : .gray)
                                }
                            }
                        }

                        Text(log.variety)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())

                        if !log.tastingNotes.isEmpty {
                            Text(log.tastingNotes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Drinking History")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: DrinkingLog.self, inMemory: true)
}

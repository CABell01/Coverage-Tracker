import SwiftUI
import SwiftData

struct DrinkWineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let wine: Wine

    @State private var rating: Int = 3
    @State private var tastingNotes: String = ""
    @State private var bottlesToDrink: Int = 1

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.name.isEmpty ? wine.variety : wine.name)
                        .font(.headline)
                    Text("\(wine.producer) \(String(wine.vintage))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("How was it?") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(star <= rating ? .yellow : .gray)
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                }

                TextField("Tasting notes...", text: $tastingNotes, axis: .vertical)
                    .lineLimit(3...8)
            }

            if wine.quantity > 1 {
                Section {
                    Stepper("Bottles: \(bottlesToDrink)", value: $bottlesToDrink, in: 1...wine.quantity)
                }
            }

            Section {
                Button("Log & Remove from Cellar") {
                    logAndRemove()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.orange)
            }
        }
        .navigationTitle("Drink Wine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func logAndRemove() {
        let log = DrinkingLog(
            wineName: wine.name.isEmpty ? wine.variety : wine.name,
            producer: wine.producer,
            variety: wine.variety,
            vintage: wine.vintage,
            dateConsumed: .now,
            rating: rating,
            tastingNotes: tastingNotes
        )
        modelContext.insert(log)

        wine.quantity -= bottlesToDrink
        if wine.quantity <= 0 {
            modelContext.delete(wine)
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        DrinkWineView(wine: Wine(
            name: "Reserve Pinot Noir",
            producer: "Domaine Drouhin",
            variety: "Pinot Noir",
            vintage: 2019,
            quantity: 3
        ))
    }
    .modelContainer(for: [Wine.self, DrinkingLog.self], inMemory: true)
}

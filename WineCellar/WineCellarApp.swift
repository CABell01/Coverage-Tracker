import SwiftUI
import SwiftData

@main
struct WineCellarApp: App {
    let container: ModelContainer
    @State private var cellarSelection = CellarSelection()

    init() {
        do {
            container = try ModelContainer(for: Wine.self, DrinkingLog.self, Cellar.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(cellarSelection)
                .onAppear { migrateIfNeeded() }
                .onOpenURL { url in
                    importSharedCellar(from: url)
                }
        }
        .modelContainer(container)
    }

    private func migrateIfNeeded() {
        let context = container.mainContext

        // Check if an owned cellar already exists
        let ownedDescriptor = FetchDescriptor<Cellar>(
            predicate: #Predicate { $0.isOwned == true }
        )
        let ownedCellars = (try? context.fetch(ownedDescriptor)) ?? []

        let myCellar: Cellar
        if let existing = ownedCellars.first {
            myCellar = existing
        } else {
            myCellar = Cellar(name: "My Cellar", ownerName: "Me", isOwned: true)
            context.insert(myCellar)
        }

        // Assign any orphaned wines to the owned cellar
        let orphanDescriptor = FetchDescriptor<Wine>(
            predicate: #Predicate { $0.cellar == nil }
        )
        if let orphans = try? context.fetch(orphanDescriptor) {
            for wine in orphans {
                wine.cellar = myCellar
            }
        }

        try? context.save()

        // Set the default selection
        if cellarSelection.selectedCellar == nil {
            cellarSelection.selectedCellar = myCellar
        }
    }

    private func importSharedCellar(from url: URL) {
        let context = container.mainContext

        if let cellar = try? CellarShareService.importCellar(from: url, into: context) {
            try? context.save()
            cellarSelection.selectedCellar = cellar
        }
    }
}

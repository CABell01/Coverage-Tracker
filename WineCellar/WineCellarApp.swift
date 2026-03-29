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

        // Fetch all cellars and find owned one
        let allDescriptor = FetchDescriptor<Cellar>()
        let allCellars = (try? context.fetch(allDescriptor)) ?? []
        let ownedCellar = allCellars.first(where: { $0.isOwned })

        let myCellar: Cellar
        if let existing = ownedCellar {
            myCellar = existing
        } else {
            myCellar = Cellar(name: "My Cellar", ownerName: "Me", isOwned: true)
            context.insert(myCellar)
        }

        // Assign any orphaned wines to the owned cellar
        let wineDescriptor = FetchDescriptor<Wine>()
        if let allWines = try? context.fetch(wineDescriptor) {
            for wine in allWines where wine.cellar == nil {
                wine.cellar = myCellar
            }
        }

        try? context.save()

        // Set the default selection
        if cellarSelection.selectedCellarID == nil {
            cellarSelection.selectedCellarID = myCellar.id
            cellarSelection.selectedCellarIsOwned = myCellar.isOwned
        }
    }

    private func importSharedCellar(from url: URL) {
        let context = container.mainContext

        if let cellar = try? CellarShareService.importCellar(from: url, into: context) {
            try? context.save()
            cellarSelection.selectedCellarID = cellar.id
            cellarSelection.selectedCellarIsOwned = cellar.isOwned
        }
    }
}

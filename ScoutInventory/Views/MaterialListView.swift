import SwiftUI

struct MaterialListView: View {
    @EnvironmentObject var appState: AppState
    @State private var items: [InventoryItem] = []
    @State private var search = ""

    private var filtered: [InventoryItem] {
        guard !search.isEmpty else { return items }
        let q = search.lowercased()
        return items.filter {
            $0.name.lowercased().contains(q) || $0.inventoryCode.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.inventoryCode)
                            .font(.headline)
                        Text(item.name)
                        Text(item.status.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: InventoryItem.self) { ItemDetailView(item: $0) }
            .searchable(text: $search)
            .navigationTitle("Matériel")
            .task { items = await appState.loadItems() }
        }
    }
}

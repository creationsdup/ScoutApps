import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var item: InventoryItem
    @State private var message: String?
    @State private var error: String?
    @State private var isWorking = false

    init(item: InventoryItem) {
        _item = State(initialValue: item)
    }

    private let actions: [MovementAction] = [.checkout, .return, .cleaning, .repair]

    var body: some View {
        Form {
            Section {
                Text(item.name).font(.title3).bold()
                LabeledContent("Code", value: item.inventoryCode)
                LabeledContent("Statut", value: item.status.label)
                LabeledContent("Quantité", value: "\(item.quantity)")
                if let description = item.description, !description.isEmpty {
                    Text(description).foregroundStyle(.secondary)
                }
            }

            Section("Actions terrain") {
                ForEach(actions, id: \.self) { action in
                    Button(action.label) { run(action) }
                        .disabled(!appState.canWrite || isWorking)
                }
                if !appState.canWrite {
                    Text("Lecture seule — ton rôle ne permet pas d'agir.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let message {
                Section { Text(message).foregroundStyle(.green) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle(item.inventoryCode)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run(_ action: MovementAction) {
        Task {
            isWorking = true
            error = nil
            message = nil
            let result = await appState.runMovement(on: item, action: action)
            switch result {
            case .success(let nextStatus):
                item = makeItem(with: nextStatus)
                message = "Action enregistrée."
            case .failure(let reason):
                error = reason.message
            }
            isWorking = false
        }
    }

    /// Reflète localement le nouveau statut (le serveur reste l'autorité).
    private func makeItem(with status: ItemStatus) -> InventoryItem {
        InventoryItem(
            id: item.id,
            inventoryCode: item.inventoryCode,
            name: item.name,
            description: item.description,
            condition: item.condition,
            status: status,
            quantity: item.quantity,
            photoUrl: item.photoUrl,
            notes: item.notes
        )
    }
}

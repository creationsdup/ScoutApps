import SwiftUI

struct EventsListView: View {
    @EnvironmentObject var appState: AppState

    @State private var newName = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCreating = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Évènements") {
                    if appState.events.isEmpty {
                        Text("Aucun évènement.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.events) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name).font(.headline)
                                Text("\(event.startDate) → \(event.endDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Créer un évènement") {
                    TextField("Nom", text: $newName)
                    DatePicker("Début", selection: $startDate, displayedComponents: .date)
                    DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    Button("Créer") {
                        createEvent()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)

                    if !appState.canWrite {
                        Text("Lecture seule — ton rôle ne permet pas de créer un évènement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!appState.canWrite)

                if let error = appState.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Évènements")
            .task { await appState.loadEvents() }
        }
    }

    private func createEvent() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isCreating = true
        Task {
            let ok = await appState.createEvent(
                name: name,
                startDate: Self.dateFormatter.string(from: startDate),
                endDate: Self.dateFormatter.string(from: endDate)
            )
            if ok { newName = "" }
            isCreating = false
        }
    }
}

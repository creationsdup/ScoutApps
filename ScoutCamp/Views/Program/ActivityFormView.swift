import SwiftUI
import ScoutKit

/// Formulaire de création / modification d'une activité.
struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity?
    /// Callback appelé après sauvegarde réussie. `isNew` indique création vs. mise à jour.
    let onSaved: (Activity, Bool) -> Void

    @State private var name: String = ""
    @State private var type: ActivityType? = nil
    @State private var branch: Branch? = nil
    @State private var durationMin: Int = 30
    @State private var hasDuration: Bool = false
    @State private var description: String = ""
    @State private var materialNotes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = ActivityService()
    private var isEditing: Bool { activity != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Aucun").tag(ActivityType?.none)
                        ForEach(ActivityType.allCases, id: \.self) { t in
                            Text(t.label).tag(ActivityType?.some(t))
                        }
                    }
                    Picker("Branche", selection: $branch) {
                        Text("Aucune").tag(Branch?.none)
                        ForEach(Branch.allCases, id: \.self) { b in
                            Text(b.label).tag(Branch?.some(b))
                        }
                    }
                }

                Section("Durée") {
                    Toggle("Durée connue", isOn: $hasDuration)
                    if hasDuration {
                        Stepper("\(durationMin) min", value: $durationMin, in: 5...480, step: 5)
                    }
                }

                Section("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Notes matériel") {
                    TextField("Matériel nécessaire", text: $materialNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier l'activité" : "Nouvelle activité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .foregroundStyle(SGDFColors.primaryBlue)
                        .disabled(!canSave || isSaving)
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    // MARK: - Helpers

    private func populateFromExisting() {
        guard let a = activity else { return }
        name = a.name
        type = a.type
        branch = a.branch
        description = a.description ?? ""
        materialNotes = a.materialNotes ?? ""
        if let d = a.durationMin {
            durationMin = d; hasDuration = true
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let a = Activity(
            id: activity?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            durationMin: hasDuration ? durationMin : nil,
            description: description.isEmpty ? nil : description,
            branch: branch,
            materialNotes: materialNotes.isEmpty ? nil : materialNotes
        )
        do {
            if isEditing {
                try await service.update(a)
                onSaved(a, false)
            } else {
                let created = try await service.create(a)
                onSaved(created, true)
            }
            dismiss()
        } catch {
            errorMessage = "Impossible d'enregistrer : \(error.localizedDescription)"
        }
    }
}

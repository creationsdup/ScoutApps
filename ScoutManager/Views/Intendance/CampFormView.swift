import SwiftUI

struct CampFormView: View {
    @EnvironmentObject private var campStore: CampStore
    @Environment(\.dismiss) private var dismiss

    let existingCamp: Camp?

    @State private var name: String = ""
    @State private var location: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var branch: Branch? = nil
    @State private var participantsCount: Int = 0
    @State private var encadrantsCount: Int = 0
    @State private var errorMessage: String? = nil
    @State private var isSaving = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var isEditing: Bool { existingCamp != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom du camp", text: $name)
                    TextField("Lieu", text: $location)
                }

                Section("Dates") {
                    Toggle("Date de début", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("Début", selection: $startDate, displayedComponents: .date)
                            .onChange(of: startDate) { _, newVal in
                                if hasEndDate && endDate < newVal { endDate = newVal }
                            }
                    }
                    Toggle("Date de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate,
                                   in: hasStartDate ? startDate... : Date.distantPast...,
                                   displayedComponents: .date)
                    }
                }

                Section("Branche & Effectifs") {
                    Picker("Branche", selection: $branch) {
                        Text("Aucune").tag(Branch?.none)
                        ForEach(Branch.allCases, id: \.self) { Text($0.label).tag(Branch?.some($0)) }
                    }
                    Stepper("Participants : \(participantsCount)", value: $participantsCount, in: 0...999)
                    Stepper("Encadrants : \(encadrantsCount)", value: $encadrantsCount, in: 0...999)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier le camp" : "Nouveau camp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    private func populateFromExisting() {
        guard let camp = existingCamp else { return }
        name = camp.name
        location = camp.location ?? ""
        branch = camp.branch
        participantsCount = camp.participantsCount ?? 0
        encadrantsCount = camp.encadrantsCount ?? 0
        if let s = camp.startDate, let d = Self.dateFormatter.date(from: s) {
            startDate = d; hasStartDate = true
        }
        if let e = camp.endDate, let d = Self.dateFormatter.date(from: e) {
            endDate = d; hasEndDate = true
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let camp = Camp(
            id: existingCamp?.id ?? UUID().uuidString,
            eventId: existingCamp?.eventId,
            name: name.trimmingCharacters(in: .whitespaces),
            location: location.isEmpty ? nil : location,
            startDate: hasStartDate ? Self.dateFormatter.string(from: startDate) : nil,
            endDate: hasEndDate ? Self.dateFormatter.string(from: endDate) : nil,
            branch: branch,
            participantsCount: participantsCount > 0 ? participantsCount : nil,
            encadrantsCount: encadrantsCount > 0 ? encadrantsCount : nil,
            createdBy: existingCamp?.createdBy ?? SupabaseService.shared.currentUserID?.uuidString
        )
        Task {
            do {
                if isEditing {
                    try await campStore.update(camp)
                } else {
                    try await campStore.create(camp)
                }
                dismiss()
            } catch {
                errorMessage = "Erreur : \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}

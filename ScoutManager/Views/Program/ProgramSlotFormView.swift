import SwiftUI

/// Formulaire de création / modification d'un créneau de planning.
struct ProgramSlotFormView: View {
    @ObservedObject var viewModel: ProgramPlanViewModel
    @Environment(\.dismiss) private var dismiss

    let campId: String
    let campStartDate: String?
    let campEndDate: String?
    let initialDate: String
    let existingSlot: ProgramSlot?

    @State private var title: String = ""
    @State private var slotDate: Date = Date()
    @State private var hasStartTime: Bool = false
    @State private var startTime: Date = Self.defaultTime(hour: 9)
    @State private var hasEndTime: Bool = false
    @State private var endTime: Date = Self.defaultTime(hour: 10)
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var selectedActivityId: String? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Task X — lien matériel
    @State private var selectedItemIds: Set<String> = []
    @State private var allItems: [Item] = []
    /// Fix 1 — true only after itemIds(slotId:) succeeds (or for a new slot).
    /// Prevents save() from calling setItems when links were never loaded (would wipe all existing links).
    @State private var linksLoaded = false

    private let programService = ProgramService()
    private let itemService = ItemService()

    private static let timeDF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func defaultTime(hour: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private var isEditing: Bool { existingSlot != nil }

    /// Fix 4 — guard end ≥ start when both are set (lexicographic compare on "HH:mm" is safe for 24h zero-padded).
    private var isTimeValid: Bool {
        guard hasStartTime && hasEndTime else { return true }
        return Self.timeDF.string(from: endTime) >= Self.timeDF.string(from: startTime)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && isTimeValid
    }

    private var campDateRange: ClosedRange<Date> {
        let start = campStartDate.flatMap { SGDFDate.day(from: $0) } ?? Date.distantPast
        let end   = campEndDate.flatMap   { SGDFDate.day(from: $0) } ?? Date.distantFuture
        return start...end
    }

    var body: some View {
        NavigationStack {
            Form {
                coreSection
                timeSection
                activitySection
                detailsSection
                materialSection
                errorSection
            }
            .navigationTitle(isEditing ? "Modifier le créneau" : "Nouveau créneau")
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
            .task { await loadItems() }
        }
    }

    // MARK: - Form sections

    private var coreSection: some View {
        Section("Créneau") {
            TextField("Titre", text: $title)
            DatePicker("Date", selection: $slotDate,
                       in: campDateRange,
                       displayedComponents: .date)
        }
    }

    private var timeSection: some View {
        Section("Horaires") {
            Toggle("Heure de début", isOn: $hasStartTime)
            if hasStartTime {
                DatePicker("Début", selection: $startTime, displayedComponents: .hourAndMinute)
            }
            Toggle("Heure de fin", isOn: $hasEndTime)
            if hasEndTime {
                DatePicker("Fin", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            // Fix 4 — inline validation message when end < start
            if hasStartTime && hasEndTime && !isTimeValid {
                Text("L'heure de fin doit être après l'heure de début.")
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.red)
            }
        }
    }

    private var activitySection: some View {
        Section("Activité") {
            Picker("Activité", selection: $selectedActivityId) {
                Text("Aucune").tag(String?.none)
                ForEach(viewModel.activities) { activity in
                    Text(activity.name).tag(String?.some(activity.id))
                }
            }
            .onChange(of: selectedActivityId) { _, newId in
                guard let id = newId,
                      let activity = viewModel.activities.first(where: { $0.id == id }),
                      title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                title = activity.name
            }
        }
    }

    private var detailsSection: some View {
        Section("Détails") {
            TextField("Lieu", text: $location)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var materialSection: some View {
        Section("Matériel") {
            NavigationLink(destination: SlotMaterialPickerView(
                allItems: allItems,
                selectedIds: $selectedItemIds
            )) {
                HStack {
                    Text("Matériel (\(selectedItemIds.count))")
                        .foregroundStyle(SGDFColors.textPrimary)
                    Spacer()
                    if !selectedItemIds.isEmpty {
                        Text("\(selectedItemIds.count) sélectionné\(selectedItemIds.count > 1 ? "s" : "")")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                }
            }
            // Fix 2 — liste en lecture seule des items sélectionnés avec couleur de statut
            ForEach(allItems.filter { selectedItemIds.contains($0.id) }) { item in
                SlotSelectedItemRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Section {
                Text(error)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.red)
            }
        }
    }

    // MARK: - Data

    private func loadItems() async {
        if let slotId = existingSlot?.id {
            // Existing slot: fetch items list AND linked ids together.
            // linksLoaded stays false until BOTH succeed to prevent save() wiping existing links.
            do {
                async let itemsTask = itemService.list()
                async let idsTask   = programService.itemIds(slotId: slotId)
                let (items, ids) = try await (itemsTask, idsTask)
                allItems = items
                selectedItemIds = Set(ids)
                linksLoaded = true
            } catch {
                // Surface to user so they know links are in an uncertain state.
                errorMessage = "Impossible de charger les liens matériel — les liens existants seront préservés à l'enregistrement."
                // Attempt to at least populate the items list for display (best-effort).
                if let items = try? await itemService.list() {
                    allItems = items
                }
                // linksLoaded remains false → save() will skip setItems
            }
        } else {
            // New slot: no existing links to lose.
            if let items = try? await itemService.list() {
                allItems = items
            }
            linksLoaded = true
        }
    }

    private func populateFromExisting() {
        guard let slot = existingSlot else {
            if let d = SGDFDate.day(from: initialDate) {
                slotDate = d
            } else if let d = SGDFDate.day(from: campStartDate ?? "") {
                slotDate = d
            }
            return
        }
        title = slot.title
        if let d = SGDFDate.day(from: slot.date) { slotDate = d }
        location = slot.location ?? ""
        notes = slot.notes ?? ""
        selectedActivityId = slot.activityId
        if let st = slot.startTime, let d = Self.timeDF.date(from: String(st.prefix(5))) {
            startTime = d; hasStartTime = true
        }
        if let et = slot.endTime, let d = Self.timeDF.date(from: String(et.prefix(5))) {
            endTime = d; hasEndTime = true
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let dateStr  = SGDFDate.string(from: slotDate)
        let startStr = hasStartTime ? Self.timeDF.string(from: startTime) : nil
        let endStr   = hasEndTime   ? Self.timeDF.string(from: endTime)   : nil
        do {
            let saved = try await viewModel.save(
                campId: campId,
                date: dateStr,
                existingId: existingSlot?.id,
                title: title.trimmingCharacters(in: .whitespaces),
                startTime: startStr,
                endTime: endStr,
                location: location.isEmpty ? nil : location,
                notes: notes.isEmpty ? nil : notes,
                activityId: selectedActivityId
            )
            // Fix 1 — only call setItems when links were successfully loaded to avoid wiping existing links.
            if linksLoaded {
                do {
                    try await programService.setItems(slotId: saved.id,
                                                      itemIds: Array(selectedItemIds))
                } catch {
                    errorMessage = "Créneau enregistré. Lien matériel non sauvegardé : \(error.localizedDescription)"
                    return
                }
            }
            dismiss()
        } catch {
            errorMessage = "Impossible d'enregistrer : \(error.localizedDescription)"
        }
    }
}

// MARK: - Fix 2 private subview — évite les expressions géantes dans materialSection

private struct SlotSelectedItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: SGDFTheme.Spacing.sm) {
            Circle()
                .fill(StatusColorMapper.color(for: item.status))
                .frame(width: 8, height: 8)
            Text(item.name)
                .font(SGDFTheme.FontStyle.body())
                .foregroundStyle(SGDFColors.textPrimary)
            Spacer()
            Text(item.status.label)
                .font(SGDFTheme.FontStyle.caption())
                .foregroundStyle(StatusColorMapper.color(for: item.status))
        }
    }
}

import SwiftUI
import ScoutKit

struct FoodStockFormView: View {
    @ObservedObject var viewModel: FoodStockViewModel
    let campId: String
    let item: FoodStockItem?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var quantityStr: String = ""
    @State private var unit: String = ""
    @State private var hasExpiry: Bool = false
    @State private var expiryDate: Date = Date()
    @State private var location: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isEditing: Bool { item != nil }
    private var parsedQuantity: Double? {
        Double(quantityStr.replacingOccurrences(of: ",", with: "."))
    }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Denrée") {
                    SGDFTextField("Nom de la denrée", text: $name)

                    HStack {
                        SGDFTextField("Quantité (ex : 2,5)", text: $quantityStr)
                            .keyboardType(.decimalPad)
                        SGDFTextField("Unité (ex : kg)", text: $unit)
                    }
                }

                Section("Péremption") {
                    Toggle("Date de péremption", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Date", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Emplacement") {
                    SGDFTextField("Emplacement (optionnel)", text: $location)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier la denrée" : "Nouvelle denrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave || isSaving)
                        .foregroundStyle(canSave && !isSaving ? SGDFColors.primaryBlue : SGDFColors.textSecondary)
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    private func populateFromExisting() {
        guard let existing = item else { return }
        name = existing.name
        if let qty = existing.quantity {
            quantityStr = qty.qtyDisplay
        }
        unit = existing.unit ?? ""
        location = existing.location ?? ""
        if let dateStr = existing.expiryDate,
           let date = SGDFDate.day(from: dateStr) {
            expiryDate = date
            hasExpiry = true
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let stockItem = FoodStockItem(
            id: item?.id ?? UUID().uuidString,
            campId: campId,
            name: trimmedName,
            quantity: parsedQuantity,
            unit: trimmedUnit.isEmpty ? nil : trimmedUnit,
            expiryDate: hasExpiry ? SGDFDate.string(from: expiryDate) : nil,
            location: trimmedLocation.isEmpty ? nil : trimmedLocation
        )
        Task {
            do {
                try await viewModel.save(stockItem, isNew: !isEditing)
                dismiss()
            } catch {
                errorMessage = "Erreur : \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}

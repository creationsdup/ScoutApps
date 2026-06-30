import SwiftUI
import PhotosUI

struct FoodTraceFormView: View {
    @ObservedObject var viewModel: FoodTraceViewModel
    let campId: String
    let entry: FoodTraceEntry?

    @Environment(\.dismiss) private var dismiss

    @State private var productName: String = ""
    @State private var brand: String = ""
    @State private var supplier: String = ""
    @State private var lotNumber: String = ""
    @State private var barcode: String = ""
    @State private var quantityStr: String = ""
    @State private var hasReceivedDate: Bool = false
    @State private var receivedDate: Date = Date()
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = Date()
    @State private var mealId: String? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var pickedImageData: Data? = nil
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showScanner = false

    private var isEditing: Bool { entry != nil }
    private var parsedQuantity: Double? {
        let s = quantityStr.replacingOccurrences(of: ",", with: ".")
        return Double(s)
    }
    private var canSave: Bool { !productName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Section Produit
                Section("Produit") {
                    SGDFTextField("Produit", text: $productName)
                    SGDFTextField("Marque", text: $brand)
                    SGDFTextField("Fournisseur / provenance", text: $supplier)
                }

                // MARK: Section Traçabilité
                Section("Traçabilité") {
                    SGDFTextField("N° de lot", text: $lotNumber)
                    HStack {
                        SGDFTextField("Code-barres", text: $barcode, systemImage: "barcode")
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                        Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
                            .foregroundStyle(SGDFColors.primaryBlue)
                    }
                    .sheet(isPresented: $showScanner) { BarcodeScannerView { code in barcode = code } }
                }

                // MARK: Section Quantité & Dates
                Section("Quantité & dates") {
                    SGDFTextField("Quantité (ex : 2,5)", text: $quantityStr)
                        .keyboardType(.decimalPad)

                    Toggle("Date de réception", isOn: $hasReceivedDate)
                    if hasReceivedDate {
                        DatePicker("Date", selection: $receivedDate, displayedComponents: .date)
                    }

                    Toggle("Date de péremption", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("Date", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                // MARK: Section Repas lié
                Section("Repas lié (optionnel)") {
                    Picker("Repas", selection: $mealId) {
                        Text("Aucun").tag(String?.none)
                        ForEach(viewModel.meals) { meal in
                            let label = "\(meal.date) · \(meal.slot.label)" + (meal.title.map { " · \($0)" } ?? "")
                            Text(label).tag(String?.some(meal.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Section Photo
                Section("Photo") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(
                            pickedImageData == nil ? "Choisir une photo" : "Photo sélectionnée",
                            systemImage: "photo"
                        )
                        .foregroundStyle(SGDFColors.primaryBlue)
                    }
                    .onChange(of: photoItem) { _, newItem in
                        Task {
                            if let newItem {
                                pickedImageData = try? await newItem.loadTransferable(type: Data.self)
                            } else {
                                pickedImageData = nil
                            }
                        }
                    }
                }

                // MARK: Erreur
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier l'entrée" : "Nouvelle entrée")
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

    // MARK: - Populate

    private func populateFromExisting() {
        guard let existing = entry else { return }
        productName = existing.productName
        brand = existing.brand ?? ""
        supplier = existing.supplier ?? ""
        lotNumber = existing.lotNumber ?? ""
        barcode = existing.barcode ?? ""
        if let qty = existing.quantity {
            quantityStr = qty.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(qty))
                : String(qty)
        }
        mealId = existing.mealId
        if let s = existing.receivedDate, let d = SGDFDate.day(from: s) {
            receivedDate = d; hasReceivedDate = true
        }
        if let s = existing.expiryDate, let d = SGDFDate.day(from: s) {
            expiryDate = d; hasExpiryDate = true
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        errorMessage = nil
        let entryId = entry?.id ?? UUID().uuidString
        let trimName = productName.trimmingCharacters(in: .whitespaces)
        let trimBrand = brand.trimmingCharacters(in: .whitespaces)
        let trimSupplier = supplier.trimmingCharacters(in: .whitespaces)
        let trimLot = lotNumber.trimmingCharacters(in: .whitespaces)
        let trimBarcode = barcode.trimmingCharacters(in: .whitespaces)

        let toSave = FoodTraceEntry(
            id: entryId,
            campId: campId,
            productName: trimName,
            brand: trimBrand.isEmpty ? nil : trimBrand,
            supplier: trimSupplier.isEmpty ? nil : trimSupplier,
            lotNumber: trimLot.isEmpty ? nil : trimLot,
            barcode: trimBarcode.isEmpty ? nil : trimBarcode,
            quantity: parsedQuantity,
            receivedDate: hasReceivedDate ? SGDFDate.string(from: receivedDate) : nil,
            expiryDate: hasExpiryDate ? SGDFDate.string(from: expiryDate) : nil,
            mealId: mealId,
            photoPath: entry?.photoPath  // conservé si pas de nouvelle photo
        )
        Task {
            do {
                try await viewModel.save(toSave, isNew: !isEditing, photoData: pickedImageData)
                dismiss()
            } catch {
                errorMessage = "Erreur : \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}

import SwiftUI
import ScoutKit

/// Sheet d'ajout manuel d'un article dans la liste de courses.
struct ShoppingAddView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    let campId: String
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var quantityStr: String = ""
    @State private var unit: String = ""

    private var parsedQuantity: Double? {
        Double(quantityStr.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SGDFTextField("Article", text: $name)
                    SGDFTextField("Qté (ex : 2,5)", text: $quantityStr)
                        .keyboardType(.decimalPad)
                    SGDFTextField("Unité (ex : kg)", text: $unit)
                }

                if let err = viewModel.errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle("Ajouter un article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isPresented = false }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        Task {
                            await viewModel.addManual(
                                campId: campId,
                                name: name.trimmingCharacters(in: .whitespaces),
                                quantity: parsedQuantity,
                                unit: unit.trimmingCharacters(in: .whitespaces).isEmpty ? nil : unit.trimmingCharacters(in: .whitespaces)
                            )
                            if viewModel.errorMessage == nil {
                                isPresented = false
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? SGDFColors.textSecondary : SGDFColors.primaryBlue)
                }
            }
        }
    }
}

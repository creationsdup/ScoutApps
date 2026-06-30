import SwiftUI
import ScoutKit

struct CheckoutCartView: View {
    let onCreated: () -> Void

    @StateObject private var vm = CheckoutCartViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Destination
                Section("Destination") {
                    TextField("Destination / libellé", text: $vm.label)
                    TextField("Notes", text: $vm.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                // MARK: Panier
                Section("Panier") {
                    if vm.cart.isEmpty {
                        Text("Panier vide")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                    } else {
                        ForEach($vm.cart) { $line in
                            CartLineRow(line: $line, maxQty: vm.maxQty(line.item))
                        }
                        .onDelete(perform: vm.removeLine)
                        .deleteDisabled(false)
                    }
                    Button {
                        showPicker = true
                    } label: {
                        Label("Ajouter du matériel", systemImage: "plus.circle")
                            .foregroundStyle(SGDFColors.orange)
                    }
                }

                // MARK: Erreur
                if let err = vm.errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }
            }
            .navigationTitle("Nouveau bon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        Task {
                            vm.isSaving = true
                            defer { vm.isSaving = false }
                            do {
                                try await vm.validate()
                                onCreated()
                                dismiss()
                            } catch {
                                vm.errorMessage = "Création impossible : \(error.localizedDescription)"
                            }
                        }
                    }
                    .disabled(!vm.canValidate || vm.isSaving)
                    .foregroundStyle(
                        (!vm.canValidate || vm.isSaving) ? SGDFColors.textSecondary : SGDFColors.primaryBlue
                    )
                }
            }
            .sheet(isPresented: $showPicker) {
                CartItemPickerView(vm: vm)
            }
        }
    }
}

// MARK: - Cart line row

private struct CartLineRow: View {
    @Binding var line: CheckoutCartViewModel.CartLine
    let maxQty: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
            Text(line.item.name)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
            Stepper(
                "Qté : \(line.qty)",
                value: $line.qty,
                in: 1...max(1, maxQty)
            )
            .font(SGDFTheme.FontStyle.body())
            .foregroundStyle(SGDFColors.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Item picker

private struct CartItemPickerView: View {
    @ObservedObject var vm: CheckoutCartViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [Item] {
        if search.trimmingCharacters(in: .whitespaces).isEmpty {
            return vm.available
        }
        return vm.available.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.available.isEmpty {
                    EmptyStateView(
                        systemImage: "shippingbox",
                        title: "Aucun article disponible",
                        message: "Il n'y a aucun matériel disponible à ajouter."
                    )
                } else {
                    List(filtered) { item in
                        let alreadyInCart = vm.cart.contains { $0.item.id == item.id }
                        Button {
                            vm.add(item)
                            dismiss()
                        } label: {
                            PickerItemRow(item: item, maxQty: vm.maxQty(item), isInCart: alreadyInCart)
                        }
                        .disabled(alreadyInCart)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $search, prompt: "Rechercher un article")
                }
            }
            .navigationTitle("Choisir un article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
            }
            .task { await vm.loadAvailable() }
        }
    }
}

// MARK: - Picker item row

private struct PickerItemRow: View {
    let item: Item
    let maxQty: Int
    let isInCart: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(isInCart ? SGDFColors.textSecondary : SGDFColors.textPrimary)
                if isInCart {
                    Text("Déjà ajouté")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                } else {
                    Text("Dispo : \(maxQty)")
                        .font(SGDFTheme.FontStyle.caption())
                        .foregroundStyle(SGDFColors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: isInCart ? "checkmark.circle.fill" : "plus.circle.fill")
                .foregroundStyle(isInCart ? SGDFColors.textSecondary : SGDFColors.orange)
        }
    }
}

import SwiftUI
import ScoutKit

struct CategoryManagerView: View {
    @StateObject private var viewModel = CategoryManagerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var editingCategory: ItemCategory?      // sheet renommer/coder
    @State private var creatingCategory = false
    @State private var addingSubTo: ItemCategory?          // alerte nouvelle sous-cat
    @State private var renamingSub: Subcategory?           // alerte renommer sous-cat
    @State private var subNameField = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Organisation")
                .navigationBarTitleDisplayMode(.inline)
                .background(SGDFColors.background)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { creatingCategory = true } label: { Image(systemName: "plus") }
                    }
                }
                .task { await viewModel.load() }
                .sheet(isPresented: $creatingCategory) {
                    CategoryEditView(viewModel: viewModel, category: nil)
                }
                .sheet(item: $editingCategory) { cat in
                    CategoryEditView(viewModel: viewModel, category: cat)
                }
                // Nouvelle sous-catégorie
                .alert("Nouvelle sous-catégorie",
                       isPresented: Binding(get: { addingSubTo != nil },
                                            set: { if !$0 { addingSubTo = nil } })) {
                    TextField("Nom", text: $subNameField)
                    Button("Annuler", role: .cancel) { subNameField = ""; addingSubTo = nil }
                    Button("Ajouter") {
                        if let cat = addingSubTo {
                            let name = subNameField
                            subNameField = ""; addingSubTo = nil
                            Task { _ = await viewModel.createSubcategory(categoryId: cat.id, name: name) }
                        }
                    }
                }
                // Renommer sous-catégorie
                .alert("Renommer la sous-catégorie",
                       isPresented: Binding(get: { renamingSub != nil },
                                            set: { if !$0 { renamingSub = nil } })) {
                    TextField("Nom", text: $subNameField)
                    Button("Annuler", role: .cancel) { subNameField = ""; renamingSub = nil }
                    Button("Enregistrer") {
                        if let sub = renamingSub {
                            let name = subNameField
                            subNameField = ""; renamingSub = nil
                            Task { _ = await viewModel.renameSubcategory(id: sub.id, name: name) }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.categories.isEmpty {
            LoadingView()
        } else if viewModel.categories.isEmpty {
            EmptyStateView(systemImage: "folder",
                           title: "Aucune catégorie",
                           message: "Crée ta première catégorie avec le bouton +.")
        } else {
            List {
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
                ForEach(viewModel.categories) { cat in
                    Section {
                        ForEach(viewModel.subcategories(of: cat.id)) { sub in
                            Text(sub.name)
                                .foregroundStyle(SGDFColors.textPrimary)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteSubcategory(id: sub.id) }
                                    } label: { Label("Supprimer", systemImage: "trash") }
                                    Button {
                                        subNameField = sub.name; renamingSub = sub
                                    } label: { Label("Renommer", systemImage: "pencil") }
                                }
                        }
                        Button {
                            subNameField = ""; addingSubTo = cat
                        } label: {
                            Label("Sous-catégorie", systemImage: "plus.circle")
                                .foregroundStyle(SGDFColors.primaryBlue)
                        }
                    } header: {
                        HStack {
                            Text(cat.name).foregroundStyle(SGDFColors.primaryBlue)
                            if let code = cat.code {
                                Text(code).foregroundStyle(SGDFColors.textSecondary)
                            }
                            Spacer()
                            Menu {
                                Button { editingCategory = cat } label: {
                                    Label("Renommer", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteCategory(id: cat.id) }
                                } label: { Label("Supprimer", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(SGDFColors.primaryBlue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

/// Création / renommage d'une catégorie (nom + code). Code verrouillé si la
/// catégorie a déjà des items (édition seulement).
private struct CategoryEditView: View {
    @ObservedObject var viewModel: CategoryManagerViewModel
    let category: ItemCategory?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var saving = false

    private var isEditing: Bool { category != nil }
    private var codeLocked: Bool {
        guard let category else { return false }
        return !viewModel.canEditCode(category.id)
    }
    private var codeValid: Bool {
        code.range(of: "^[A-Z]{2,4}$", options: .regularExpression) != nil
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (codeLocked || codeValid) && !saving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Catégorie") {
                    TextField("Nom", text: $name)
                    if codeLocked {
                        LabeledContent("Code", value: code)
                        Text("Code verrouillé : des objets utilisent cette catégorie.")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    } else {
                        TextField("Code (2-4 lettres, ex. TEN)", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    code = category.code ?? ""
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let ok: Bool
        if let category {
            // En édition : n'envoie le code que s'il est déverrouillé.
            ok = await viewModel.renameCategory(id: category.id, name: name,
                                                code: codeLocked ? nil : code)
        } else {
            ok = await viewModel.createCategory(name: name, code: code)
        }
        if ok { dismiss() }
    }
}

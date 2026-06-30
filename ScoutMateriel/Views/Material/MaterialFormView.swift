import SwiftUI
import ScoutKit
import PhotosUI
import UIKit

struct MaterialFormView: View {
    @StateObject private var viewModel: MaterialFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showAdvanced = false
    let onSaved: () -> Void

    init(item: Item?, onSaved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MaterialFormViewModel(item: item))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("L'essentiel") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: SGDFTheme.Spacing.md) {
                            photoThumbnail
                            Text(hasPhoto ? "Changer la photo" : "Ajouter une photo")
                        }
                    }
                    HStack {
                        TextField("Nom", text: $viewModel.name)
                        Text("Requis")
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.textSecondary)
                    }
                    Picker(selection: $viewModel.categoryId) {
                        Text("Choisir…").tag(String?.none)
                        ForEach(viewModel.categories) { Text($0.name).tag(String?.some($0.id)) }
                    } label: {
                        HStack {
                            Text("Catégorie")
                            Text("Requis")
                                .font(SGDFTheme.FontStyle.caption())
                                .foregroundStyle(SGDFColors.textSecondary)
                        }
                    }
                    if !viewModel.filteredSubcategories.isEmpty {
                        Picker("Sous-catégorie", selection: $viewModel.subcategoryId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(viewModel.filteredSubcategories) { Text($0.name).tag(String?.some($0.id)) }
                        }
                    }
                    if viewModel.isEditing {
                        LabeledContent("Code inventaire", value: viewModel.inventoryCode)
                    }
                    Picker("Type de suivi", selection: $viewModel.trackingType) {
                        ForEach(TrackingType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    if viewModel.trackingType == .global {
                        Stepper("Quantité : \(viewModel.quantity)", value: $viewModel.quantity, in: 1...9999)
                    }
                    Picker("Statut", selection: $viewModel.status) {
                        ForEach(ItemStatus.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
                Section {
                    DisclosureGroup("Plus d'options", isExpanded: $showAdvanced) {
                        TextField("Description", text: $viewModel.itemDescription, axis: .vertical)
                        Picker("Localisation", selection: $viewModel.locationId) {
                            Text("Aucune").tag(String?.none)
                            ForEach(viewModel.locations) { Text($0.name).tag(String?.some($0.id)) }
                        }
                        Picker("Branche", selection: $viewModel.branch) {
                            Text("Aucune").tag(Branch?.none)
                            ForEach(Branch.allCases, id: \.self) { Text($0.label).tag(Branch?.some($0)) }
                        }
                        Picker("État", selection: $viewModel.condition) {
                            ForEach(ItemCondition.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if viewModel.trackingType == .global {
                            Picker("Unité", selection: $viewModel.unit) {
                                ForEach(ItemUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                            Stepper(viewModel.minimumThreshold == 0
                                    ? "Seuil minimum : aucun"
                                    : "Seuil minimum : \(viewModel.minimumThreshold)",
                                    value: $viewModel.minimumThreshold, in: 0...9999)
                        }
                        TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(SGDFColors.red) }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            if await viewModel.save() { onSaved(); dismiss() }
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                showAdvanced = viewModel.shouldExpandAdvanced
                await viewModel.loadReferentials()
            }
            .onChange(of: viewModel.trackingType) { _, newValue in
                if newValue == .specifique { viewModel.quantity = 1 }
            }
            .onChange(of: viewModel.categoryId) { _, _ in
                viewModel.subcategoryId = nil
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        viewModel.pickedImageData = data
                    }
                }
            }
        }
    }

    private var hasPhoto: Bool {
        viewModel.pickedImageData != nil || viewModel.existingImageURL != nil
    }

    @ViewBuilder
    private var photoThumbnail: some View {
        Group {
            if let data = viewModel.pickedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let url = viewModel.existingImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholderPhoto
                    }
                }
            } else {
                placeholderPhoto
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
    }

    private var placeholderPhoto: some View {
        Rectangle().fill(SGDFColors.border)
            .overlay(Image(systemName: "photo").foregroundStyle(SGDFColors.textSecondary))
    }
}

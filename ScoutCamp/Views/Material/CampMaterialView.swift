import SwiftUI
import ScoutKit

// MARK: - Main View

struct CampMaterialView: View {
    @EnvironmentObject private var campStore: CampStore
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = CampMaterialViewModel()
    @State private var showAdd = false
    @State private var confirmReturnAll = false

    var body: some View {
        NavigationStack {
            Group {
                if campStore.selectedCamp == nil {
                    EmptyStateView(
                        systemImage: "shippingbox",
                        title: "Aucun camp",
                        message: "Sélectionne un camp."
                    )
                } else {
                    campContent
                }
            }
            .navigationTitle("Matériel")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if session.canWrite, campStore.selectedCamp != nil {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(SGDFColors.primaryBlue)
                        }
                        Button("Tout rendre") {
                            confirmReturnAll = true
                        }
                        .foregroundStyle(SGDFColors.red)
                        .disabled(vm.items.isEmpty)
                    }
                }
            }
            .confirmationDialog("Tout rendre ?", isPresented: $confirmReturnAll, titleVisibility: .visible) {
                Button("Tout rendre", role: .destructive) {
                    if let camp = campStore.selectedCamp {
                        Task { await vm.returnAll(campId: camp.id) }
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
            .task {
                if let camp = campStore.selectedCamp {
                    await vm.load(campId: camp.id)
                }
            }
            .onChange(of: campStore.selectedCampID) { _, _ in
                Task {
                    if let camp = campStore.selectedCamp {
                        await vm.load(campId: camp.id)
                    } else {
                        vm.items = []
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                if let camp = campStore.selectedCamp {
                    AddMaterialSheet(vm: vm, campId: camp.id)
                }
            }
        }
    }

    // MARK: - Camp content

    @ViewBuilder
    private var campContent: some View {
        if vm.isLoading {
            LoadingView()
        } else {
            List {
                if let err = vm.errorMessage {
                    Section {
                        Text(err)
                            .font(SGDFTheme.FontStyle.caption())
                            .foregroundStyle(SGDFColors.red)
                    }
                }

                if vm.items.isEmpty {
                    Section {
                        Text("Aucun matériel emporté. Ajoute du matériel.")
                            .font(SGDFTheme.FontStyle.body())
                            .foregroundStyle(SGDFColors.textSecondary)
                            .listRowBackground(SGDFColors.background)
                    }
                } else {
                    Section {
                        ForEach(vm.items) { item in
                            MaterialRow(item: item)
                        }
                        .onDelete { offsets in
                            guard session.canWrite,
                                  let camp = campStore.selectedCamp else { return }
                            for i in offsets {
                                let item = vm.items[i]
                                Task { await vm.remove(campId: camp.id, item: item) }
                            }
                        }
                        .deleteDisabled(!session.canWrite)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(SGDFColors.background)
        }
    }
}

// MARK: - MaterialRow

private struct MaterialRow: View {
    let item: Item

    var body: some View {
        HStack {
            Text(item.name)
                .font(SGDFTheme.FontStyle.body().weight(.semibold))
                .foregroundStyle(SGDFColors.textPrimary)
            Spacer()
            SGDFBadge(status: item.status)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AddMaterialSheet

private struct AddMaterialSheet: View {
    @ObservedObject var vm: CampMaterialViewModel
    let campId: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if vm.available.isEmpty {
                    EmptyStateView(
                        systemImage: "shippingbox",
                        title: "Aucun matériel disponible",
                        message: "Tout le matériel est déjà assigné ou indisponible."
                    )
                } else {
                    List(vm.available) { item in
                        AvailableItemRow(item: item, isSelected: selected.contains(item.id))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(item.id) {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Ajouter du matériel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(SGDFColors.primaryBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        Task {
                            await vm.add(campId: campId, itemIds: selected)
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty)
                    .foregroundStyle(selected.isEmpty ? SGDFColors.textSecondary : SGDFColors.primaryBlue)
                }
            }
            .task { await vm.loadAvailable() }
        }
    }
}

// MARK: - AvailableItemRow

private struct AvailableItemRow: View {
    let item: Item
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                Text(item.name)
                    .font(SGDFTheme.FontStyle.body().weight(.semibold))
                    .foregroundStyle(SGDFColors.textPrimary)
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SGDFColors.primaryBlue)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(SGDFColors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

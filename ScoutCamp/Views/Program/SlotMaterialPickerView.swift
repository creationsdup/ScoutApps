import SwiftUI
import ScoutKit

/// Sélecteur de matériel pour un créneau de planning.
/// Utilisé en push depuis ProgramSlotFormView.
struct SlotMaterialPickerView: View {
    let allItems: [Item]
    @Binding var selectedIds: Set<String>
    @State private var search: String = ""

    private var filtered: [Item] {
        if search.isEmpty { return allItems }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { item in
                MaterialPickerRow(
                    item: item,
                    isSelected: selectedIds.contains(item.id)
                ) {
                    if selectedIds.contains(item.id) {
                        selectedIds.remove(item.id)
                    } else {
                        selectedIds.insert(item.id)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Rechercher un article")
        .navigationTitle("Matériel (\(selectedIds.count))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Row (private subview)

private struct MaterialPickerRow: View {
    let item: Item
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                    Text(item.name)
                        .font(SGDFTheme.FontStyle.body())
                        .foregroundStyle(SGDFColors.textPrimary)
                    SGDFBadge(status: item.status)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? SGDFColors.violet : SGDFColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct MaterialDetailView: View {
    let item: Item
    @ObservedObject var listViewModel: MaterialListViewModel

    private var imageURL: URL? {
        guard let path = item.imagePath else { return nil }
        return try? ImageStorageService().publicURL(for: path)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGDFTheme.Spacing.lg) {
                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(SGDFColors.border)
                                .overlay(Image(systemName: "photo")
                                    .foregroundStyle(SGDFColors.textSecondary))
                        }
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
                }

                HStack {
                    Text(item.name)
                        .font(SGDFTheme.FontStyle.screenTitle())
                        .foregroundStyle(SGDFColors.textPrimary)
                    Spacer()
                    SGDFBadge(status: item.status)
                }
                Text(item.inventoryCode)
                    .font(SGDFTheme.FontStyle.caption())
                    .foregroundStyle(SGDFColors.textSecondary)

                if let description = item.description, !description.isEmpty {
                    Text(description).foregroundStyle(SGDFColors.textPrimary)
                }

                SGDFCard {
                    DetailRow(label: "État", value: item.condition.label)
                    DetailRow(label: "Suivi", value: item.trackingType.label)
                    DetailRow(label: "Quantité",
                              value: "\(item.quantityAvailable ?? item.quantity) / \(item.quantity)")
                    if let branch = item.branch { DetailRow(label: "Branche", value: branch.label) }
                    if let cat = listViewModel.categoryName(item.categoryId) {
                        DetailRow(label: "Catégorie", value: cat)
                    }
                    if let loc = listViewModel.locationName(item.locationId) {
                        DetailRow(label: "Localisation", value: loc)
                    }
                }

                if let notes = item.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: SGDFTheme.Spacing.xs) {
                        Text("Notes").font(SGDFTheme.FontStyle.sectionTitle())
                            .foregroundStyle(SGDFColors.textPrimary)
                        Text(notes).foregroundStyle(SGDFColors.textSecondary)
                    }
                }
            }
            .padding(SGDFTheme.Spacing.md)
        }
        .background(SGDFColors.background)
        .navigationTitle("Fiche matériel")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Ligne label/valeur dans la fiche.
private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(SGDFColors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(SGDFColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(SGDFTheme.FontStyle.body())
    }
}

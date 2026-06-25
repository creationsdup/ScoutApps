import SwiftUI
import VisionKit

struct ScanView: View {
    @EnvironmentObject private var appState: AppState
    @State private var manualCode = ""
    @State private var message = "Scanne une étiquette TAG-000001 ou saisis le code."
    @State private var resolvedItem: InventoryItem?
    @State private var isResolving = false

    private var cameraSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if cameraSupported {
                    CameraScanner { code in resolve(code) }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 140)
                        .overlay(Text("Caméra indisponible — saisie manuelle").foregroundStyle(.secondary))
                }

                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    TextField("TAG-000001", text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Vérifier") { resolve(manualCode) }
                        .disabled(manualCode.isEmpty || isResolving)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Scan QR")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            appState.selectedEvent = nil
                        } label: {
                            Label("Hors évènement", systemImage: appState.selectedEvent == nil ? "checkmark" : "")
                        }
                        ForEach(appState.events) { event in
                            Button {
                                appState.selectedEvent = event
                            } label: {
                                Label(event.name, systemImage: appState.selectedEvent?.id == event.id ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(appState.selectedEvent?.name ?? "Hors évènement")
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Déconnexion") { appState.logout() }
                }
            }
            .safeAreaInset(edge: .top) {
                Text(appState.selectedEvent.map { "Évènement : \($0.name)" } ?? "Hors évènement")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                    .background(.bar)
            }
            .task { await appState.loadEvents() }
            .navigationDestination(item: $resolvedItem) { item in
                ItemDetailView(item: item)
            }
        }
    }

    private func resolve(_ raw: String) {
        guard !isResolving else { return }
        Task {
            isResolving = true
            let resolution = await appState.resolveTag(raw)
            switch resolution {
            case .item(let item):
                resolvedItem = item
            case .unassigned(let m), .disabled(let m), .unknown(let m), .invalid(let m):
                message = m
            }
            isResolving = false
        }
    }
}

/// Lecteur de QR codes basé sur VisionKit DataScanner.
struct CameraScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                onScan(value)
            }
        }
    }
}

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @StateObject private var listViewModel = MaterialListViewModel()
    @State private var manualCode = ""
    @State private var message = "Scanne une étiquette TAG-000001 ou saisis le code."
    @State private var resolvedItem: Item?
    @State private var blankTagCode: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: SGDFTheme.Spacing.md) {
                QRCameraView { code in resolve(code) }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)
                            .stroke(SGDFColors.primaryBlue, lineWidth: 2)
                    )

                Text(message)
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: SGDFTheme.Spacing.sm) {
                    SGDFTextField("TAG-000001", text: $manualCode, systemImage: "number")
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    SGDFButton("Vérifier", kind: .primary) { resolve(manualCode) }
                }

                Spacer()
            }
            .padding(SGDFTheme.Spacing.md)
            .background(SGDFColors.background)
            .navigationTitle("Scan QR")
            .navigationDestination(item: $resolvedItem) { item in
                MaterialDetailView(item: item, listViewModel: listViewModel)
            }
            .sheet(item: $blankTagCode) { code in
                AssignQRCodeView(tagCode: code) {
                    message = "Étiquette \(code) associée."
                }
            }
            .task { await listViewModel.loadReferentials() }
        }
    }

    private func resolve(_ raw: String) {
        guard !viewModel.isResolving, !raw.isEmpty else { return }
        Task {
            switch await viewModel.resolve(raw) {
            case .item(let item):
                resolvedItem = item
            case .unassigned(let m):
                message = m
                blankTagCode = TagCode.parse(raw)
            case .disabled(let m), .unknown(let m), .invalid(let m):
                message = m
            }
        }
    }
}

/// Caméra QR basée sur AVFoundation. Sur simulateur (pas de caméra), l'aperçu reste noir
/// — la saisie manuelle prend le relais.
struct QRCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onScan = onScan
        return controller
    }
    func updateUIViewController(_ controller: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false
    private var configured = false
    private let sessionQueue = DispatchQueue(label: "fr.scoutmanager.scan.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async { self?.configureSession() }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Réarme le scanner au retour (ex. après consultation d'une fiche) :
        // sans ça, didScan reste vrai et la session stoppée → plus aucune détection.
        guard configured, !session.isRunning else { return }
        didScan = false
        sessionQueue.async { [session] in session.startRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
        configured = true

        sessionQueue.async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didScan,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        didScan = true
        sessionQueue.async { [session] in session.stopRunning() }
        onScan?(value)
    }
}

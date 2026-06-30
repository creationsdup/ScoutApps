import SwiftUI
import AVFoundation

/// Scanner de code-barres (EAN-8/EAN-13 + QR) présenté en sheet. Renvoie la chaîne brute lue.
/// Sur simulateur (pas de caméra), l'aperçu reste noir : saisie manuelle de secours.
struct BarcodeScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var manual = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: SGDFTheme.Spacing.md) {
                BarcodeCameraView { code in
                    onScanned(code)
                    dismiss()
                }
                .frame(maxWidth: .infinity).frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: SGDFTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: SGDFTheme.Radius.card)
                        .stroke(SGDFColors.primaryBlue, lineWidth: 2)
                )

                Text("Vise le code-barres, ou saisis-le.")
                    .font(SGDFTheme.FontStyle.body())
                    .foregroundStyle(SGDFColors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: SGDFTheme.Spacing.sm) {
                    SGDFTextField("Code-barres", text: $manual, systemImage: "barcode")
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    SGDFButton("Valider", kind: .primary) {
                        let v = manual.trimmingCharacters(in: .whitespaces)
                        guard !v.isEmpty else { return }
                        onScanned(v); dismiss()
                    }
                }
                Spacer()
            }
            .padding(SGDFTheme.Spacing.md)
            .background(SGDFColors.background)
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }
}

/// Caméra code-barres AVFoundation : EAN-8/EAN-13 + QR.
struct BarcodeCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let c = BarcodeScannerController(); c.onScan = onScan; return c
    }
    func updateUIViewController(_ controller: BarcodeScannerController, context: Context) {}
}

final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false
    private var configured = false
    private let sessionQueue = DispatchQueue(label: "fr.scoutmanager.barcode.session")

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
        output.metadataObjectTypes = [.ean8, .ean13, .qr]   // <-- code-barres + QR
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

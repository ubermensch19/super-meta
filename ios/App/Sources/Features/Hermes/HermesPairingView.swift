import SwiftUI
import DesignSystem
import AgentGateway
import VisionKit
import Inject

/// One-screen gateway pairing: paste the dashboard/gateway URL (or scan it as a
/// QR code), and we fill in host, port, TLS, and token. New devices then show up
/// on the gateway for a one-time approval.
struct HermesPairingView: View {
    @EnvironmentObject private var hermes: HermesService
    @EnvironmentObject private var gateway: GatewayService
    @Environment(\.dismiss) private var dismiss
    @ObserveInjection var inject

    @State private var endpointText = ""
    @State private var errorText: String?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Paste your gateway address — the same URL that opens your OpenClaw or Hermes dashboard. The token is picked up automatically.")
                        .font(Theme.Font.body(14))
                        .foregroundStyle(Theme.Palette.textSecondary)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("GATEWAY URL")
                            .font(Theme.Font.readout(10)).tracking(1)
                            .foregroundStyle(Theme.Palette.textMuted)
                        TextField("wss://hermes.tail1234.ts.net#token=…", text: $endpointText, axis: .vertical)
                            .lineLimit(1...3)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(Theme.Font.body(13))
                            .foregroundStyle(Theme.Palette.live)
                    }

                    HUDButton("Connect", systemImage: "bolt") { applyEndpoint(endpointText) }

                    if DataScannerViewController.isSupported {
                        Button {
                            showScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan QR code instead")
                            }
                            .font(Theme.Font.body(14))
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if hermes.state == .waitingForPairing {
                        HUDPanel {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                StatusBadge("awaiting approval", color: Theme.Palette.accent)
                                Text("Approve this device on your gateway:")
                                    .font(Theme.Font.body(13))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                Text("openclaw devices approve  ·  \(gateway.nodeID)")
                                    .font(Theme.Font.readout(12))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    Text("Away from home? Run the gateway behind Tailscale (openclaw gateway --tailscale serve) and use its wss:// URL here — it works from anywhere.")
                        .font(Theme.Font.body(12))
                        .foregroundStyle(Theme.Palette.textMuted)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Pair with Hermes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                showScanner = false
                endpointText = code
                applyEndpoint(code)
            }
        }
        .preferredColorScheme(.dark)
        .enableInjection()
    }

    private func applyEndpoint(_ raw: String) {
        guard let endpoint = Self.parseEndpoint(raw) else {
            errorText = "Couldn't read that address. Expected something like wss://host:18789#token=…"
            return
        }
        errorText = nil
        gateway.host = endpoint.host
        gateway.port = endpoint.port
        gateway.useTLS = endpoint.tls
        if let token = endpoint.token { gateway.token = token }
        hermes.connect()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if hermes.state == .connected { dismiss() }
        }
    }

    /// Accepts `wss://host:port#token=…`, `ws://host:port?token=…`, a bare
    /// `host[:port]`, or a Control UI link with a `gatewayUrl` query parameter.
    static func parseEndpoint(_ raw: String) -> (host: String, port: Int, tls: Bool, token: String?)? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "ws://" + text }
        guard let components = URLComponents(string: text), let host = components.host, !host.isEmpty else {
            return nil
        }

        var token = components.queryItems?.first(where: { $0.name == "token" })?.value
        // The dashboard puts the token in the fragment so it never hits server logs.
        if token == nil, let fragment = components.fragment {
            token = URLComponents(string: "?" + fragment)?
                .queryItems?.first(where: { $0.name == "token" })?.value
            if token == nil, !fragment.contains("=") { token = fragment }
        }

        // Control UI dev links carry the real endpoint in ?gatewayUrl=…
        if let nested = components.queryItems?.first(where: { $0.name == "gatewayUrl" })?.value,
           let inner = parseEndpoint(nested) {
            return (inner.host, inner.port, inner.tls, token ?? inner.token)
        }

        let tls = components.scheme == "wss" || components.scheme == "https"
        let port = components.port ?? (tls ? 443 : 18789)
        return (host, port, tls, token)
    }
}

// MARK: - QR scanner

private struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    dataScanner.stopScanning()
                    onCode(payload)
                    return
                }
            }
        }
    }
}

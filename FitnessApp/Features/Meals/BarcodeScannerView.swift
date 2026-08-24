//
//  BarcodeScannerView.swift
//  Arovia
//
//  Camera-based barcode scanning via VisionKit's DataScannerViewController (iOS 16+, requires a
//  device with a Neural Engine — not available in Simulator or on older hardware, hence the
//  isSupported/isAvailable checks and graceful fallback below).
//

import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

struct BarcodeScannerView: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                #if canImport(VisionKit)
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    BarcodeScannerRepresentable { code in
                        onScan(code)
                    }
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        Text("Point the camera at a barcode")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(.bottom, 40)
                    }
                } else {
                    unsupportedView
                }
                #else
                unsupportedView
                #endif
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var unsupportedView: some View {
        ContentUnavailableView(
            "Barcode Scanning Unavailable",
            systemImage: "barcode.viewfinder",
            description: Text("This device doesn't support barcode scanning (needs a real device with a Neural Engine — this won't work in Simulator). You can still add the food manually.")
        )
    }
}

#if canImport(VisionKit)
private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    hasScanned = true
                    dataScanner.stopScanning()
                    onScan(payload)
                    break
                }
            }
        }
    }
}
#endif

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Encodes the printed receipt number; it is not a link to stored data.
struct ReviewReceiptBarcode: View {
    let document: ReviewReceiptDocument
    @State private var image: UIImage?

    private var identifier: String {
        let date = document.start.formatted(
            .dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))
        ).filter(\.isNumber)
        return "RV-" + date
    }

    var body: some View {
        VStack(spacing: 5) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .renderingMode(.template)
                        .interpolation(.none)
                        .resizable()
                } else {
                    Image(systemName: "barcode")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            Text(identifier)
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
        }
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: AppLanguage.text("复盘记录条形码，编号 %@"), identifier))
        .task(id: identifier) { image = makeCode(from: identifier) }
    }

    private func makeCode(from value: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(value.utf8)
        filter.quietSpace = 10
        guard let output = filter.outputImage,
              let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: output])?.outputImage,
              let transparent = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey: inverted])?.outputImage,
              let cgImage = CIContext().createCGImage(transparent, from: transparent.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

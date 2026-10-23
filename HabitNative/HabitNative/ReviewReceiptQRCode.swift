import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ReviewReceiptQRCode: View {
    let document: ReviewReceiptDocument
    @State private var image: UIImage?

    private var payload: String {
        let identifier = document.start.formatted(
            .dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_CN"))
        ).filter(\.isNumber)
        let start = document.start.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
        let end = document.end.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
        return "习惯复盘 RV-\(identifier)\n周期：\(start)–\(end)\n完成：\(document.completions)次\n积分：\(document.points)分"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .padding(15)
                    .foregroundStyle(.black.opacity(0.55))
            }
        }
        .frame(width: 62, height: 62)
        .padding(4)
        .background(.white)
        .accessibilityLabel("本期行动概览二维码")
        .task(id: payload) { image = makeCode(from: payload) }
    }

    private func makeCode(from value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

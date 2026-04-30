import SwiftUI

struct WineThumbnail: View {
    let photoData: Data?
    var size: CGFloat = 44

    var body: some View {
        if let data = photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            Image(systemName: "wineglass")
                .font(.system(size: size * 0.4))
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .frame(width: size, height: size)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        }
    }
}

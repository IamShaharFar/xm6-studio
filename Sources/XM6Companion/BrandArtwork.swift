import SwiftUI
import AppKit

enum BrandArtwork {
    // The same unmodified Sony product photograph is used throughout the app.
    // Prefer the installed app's resources; Bundle.module supports SwiftPM runs.
    static let headphones: NSImage = {
        let url = Bundle.main.url(forResource: "WH1000XM6", withExtension: "png")
            ?? Bundle.module.url(forResource: "WH1000XM6", withExtension: "png")!
        return NSImage(contentsOf: url)!
    }()
}

struct HeadphoneArtwork: View {
    var size: CGFloat = 44
    var showsBackground = true
    var body: some View {
        Image(nsImage: BrandArtwork.headphones)
            .resizable().interpolation(.high).scaledToFill()
            .frame(width: size * 0.92, height: size * 0.92)
            .clipped()
            .frame(width: size, height: size)
            .background {
                if showsBackground {
                    RoundedRectangle(cornerRadius: size * 0.23)
                        .fill(LinearGradient(colors: [Color(red: 0.94, green: 0.98, blue: 0.97), Color(red: 0.76, green: 0.88, blue: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .accessibilityLabel("Sony WH-1000XM6 headphones")
    }
}

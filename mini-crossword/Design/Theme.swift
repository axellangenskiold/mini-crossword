import SwiftUI

enum Theme {
    static let backgroundTop = Color(hex: 0xF4EDE0)
    static let backgroundBottom = Color(hex: 0xD8E8E1)
    static let accent = Color(hex: 0x0F6B63)
    static let ink = Color(hex: 0x1B1B1B)
    static let card = Color(hex: 0xFFF9F0)
    static let muted = Color(hex: 0x6D6A65)
    static let complete = Color(hex: 0x6CC071)
    static let inactive = Color(hex: 0xC8C1B5)
    static let highlight = Color(hex: 0xCFE3FF)

    static func titleFont(size: CGFloat) -> Font {
        .custom("Avenir Next Condensed", size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .custom("Avenir Next Condensed", size: size)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

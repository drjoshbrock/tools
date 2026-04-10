import SwiftUI

enum Sol {
    static let base03 = Color(red: 0/255.0, green: 43/255.0, blue: 54/255.0)
    static let base02 = Color(red: 7/255.0, green: 54/255.0, blue: 66/255.0)
    static let base01 = Color(red: 88/255.0, green: 110/255.0, blue: 117/255.0)
    static let base00 = Color(red: 101/255.0, green: 123/255.0, blue: 131/255.0)
    static let base0  = Color(red: 131/255.0, green: 148/255.0, blue: 150/255.0)
    static let base1  = Color(red: 147/255.0, green: 161/255.0, blue: 161/255.0)
    static let base2  = Color(red: 238/255.0, green: 232/255.0, blue: 213/255.0)
    static let base3  = Color(red: 253/255.0, green: 246/255.0, blue: 227/255.0)

    static let yellow  = Color(red: 181/255.0, green: 137/255.0, blue: 0/255.0)
    static let orange  = Color(red: 203/255.0, green: 75/255.0, blue: 22/255.0)
    static let red     = Color(red: 220/255.0, green: 50/255.0, blue: 47/255.0)
    static let magenta = Color(red: 211/255.0, green: 54/255.0, blue: 130/255.0)
    static let violet  = Color(red: 108/255.0, green: 113/255.0, blue: 196/255.0)
    static let blue    = Color(red: 38/255.0, green: 139/255.0, blue: 210/255.0)
    static let cyan    = Color(red: 42/255.0, green: 161/255.0, blue: 152/255.0)
    static let green   = Color(red: 133/255.0, green: 153/255.0, blue: 0/255.0)
}

struct Theme {
    let colorScheme: ColorScheme

    var bg: Color { colorScheme == .dark ? Sol.base03 : Sol.base3 }
    var bgHighlight: Color { colorScheme == .dark ? Sol.base02 : Sol.base2 }
    var fg: Color { colorScheme == .dark ? Sol.base0 : Sol.base00 }
    var fgDim: Color { colorScheme == .dark ? Sol.base01 : Sol.base1 }
    var fgEmphasis: Color { colorScheme == .dark ? Sol.base1 : Sol.base01 }
    var border: Color { colorScheme == .dark ? Sol.base01 : Sol.base1 }
}

enum DashboardConfig {
    static let lat = 38.40
    static let lon = -85.61
    static let redsId = 113
    static let tz = TimeZone(identifier: "America/New_York")!
}

import SwiftUI

/// The goslo radio logo in pixel art: a "G" at the heart of a symmetric sound wave.
/// Same drawing as the app icon (Tools/Icon/make_icon.py).
struct RadioLogo: View {
    /// Size of one logo pixel, in points.
    var pixel: CGFloat = 2
    var color: Color = Theme.text

    static let rows = [
        ".......................XXXXX.......................",
        "......................XXXXXXX......................",
        "............XX.......XX.....XX.......XX............",
        "............XX....XX.XX.....XX.XX....XX............",
        "............XX....XX.XX........XX....XX............",
        "............XX.XX.XX.XX........XX.XX.XX............",
        ".........XX.XX.XX.XX.XX........XX.XX.XX.XX.........",
        ".........XX.XX.XX.XX.XX........XX.XX.XX.XX.........",
        "......XX.XX.XX.XX.XX.XX........XX.XX.XX.XX.XX......",
        "XX.XX.XX.XX.XX.XX.XX.XX..XXXXX.XX.XX.XX.XX.XX.XX.XX",
        "XX.XX.XX.XX.XX.XX.XX.XX..XXXXX.XX.XX.XX.XX.XX.XX.XX",
        "......XX.XX.XX.XX.XX.XX.....XX.XX.XX.XX.XX.XX......",
        ".........XX.XX.XX.XX.XX.....XX.XX.XX.XX.XX.........",
        ".........XX.XX.XX.XX.XX.....XX.XX.XX.XX.XX.........",
        "............XX.XX.XX.XX.....XX.XX.XX.XX............",
        "............XX....XX.XX.....XX.XX....XX............",
        "............XX....XX.XX.....XX.XX....XX............",
        "............XX.......XX.....XX.......XX............",
        "......................XXXXXXX......................",
        ".......................XXXXX.......................",
    ]
    static let width = rows[0].count
    static let height = rows.count

    var body: some View {
        Canvas { context, _ in
            for (y, row) in RadioLogo.rows.enumerated() {
                for (x, cell) in row.enumerated() where cell == "X" {
                    let rect = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)
                    context.fill(Path(rect.insetBy(dx: -0.25, dy: -0.25)), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(RadioLogo.width) * pixel, height: CGFloat(RadioLogo.height) * pixel)
        .accessibilityElement()
        .accessibilityLabel("goslo radio")
    }
}

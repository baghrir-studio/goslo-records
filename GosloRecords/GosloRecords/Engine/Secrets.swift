import Foundation

/// Easter eggs: a code name, a hidden room, a rare pigeon, a radio jingle. Each one has its achievement.
enum Secrets {
    /// Typing this as your name dresses you in gold ("Tu connais la maison").
    static let houseName = "goslo"
    /// Knocks on the Bunker's wall that open the archive.
    static let bunkerKnocks = 10
    /// Taps on the goslo radio poster that play the secret jingle.
    static let jingleTaps = 3
    /// One wild encounter in this many, in its city, is the rare local.
    static let rareWildOdds = 12
    static let rareWild: [City: String] = [.lille: "pigeon_lille"]

    static let jingleFlag = "jingle_secret"
    static let archiveFlag = "demos_fred"
    static let pigeonFlag = "sauvage_battu_pigeon_lille"

    static func isHouseName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespaces).lowercased() == houseName
    }

    /// What's behind the Bunker's loose brick.
    static let archiveLines = [
        "Une brique bouge. Derrière : un carton marqué « DÉMOS 2009 — NE PAS TOUCHER (FRED) ».",
        "Dedans, des cassettes annotées au stylo, et le fameux disque d'or. Il est en plastique. Il y a encore le prix dessus.",
        "Tu remets tout en place. Fred n'a pas besoin de savoir. Personne n'a besoin de savoir.",
    ]
}

extension Rapper {
    /// The house code: a gold outfit for those who know.
    var isHouseMember: Bool { Secrets.isHouseName(name) }
}

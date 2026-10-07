import Foundation

/// Freestyle, once per clash: the last word of a bar shows up, pick the one that rhymes among four,
/// and keep chaining until the beat runs out. Each rhyme hits a little harder.
enum Freestyle {
    static let seconds = 10.0
    static let choices = 4
    /// Rhymes counted at most (the crowd stops counting after that).
    static let maxRhymes = 8
    /// From this many rhymes, it's a big hit.
    static let strongAt = 5
    /// A wrong pick costs this much time.
    static let wrongPenalty = 1.0

    /// Words sharing their last sound.
    static let families: [[String]] = [
        ["bitume", "costume", "plume", "légume", "brume", "enclume", "rhume", "amertume"],
        ["nation", "passion", "mission", "création", "ambition", "attention", "émotion", "pression"],
        ["lumière", "frontière", "poussière", "prière", "carrière", "rivière", "barrière", "première"],
        ["danse", "chance", "silence", "violence", "vengeance", "distance", "confiance", "enfance"],
        ["rêve", "grève", "trêve", "sève", "élève", "relève", "brève", "glaive"],
        ["regard", "retard", "brouillard", "cafard", "hasard", "dollar", "guitare", "bavard"],
        ["fric", "public", "déclic", "trafic", "panique", "musique", "magique", "brique"],
        ["cœur", "peur", "douleur", "couleur", "rancœur", "honneur", "chaleur", "rumeur"],
        ["espoir", "miroir", "trottoir", "histoire", "mémoire", "couloir", "victoire", "noir"],
        ["planète", "tempête", "silhouette", "casquette", "conquête", "fête", "tête", "défaite"],
        ["famille", "grille", "coquille", "aiguille", "bille", "vanille", "brindille", "pastille"],
        ["genou", "bijou", "voyou", "caillou", "hibou", "tabou", "bambou", "verrou"],
    ]

    struct Round: Equatable {
        let prompt: String
        let options: [String]
        let answer: Int
    }

    static func family(of word: String) -> Int? {
        families.firstIndex { $0.contains(word) }
    }

    static func rhymes(_ a: String, _ b: String) -> Bool {
        a != b && family(of: a) != nil && family(of: a) == family(of: b)
    }

    /// A prompt word, one rhyme and three words that don't. Never the family just played.
    static func round<R: RandomNumberGenerator>(after previous: Round? = nil, using rng: inout R) -> Round {
        let last = previous.flatMap { family(of: $0.prompt) }
        let pick = families.indices.filter { $0 != last }.randomElement(using: &rng)!
        let words = families[pick].shuffled(using: &rng)
        let others = families.indices.filter { $0 != pick }.shuffled(using: &rng).prefix(choices - 1)
        var options = [words[1]] + others.map { families[$0].randomElement(using: &rng)! }
        options.shuffle(using: &rng)
        return Round(prompt: words[0], options: options, answer: options.firstIndex(of: words[1])!)
    }

    /// Damage of a freestyle: nothing without a rhyme, then more per rhyme as the pen gets better.
    static func damage(rhymes: Int, level: Int) -> Int {
        let rhymes = min(max(rhymes, 0), maxRhymes), level = min(max(level, 1), 10)
        return rhymes == 0 ? 0 : 3 + rhymes * (2 + level / 3)
    }

    static func line(rhymes: Int) -> String {
        switch min(rhymes, maxRhymes) {
        case 0: "Tu ouvres la bouche, rien ne sort. Le beat continue sans toi. Quelqu'un tousse."
        case 1...2: "Deux rimes, un peu laborieuses. Le public t'accorde un « ouais » poli."
        case 3...4: "Ça s'enchaîne ! Le premier rang commence à hocher la tête."
        case 5...6: "Les rimes tombent en rafale. La salle crie chaque fin de mesure avec toi."
        default: "Huit rimes sans respirer. Le DJ coupe le son pour laisser la salle hurler."
        }
    }
}

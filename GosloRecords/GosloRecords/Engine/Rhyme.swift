import Foundation

// MARK: - Dictionary

/// The French word list used to check a typed punchline (Resources/french-words.txt, built by
/// Tools/Dictionary/build_dictionary.py from `an-array-of-french-words`, MIT). Words are stored normalised:
/// lowercase, no accents, letters only — so « ete » and « été » are the same word.
struct FrenchDictionary {
    let words: Set<String>

    init<S: Sequence>(words: S) where S.Element == String {
        self.words = Set(words.map(FrenchDictionary.normalize).filter { !$0.isEmpty })
    }

    /// Reads the front-coded file: each line is one character for how many leading letters are shared with
    /// the previous word ('0'…'9', then 'A'…'Z' for 10…35), followed by the rest of the word.
    init(frontCoded data: Data) {
        var words = Set<String>()
        words.reserveCapacity(330_000)
        var current: [UInt8] = []
        var lineStart = true
        for byte in data {
            if byte == 0x0A {
                if !current.isEmpty { words.insert(String(decoding: current, as: UTF8.self)) }
                lineStart = true
            } else if byte == 0x0D {
                continue
            } else if lineStart {
                let shared: Int
                switch byte {
                case 0x30...0x39: shared = Int(byte - 0x30)
                case 0x41...0x5A: shared = Int(byte - 0x41) + 10
                default: shared = 0
                }
                current.removeLast(max(0, current.count - shared))
                lineStart = false
            } else {
                current.append(byte)
            }
        }
        if !lineStart, !current.isEmpty { words.insert(String(decoding: current, as: UTF8.self)) }
        self.words = words
    }

    var count: Int { words.count }

    /// Is this a French word? Accents and case don't matter; « l'hiver » is checked as « hiver ».
    func contains(_ word: String) -> Bool {
        let lowered = word.lowercased()
        let whole = FrenchDictionary.normalize(lowered)
        guard !whole.isEmpty else { return false }
        if words.contains(whole) { return true }
        let last = lowered.split(whereSeparator: { "'’-".contains($0) }).last.map(String.init) ?? lowered
        let tail = FrenchDictionary.normalize(last)
        return !tail.isEmpty && words.contains(tail)
    }

    /// Lowercase, accents removed, œ → oe, æ → ae, only the letters a…z kept.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "æ", with: "ae")
        var result = String.UnicodeScalarView()
        for scalar in lowered.decomposedStringWithCanonicalMapping.unicodeScalars where ("a"..."z").contains(scalar) {
            result.append(scalar)
        }
        return String(result)
    }
}

// MARK: - Rhymes

/// How well two words rhyme, by the number of sounds they share at the end.
enum RhymeQuality: Int, Comparable, CaseIterable, Codable {
    /// The last vowel (and what follows it) differs, or it's the same word.
    case aucune
    /// Only the last vowel: « ami / pari ».
    case pauvre
    /// Two sounds: « nuit / bruit ».
    case suffisante
    /// Three sounds or more: « nation / passion ».
    case riche

    static func < (lhs: RhymeQuality, rhs: RhymeQuality) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .riche: "Rime riche"
        case .suffisante: "Rime suffisante"
        case .pauvre: "Rime pauvre"
        case .aucune: "Pas de rime"
        }
    }
}

/// A rough French phonetisation, good enough to hear how words END: silent final letters, digraphs and
/// trigraphs, nasal vowels, soft c/g, -tion… It merges close sounds the way rap does (é/è, o/ô, eu/e muet).
/// Foundation only, no dictionary needed (one helps to spot verbs in -ent: « ils chantent »).
enum Rhyme {
    /// One sound, and the letters of the word that make it (for « -tion / -ssion »).
    struct Sound: Equatable {
        let phoneme: String
        let letters: Range<Int>
    }

    /// Vowel sounds (the rest are consonants, j and w included).
    static let vowels: Set<String> = ["a", "e", "i", "o", "u", "y", "ø", "ɑ̃", "ɛ̃", "ɔ̃"]

    /// The last word of a line, without punctuation (« hiver, » → « hiver »). nil if there's no word.
    static func lastWord(of line: String) -> String? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace })
        for token in tokens.reversed() {
            let word = token.filter { $0.isLetter || "'’-".contains($0) }
                .trimmingCharacters(in: CharacterSet(charactersIn: "'’-"))
            if word.contains(where: \.isLetter) { return word }
        }
        return nil
    }

    /// The letters looked at: lowercase, after any elision (« l'écho » → « écho »), hyphens dropped, œ/æ split.
    static func letters(of word: String) -> [Character] {
        let lowered = word.lowercased()
        // After an elision (« l'écho ») or a hyphen (« hip-hop »), only the last part rhymes.
        let last = lowered.split(whereSeparator: { "'’-".contains($0) }).last.map(String.init) ?? lowered
        let expanded = last.replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "æ", with: "ae")
        return expanded.precomposedStringWithCanonicalMapping.filter(\.isLetter).map { $0 }
    }

    /// The phonemes of a word, in order.
    static func phonemes(_ word: String, lexicon: FrenchDictionary? = nil) -> [String] {
        sounds(word, lexicon: lexicon).map(\.phoneme)
    }

    /// How well `a` and `b` rhyme. The same word twice is no rhyme.
    static func quality(_ a: String, _ b: String, lexicon: FrenchDictionary? = nil) -> RhymeQuality {
        match(a, b, lexicon: lexicon).quality
    }

    /// The quality and, when they rhyme, the letters that rhyme in each word (« tion », « ssion »).
    static func match(_ a: String, _ b: String, lexicon: FrenchDictionary? = nil)
        -> (quality: RhymeQuality, endings: (String, String)?) {
        let left = letters(of: a), right = letters(of: b)
        guard !left.isEmpty, !right.isEmpty,
              FrenchDictionary.normalize(String(left)) != FrenchDictionary.normalize(String(right)) else { return (.aucune, nil) }
        let x = sounds(left, lexicon: lexicon), y = sounds(right, lexicon: lexicon)
        guard let lastVowel = x.lastIndex(where: { vowels.contains($0.phoneme) }),
              y.contains(where: { vowels.contains($0.phoneme) }) else { return (.aucune, nil) }
        var shared = 0
        while shared < min(x.count, y.count) && x[x.count - 1 - shared].phoneme == y[y.count - 1 - shared].phoneme {
            shared += 1
        }
        // The last vowel and everything after it must be the same.
        guard shared >= x.count - lastVowel else { return (.aucune, nil) }
        let quality: RhymeQuality = shared >= 3 ? .riche : shared == 2 ? .suffisante : .pauvre
        let spell = { (word: [Character], sounds: [Sound]) in
            String(word[sounds[sounds.count - shared].letters.lowerBound...])
        }
        return (quality, (spell(left, x), spell(right, y)))
    }

    static func sounds(_ word: String, lexicon: FrenchDictionary? = nil) -> [Sound] {
        sounds(letters(of: word), lexicon: lexicon)
    }

    // MARK: Phonetisation

    private static let vowelLetters: Set<Character> = ["a", "e", "i", "o", "u", "y", "à", "â", "ä", "é", "è", "ê", "ë",
                                                       "î", "ï", "ô", "ö", "ù", "û", "ü", "ÿ"]
    /// Letters after which c and g are soft.
    private static let softeners: Set<Character> = ["e", "i", "y", "é", "è", "ê", "ë", "î", "ï"]

    /// Words whose final -er sounds [ɛʁ] (« hiver »), not [e] (« parler »).
    private static let openEr: Set<String> = [
        "mer", "fer", "ver", "cher", "hier", "fier", "enfer", "hiver", "super", "amer", "cancer", "laser", "poster",
        "hamster", "gangster", "leader", "rocker", "dealer", "joker", "poker", "bunker", "hacker", "loser", "flyer",
        "master", "killer", "starter", "boxer", "revolver", "cuiller", "ether", "alter", "inter", "cutter", "reporter",
        "scooter", "hipster", "blazer", "mixer", "speaker", "sniper", "biker", "trader", "outsider", "thriller",
        "teaser", "winner", "tiers", "vers", "envers", "travers", "univers", "pervers",
        "divers", "revers", "convers",
    ]
    /// Final s that is heard.
    private static let heardS: Set<String> = [
        "bus", "fils", "sens", "ours", "tennis", "virus", "cactus", "campus", "terminus", "bonus", "blocus", "rebus",
        "lotus", "helas", "as", "atlas", "jadis", "oasis", "mars", "gratis", "iris", "mais", "vis", "lys", "os",
        "biceps", "palmares", "tous", "hiatus", "papyrus", "processus", "consensus", "sinus", "airbus",
        "autobus", "abribus", "omnibus", "pubis", "bis", "tournevis", "fax", "relax", "thorax", "index", "silex",
        "lynx", "sphinx", "phenix", "climax", "max", "ex", "vortex", "latex", "kleenex", "rolex", "gps", "dmx", "boss",
        "stress", "express", "miss", "kiss", "business", "jus", "us",
    ]
    /// Final t that is heard.
    private static let heardT: Set<String> = [
        "net", "huit", "brut", "zut", "chut", "mat", "fat", "but", "dot", "kit", "hit", "flirt", "short", "yaourt",
        "soft", "toast", "test", "raft", "sept", "concept", "abrupt", "rapt", "ouest", "est", "direct", "correct",
        "exact", "intact", "strict", "verdict", "contact", "impact", "compact", "abject", "infect", "select", "tact",
        "district", "dialect", "beat", "street", "tweet", "shoot", "spot", "flat", "smart", "start", "set",
        "match", "boycott", "cut", "knockout", "scout", "input", "output", "transit", "deficit", "debit",
        "credit", "audit", "accessit", "zenith", "granit", "mazout", "azimut", "rut", "scorbut", "occiput",
    ]
    /// … except in these.
    private static let silentT: Set<String> = ["est", "respect", "aspect", "suspect", "chat", "rat", "set", "debit",
                                               "credit"]
    private static let heardD: Set<String> = ["sud", "bled", "raid", "stand", "david", "rad", "lord", "board", "skate",
                                              "kid", "pad", "rand", "grind", "food", "hood", "weekend", "plaid", "fjord"]
    private static let silentP: Set<String> = ["trop", "sirop", "galop", "drap", "sparadrap", "loup", "coup", "beaucoup",
                                               "sept", "corps", "temps", "champ", "camp", "contrechamp", "printemps"]
    private static let silentC: Set<String> = ["tabac", "estomac", "porc", "croc", "escroc", "accroc", "caoutchouc",
                                               "clerc", "marc", "raccroc"]
    private static let silentL: Set<String> = ["gentil", "fusil", "outil", "sourcil", "persil", "nombril", "saoul",
                                               "soul", "cul", "pouls", "fils"]
    private static let silentF: Set<String> = ["clef", "cerf", "nerf", "nerfs", "cerfs", "clefs", "boeufs", "oeufs"]
    private static let silentZ: Set<String> = ["riz", "raz"]
    /// « ill » said [il]: « ville », « mille ».
    private static let hardIll = ["vill", "mill", "tranquill", "pupill", "oscill", "distill", "bacill", "instill"]
    /// « ch » said [k].
    private static let hardCh = ["echo", "orchest", "choral", "chaos", "chrom", "psych", "archange", "chiro", "techn",
                                 "chorus", "chor", "christ", "chlor", "krach", "varech", "lichen", "yacht", "ichthy"]
    /// -ent words that are not verbs even though a verb looks like them (« le président »).
    private static let nasalEnt: Set<String> = [
        "content", "parent", "talent", "souvent", "serpent", "present", "absent", "accent", "argent", "agent", "urgent",
        "moment", "comment", "client", "patient", "violent", "evident", "different", "excellent", "innocent",
        "intelligent", "adolescent", "president", "accident", "incident", "equivalent", "eloquent", "frequent",
        "recent", "decent", "indecent", "regent", "sergent", "torrent", "couvent", "precedent", "resident", "affluent",
        "influent", "negligent", "convergent", "divergent", "emergent", "detergent", "adherent", "coherent",
        "concurrent", "coincident", "confident", "diligent", "indulgent", "permanent", "pertinent", "turbulent",
        "insolent", "opulent", "succulent", "virulent", "fervent", "consent", "orient", "ingredient", "recipient",
        "quotient", "impatient", "omnipotent", "impotent", "transparent", "apparent", "lent", "dent", "vent", "cent",
        "gent", "ardent", "prudent", "imprudent", "strident", "trident", "occident", "dissident", "event", "ferment",
    ]

    private static func isVowel(_ c: Character?) -> Bool { c.map { vowelLetters.contains($0) } ?? false }
    private static func isConsonant(_ c: Character?) -> Bool { c.map { $0.isLetter && !vowelLetters.contains($0) } ?? false }

    /// Is this word a verb whose -ent is silent (« ils chantent »)?
    private static func isVerbEnt(_ w: [Character], plain: String, lexicon: FrenchDictionary?) -> Bool {
        guard plain.hasSuffix("ent"), w.count >= 5, !nasalEnt.contains(plain) else { return false }
        if plain.hasSuffix("tient") || plain.hasSuffix("vient") { return false }
        let stem = String(plain.dropLast(3))
        if stem.hasSuffix("ss") || stem.hasSuffix("nn") || stem.hasSuffix("ill") || stem.hasSuffix("gn")
            || stem.hasSuffix("ai") { return true }
        guard let lexicon else { return false }
        // « disent », « écrivent » (dire, écrire).
        if stem.hasSuffix("s") || stem.hasSuffix("v"), lexicon.words.contains(String(stem.dropLast()) + "re") { return true }
        return ["er", "ir", "re", "oir"].contains { lexicon.words.contains(stem + $0) }
            || (stem.hasSuffix("i") && lexicon.words.contains(stem + "r"))
    }

    private static func sounds(_ w: [Character], lexicon: FrenchDictionary?) -> [Sound] {
        let n = w.count
        guard n > 0 else { return [] }
        let plain = FrenchDictionary.normalize(String(w))
        func at(_ i: Int) -> Character? { i >= 0 && i < n ? w[i] : nil }
        func has(_ s: String, _ i: Int) -> Bool {
            let chars = Array(s)
            guard i >= 0, i + chars.count <= n else { return false }
            for (k, c) in chars.enumerated() where w[i + k] != c { return false }
            return true
        }

        // 1. Silent ending: how many letters are actually said (`end`), and whether a mute e followed.
        var end = n
        var muteE = false
        let vowelBefore = { (limit: Int) in w[0..<max(0, limit)].contains { vowelLetters.contains($0) } }
        if plain == "est" {
            end = 1  // « c'est »: just [e]
        } else if plain.hasSuffix("aient"), n > 5 {
            end = n - 3
        } else if isVerbEnt(w, plain: plain, lexicon: lexicon) {
            end = n - 3
            muteE = true
        } else if w.last == "e", n > 2, vowelBefore(n - 1), at(n - 2) != "e", plain != "que" {
            end = n - 1
            muteE = true
        } else if has("es", n - 2), n > 3, vowelBefore(n - 2), !heardS.contains(plain) {
            end = n - 2
            muteE = true
        }
        if !muteE {
            // Final consonants that aren't said (up to two: « temps », « doigts »).
            for _ in 0..<2 {
                guard end > 1, let last = at(end - 1) else { break }
                let word = String(w[0..<end])
                let key = FrenchDictionary.normalize(word)
                let listed = { (set: Set<String>) in set.contains(key) || set.contains(plain) }
                let before = at(end - 2)
                var silent = false
                switch last {
                case "s":
                    silent = !heardS.contains(key) && before != "s"
                case "x":
                    let six = key == "six" || key == "dix"
                    silent = !heardS.contains(key) && !six
                        && !((before == "a" || before == "e") && !isVowel(at(end - 3)))
                case "t":
                    silent = listed(silentT) || !(listed(heardT) || before == "s" || (before == "c" && end == n)
                                                         || (before == "p" && end == n))
                    if key.hasSuffix("ect") && silentT.contains(key) { end -= 1 } // « respect »: c and t
                case "d": silent = !listed(heardD)
                case "p": silent = listed(silentP) || before == "m" || has("oup", end - 3)
                case "c": silent = listed(silentC) || before == "n"
                case "g": silent = before == "n" && !(key.hasSuffix("ing") && !key.hasSuffix("oing")) && !["gang", "bang", "slang", "boomerang", "gong",
                                                                                  "ping", "pong", "bling", "king"].contains(key)
                case "z": silent = before == "e" || listed(silentZ)
                case "r": silent = before == "e" && end - 2 > 0 && !openEr.contains(key) && !openEr.contains(plain)
                    && !(key.hasSuffix("ier") && ["hier", "fier"].contains(key))
                case "l": silent = listed(silentL)
                case "f": silent = listed(silentF)
                case "b": silent = before == "m"
                // « clash », « punch » keep their h (sh, ch); « ah », « oh » don't.
                case "h": silent = !(before == "s" || before == "c" || before == "p" || before == "t")
                default: silent = false
                }
                guard silent else { break }
                end -= 1
                // After an s or x, look at the letter before (« chats », « temps »); otherwise stop.
                if !(last == "s" || last == "x" || last == "h") { break }
            }
        }

        // 2. Sounds, left to right.
        var out: [Sound] = []
        var pending: Int?  // a silent h waiting to be attached to the next sound
        func emit(_ phoneme: String, _ from: Int, _ to: Int) {
            out.append(Sound(phoneme: phoneme, letters: (pending ?? from)..<to))
            pending = nil
        }
        /// Is the n/m at `j` part of a nasal vowel (followed by a consonant, or the end of the word)?
        func nasal(_ j: Int) -> Bool {
            guard j < end, at(j) == "n" || at(j) == "m" else { return false }
            if j + 1 >= n { return true }
            if j + 1 >= end { return !muteE && !isVowel(at(j + 1)) }
            let next = at(j + 1)
            return isConsonant(next) && next != "n" && next != "m" && next != "h"
        }
        var i = 0
        while i < end {
            let c = w[i]
            let next = at(i + 1)
            // Vowels.
            if isVowel(c) {
                if has("eau", i) { emit("o", i, i + 3); i += 3; continue }
                if c == "a", has("ill", i + 1) { emit("a", i, i + 1); emit("j", i + 1, i + 4); i += 4; continue }
                if c == "a", has("il", i + 1), i + 3 >= end { emit("a", i, i + 1); emit("j", i + 1, i + 3); i += 3; continue }
                if has("ueil", i) || has("oeil", i) || has("euil", i) {
                    let len = has("ill", i + 2) ? 5 : 4
                    emit("ø", i, i + 2); emit("j", i + 2, i + len); i += len; continue
                }
                if has("eil", i) || has("ouil", i) {
                    let vowelLen = c == "e" ? 1 : 2
                    let len = has("ill", i + vowelLen) ? vowelLen + 3 : vowelLen + 2
                    if c == "e" || has("ill", i + vowelLen) || i + len >= end {
                        emit(c == "e" ? "e" : "u", i, i + vowelLen); emit("j", i + vowelLen, i + len); i += len; continue
                    }
                }
                if (c == "i" || c == "y"), has("ll", i + 1), i > 0, !isVowel(at(i - 1)) || at(i - 1) == "u" {
                    if hardIll.contains(where: { plain.hasPrefix($0) }) || plain.hasSuffix("ville") || plain.hasSuffix("villes") {
                        emit("i", i, i + 1); emit("l", i + 1, i + 3)
                    } else {
                        emit("i", i, i + 1); emit("j", i + 1, i + 3)
                    }
                    i += 3; continue
                }
                if has("oin", i), nasal(i + 2) { emit("w", i, i + 1); emit("ɛ̃", i + 1, i + 3); i += 3; continue }
                if has("oi", i) || has("oî", i) { emit("w", i, i + 1); emit("a", i + 1, i + 2); i += 2; continue }
                if has("oy", i), isVowel(at(i + 2)) { emit("w", i, i + 1); emit("a", i + 1, i + 2); emit("j", i + 2, i + 3); i += 3; continue }
                if has("ou", i) || has("oû", i) || has("où", i) { emit("u", i, i + 2); i += 2; continue }
                if has("oo", i) { emit("u", i, i + 2); i += 2; continue }
                if has("ee", i) { emit("i", i, i + 2); i += 2; continue }
                if has("ow", i), i + 2 >= end { emit("o", i, i + 2); i += 2; continue }
                if has("oeu", i) { emit("ø", i, i + 3); i += 3; continue }
                if has("eu", i) || has("eû", i) { emit("ø", i, i + 2); i += 2; continue }
                if has("au", i) { emit("o", i, i + 2); i += 2; continue }
                if (has("ain", i) || has("aim", i) || has("ein", i) || has("eim", i)), nasal(i + 2) {
                    emit("ɛ̃", i, i + 3); i += 3; continue
                }
                if has("ay", i), isVowel(at(i + 2)) { emit("e", i, i + 1); emit("j", i + 1, i + 2); i += 2; continue }
                if has("ai", i) || has("aî", i) || has("ei", i) || has("ay", i) || has("ey", i) {
                    emit("e", i, i + 2); i += 2; continue
                }
                if (c == "a" || c == "e") && (next == "n" || next == "m") && nasal(i + 1) {
                    if c == "e" && next == "n" {
                        let prev = at(i - 1)
                        if prev == "y" || prev == "é" || plain == "examen" || plain == "examens" {
                            emit("ɛ̃", i, i + 2); i += 2; continue
                        }
                        if prev == "i" {
                            let after = at(i + 2)
                            let verbLike = (plain.hasSuffix("tient") || plain.hasSuffix("vient") || plain.hasSuffix("tiens")
                                            || plain.hasSuffix("viens")) && !["patient", "impatient", "quotient"].contains(plain)
                            if after == nil || after == "s" || verbLike || (after == "n") {
                                emit("ɛ̃", i, i + 2); i += 2; continue
                            }
                        }
                    }
                    emit("ɑ̃", i, i + 2); i += 2; continue
                }
                if (c == "i" || c == "y") && (next == "n" || next == "m") && nasal(i + 1) {
                    if plain.hasSuffix("ing"), i + 3 == n || i + 3 == end { emit("i", i, i + 1); emit("ŋ", i + 1, i + 3); i += 3; continue }
                    emit("ɛ̃", i, i + 2); i += 2; continue
                }
                if c == "u" && (next == "n" || next == "m") && nasal(i + 1) {
                    if next == "m", i + 2 == n, plain != "parfum" { emit("o", i, i + 1); emit("m", i + 1, i + 2); i += 2; continue }
                    emit("ɛ̃", i, i + 2); i += 2; continue
                }
                if c == "o" && (next == "n" || next == "m") && nasal(i + 1) {
                    if ["gang", "bang", "pong", "gong"].contains(plain), at(i + 2) == "g" {
                        emit("o", i, i + 1); emit("ŋ", i + 1, i + 3); i += 3; continue
                    }
                    emit("ɔ̃", i, i + 2); i += 2; continue
                }
                if c == "e", has("mment", i) || plain == "femme" || plain == "femmes" { emit("a", i, i + 1); i += 1; continue }
                switch c {
                case "a", "à", "â", "ä": emit("a", i, i + 1)
                case "é", "è", "ê", "ë": emit("e", i, i + 1)
                case "o", "ô", "ö": emit("o", i, i + 1)
                case "u", "û", "ü", "ù": emit("y", i, i + 1)
                case "i", "î", "ï", "y", "ÿ":
                    // Before a vowel that is said: a glide (« passion », « pied »).
                    if isVowel(next), i + 1 < end, i > 0 { emit("j", i, i + 1) } else { emit("i", i, i + 1) }
                case "e":
                    if i + 1 >= end {
                        // « -er », « -et », « -ez », « -es » (les, mes) say [e]; a lone e is muet.
                        emit(end < n && !muteE ? "e" : "ø", i, i + 1)
                    } else {
                        let c1 = at(i + 1), c2 = at(i + 2)
                        let closed = isConsonant(c1) && (i + 2 >= end || (isConsonant(c2) && !(c2 == "r" || c2 == "l" || c2 == "h"))
                                                          || c1 == "x" || (c1 == c2))
                        emit(closed ? "e" : "ø", i, i + 1)
                    }
                default: emit("ø", i, i + 1)
                }
                i += 1
                continue
            }

            // Consonants.
            switch c {
            case "h":
                if pending == nil { pending = i }
                i += 1
            case "c":
                if next == "h" {
                    let hard = at(i + 2) == "r" || (at(i + 2) == "l" && !plain.contains("punch")) || hardCh.contains { plain.contains($0) }
                    emit(hard ? "k" : "ʃ", i, i + 2); i += 2
                } else if next == "k" {
                    emit("k", i, i + 2); i += 2
                } else if next == "c", let after = at(i + 2), softeners.contains(after) {
                    emit("k", i, i + 1); emit("s", i + 1, i + 2); i += 2
                } else if next == "c" {
                    emit("k", i, i + 2); i += 2
                } else {
                    emit(next.map { softeners.contains($0) } == true ? "s" : "k", i, i + 1); i += 1
                }
            case "ç": emit("s", i, i + 1); i += 1
            case "s":
                if has("sch", i) || has("sh", i) { let len = has("sch", i) ? 3 : 2; emit("ʃ", i, i + len); i += len; continue }
                if next == "s" { emit("s", i, i + 2); i += 2; continue }
                if next == "c", let after = at(i + 2), softeners.contains(after) { emit("s", i, i + 2); i += 2; continue }
                emit(isVowel(at(i - 1)) && isVowel(next) && i > 0 ? "z" : "s", i, i + 1); i += 1
            case "p":
                // « sept », « compter », « baptême »: the p is silent.
                if next == "t", ["sept", "compt", "bapt", "sculpt", "prompt", "exempt"].contains(where: { plain.hasPrefix($0) }) {
                    if pending == nil { pending = i }
                    i += 1
                    continue
                }
                if next == "h" { emit("f", i, i + 2); i += 2 } else { emit("p", i, i + (next == "p" ? 2 : 1)); i += next == "p" ? 2 : 1 }
            case "t":
                if next == "h" { emit("t", i, i + 2); i += 2; continue }
                let soft = (has("tion", i) || has("tiel", i) || has("tial", i) || has("tieux", i) || has("tience", i)
                            || ((plain.hasPrefix("patien") || plain.hasPrefix("impatien") || plain.hasPrefix("quotien")) && has("tien", i)))
                    && at(i - 1) != "s" && at(i - 1) != "x"
                if soft { emit("s", i, i + 1); i += 1 } else { emit("t", i, i + (next == "t" ? 2 : 1)); i += next == "t" ? 2 : 1 }
            case "g":
                if next == "n" { emit("ɲ", i, i + 2); i += 2; continue }
                if next == "u", has("ueil", i + 1) { emit("g", i, i + 1); i += 1; continue }  // « orgueil »
                if next == "u", let after = at(i + 2), softeners.contains(after) { emit("g", i, i + 2); i += 2; continue }
                if next == "u", i + 2 >= end, muteE { emit("g", i, i + 2); i += 2; continue }
                if next == "e", let after = at(i + 2), "aouâô".contains(after) { emit("ʒ", i, i + 2); i += 2; continue }
                if next == "g" { emit("g", i, i + 2); i += 2; continue }
                emit(next.map { softeners.contains($0) } == true ? "ʒ" : "g", i, i + 1); i += 1
            case "q":
                emit("k", i, i + (next == "u" ? 2 : 1)); i += next == "u" ? 2 : 1
            case "x":
                if i == end - 1, plain == "six" || plain == "dix" { emit("s", i, i + 1); i += 1; continue }
                if i > 0, at(i - 1) == "e", isVowel(next), i < 2 || w[0] == "e" {
                    emit("g", i, i + 1); emit("z", i, i + 1)
                } else {
                    emit("k", i, i + 1); emit("s", i, i + 1)
                }
                i += 1
            case "j": emit("ʒ", i, i + 1); i += 1
            case "r": emit("ʁ", i, i + (next == "r" ? 2 : 1)); i += next == "r" ? 2 : 1
            case "w": emit(i == 0 && plain.hasPrefix("wag") ? "v" : "w", i, i + 1); i += 1
            case "k": emit("k", i, i + 1); i += 1
            default:
                let same = next == c
                emit(String(c), i, i + (same ? 2 : 1))
                i += same ? 2 : 1
            }
        }
        // The silent letters belong to the last sound (« nation » → « -tion », « passions » → « -ssions »).
        if let last = out.last {
            out[out.count - 1] = Sound(phoneme: last.phoneme, letters: last.letters.lowerBound..<n)
        }
        return out
    }
}

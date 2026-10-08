import Foundation

/// goslo radio's philosopher: he reads your punchlines (the refrains you wrote) the way he'd read a classic,
/// one thinker at a time, and posts the analysis on the radio's account.
enum Philosopher {
    static let id = "philosophe_goslo"
    /// XP for the pen, the first time a refrain is analysed.
    static let readingXP = 20
    static func readFlag(_ index: Int) -> String { "philo_lu_\(index)" }

    /// One reading per thinker; `{h}` is the refrain.
    static let readings = [
        "« {h} ». Nietzsche disait qu'il faut avoir du chaos en soi pour enfanter une étoile qui danse. Toi, t'as surtout du chaos. Mais l'étoile n'est pas loin.",
        "« {h} ». Il faut imaginer Sisyphe heureux, disait Camus. Moi j'imagine Sisyphe en train de rapper ça : il pousse moins vite son rocher, mais il a le flow.",
        "« {h} ». Socrate savait qu'il ne savait rien. Toi, tu sais rimer. Ça te fait déjà un point d'avance sur Socrate.",
        "« {h} ». On ne se baigne jamais deux fois dans le même fleuve, disait Héraclite. On n'écoute jamais deux fois ce refrain de la même façon. La deuxième fois, il est meilleur.",
        "« {h} ». Spinoza voulait comprendre plutôt que juger. J'ai compris. Je juge quand même : c'est fort.",
        "« {h} ». Je pense, donc je suis, disait Descartes. Toi : je rime, donc je suis. C'est moins célèbre, mais ça tient.",
        "« {h} ». Diogène vivait dans un tonneau et disait leurs quatre vérités aux puissants. C'est exactement ce que fait cette ligne. Sans le tonneau.",
        "« {h} ». Le cœur a ses raisons que la raison ne connaît point, disait Pascal. Cette rime a ses raisons que le flow ne connaît point.",
        "« {h} ». Montaigne se prenait lui-même comme sujet d'étude. Toi aussi. On appelle ça un egotrip, mais avec une bibliographie.",
        "« {h} ». Épicure cherchait l'absence de trouble. Cette punchline cherche le trouble. Elle le trouve.",
        "« {h} ». Ibn Khaldoun voyait les dynasties monter puis tomber en quelques générations. Ce refrain, c'est le début d'une dynastie. Reste à savoir combien de générations.",
        "« {h} ». L'existence précède l'essence, disait Sartre. Ton refrain existe. Son essence, on la cherchera ensemble sur @goslo_radio.",
    ]

    static let noRefrain = [
        "Une punchline, c'est un aphorisme qui a mis des baskets. Ramène-m'en une, je la lirai comme on lit les classiques : lentement, et en doutant de tout.",
        "Écris un refrain, au Punchliner ou ailleurs. Je l'analyserai pour goslo radio. Avec ta permission. Ou sans.",
    ]

    static let signOff = [
        "Je publie l'analyse sur @goslo_radio ce soir. Tu seras cité. Entre Platon et un rappeur de 2004.",
        "Tu repasses quand tu as une nouvelle punchline. La philosophie n'attend pas. Enfin si, elle attend beaucoup, mais pas moi.",
    ]

    /// Which thinker reads this refrain (always the same one for the same words).
    static func reading(of hook: String) -> String {
        let index = hook.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff } % readings.count
        return readings[index].replacingOccurrences(of: "{h}", with: hook)
    }
}

extension GameEngine {
    /// Talking to the philosopher: his reading of your newest refrain not yet analysed (pen XP the first time),
    /// or of your latest one again, or an invitation to write one.
    func philosopherReading(in state: inout GameState) -> [String] {
        guard !state.hooks.isEmpty else { return [Philosopher.noRefrain[state.flags.count % Philosopher.noRefrain.count]] }
        let fresh = state.hooks.indices.last { !state.flags.contains(Philosopher.readFlag($0)) }
        let index = fresh ?? state.hooks.count - 1
        var lines = [Philosopher.reading(of: state.hooks[index])]
        if fresh != nil {
            state.flags.insert(Philosopher.readFlag(index))
            state.skills.gain([.plume: Philosopher.readingXP])
            lines.append(Philosopher.signOff[index % Philosopher.signOff.count])
        } else {
            lines.append("Celle-là, je l'ai déjà disséquée. Écris-en une nouvelle, je t'attends sur mon banc.")
        }
        return lines
    }

    /// Refrains the philosopher has read.
    func analysedRefrains(in state: GameState) -> Int {
        state.hooks.indices.filter { state.flags.contains(Philosopher.readFlag($0)) }.count
    }
}

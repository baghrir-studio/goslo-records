import Foundation

/// One rung of « Le Tournoi goslo radio » (story.json, "tournament"): a boss unlocked by the artist level
/// and by beating the previous rung. Beating it sets `tournoi_<opponent>`, which unlocks its technique.
struct TournamentBoss: Codable, Equatable, Identifiable {
    /// Cast id of the boss.
    let opponent: String
    /// Artist level needed to challenge them.
    let minArtistLevel: Int
    let levelBonus: Int
    let opponentPower: Double?
    let rounds: Int
    /// Artist XP for the win (on top of a clash's usual XP).
    let xp: Int
    /// Id of the technique (story.json "techniques") the win unlocks.
    let technique: String
    /// The DJ Noize / Animateur intro shown on the ladder.
    let intro: String
    let win: ClashResultSpec
    let lose: ClashResultSpec

    var id: String { opponent }
    /// Story flag set when the boss is beaten.
    var flag: String { GameEngine.tournamentFlag(opponent) }

    enum CodingKeys: String, CodingKey {
        case opponent, rounds, xp, technique, intro, win, lose
        case minArtistLevel = "min_artist_level"
        case levelBonus = "level_bonus"
        case opponentPower = "opponent_power"
    }

    init(opponent: String, minArtistLevel: Int, levelBonus: Int = 0, opponentPower: Double? = nil,
         rounds: Int = ClashState.maxRounds, xp: Int = 0, technique: String, intro: String = "",
         win: ClashResultSpec, lose: ClashResultSpec) {
        self.opponent = opponent
        self.minArtistLevel = minArtistLevel
        self.levelBonus = levelBonus
        self.opponentPower = opponentPower
        self.rounds = rounds
        self.xp = xp
        self.technique = technique
        self.intro = intro
        self.win = win
        self.lose = lose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        opponent = try c.decode(String.self, forKey: .opponent)
        minArtistLevel = try c.decodeIfPresent(Int.self, forKey: .minArtistLevel) ?? 1
        levelBonus = try c.decodeIfPresent(Int.self, forKey: .levelBonus) ?? 0
        opponentPower = try c.decodeIfPresent(Double.self, forKey: .opponentPower)
        rounds = max(1, try c.decodeIfPresent(Int.self, forKey: .rounds) ?? ClashState.maxRounds)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        technique = try c.decode(String.self, forKey: .technique)
        intro = try c.decodeIfPresent(String.self, forKey: .intro) ?? ""
        win = try c.decode(ClashResultSpec.self, forKey: .win)
        lose = try c.decode(ClashResultSpec.self, forKey: .lose)
    }

    /// The boss clash this rung plays (the win also sets `flag`).
    var spec: ClashSpec {
        ClashSpec(opponent: opponent,
                  win: ClashResultSpec(effects: win.effects, consequence: win.consequence, setFlags: win.setFlags + [flag]),
                  lose: lose, boss: true, rounds: rounds, levelBonus: levelBonus, opponentPower: opponentPower)
    }
}

/// Where the player stands on one rung of the ladder (for the Tournoi screen).
struct TournamentRung: Equatable, Identifiable {
    enum Status: Equatable {
        /// Not yet: `lockReason` says why.
        case locked
        case available
        case beaten
    }

    /// 1-based position on the ladder.
    let round: Int
    let boss: TournamentBoss
    let member: CastMember
    /// The technique the win unlocks.
    let technique: UnlockableTechnique?
    let status: Status
    let lockReason: String?

    var id: String { boss.id }
}

extension GameEngine {
    static let tournamentName = "Le Tournoi goslo radio"
    /// Talking to the radio host opens the Tournoi.
    static let tournamentHostId = "animateur_goslo"
    /// Set once every rung is beaten.
    static let tournamentChampionFlag = "tournoi_champion"

    static func tournamentFlag(_ opponentId: String) -> String { "tournoi_\(opponentId)" }

    /// The ladder, in order, with each rung's status.
    func tournamentBosses(in state: GameState) -> [TournamentRung] {
        let level = ArtistLevel.level(xp: state.artistXP)
        var previous: CastMember?
        var previousBeaten = true
        var rungs: [TournamentRung] = []
        for (index, boss) in story.tournament.enumerated() {
            guard let member = castMember(boss.opponent), member.clash != nil else { continue }
            let beaten = state.flags.contains(boss.flag)
            let status: TournamentRung.Status
            var reason: String?
            if beaten {
                status = .beaten
            } else if level < boss.minArtistLevel {
                status = .locked
                reason = "Niveau d'artiste \(boss.minArtistLevel) requis"
            } else if !previousBeaten {
                status = .locked
                reason = "Bats d'abord \(previous?.name ?? "le tour précédent")"
            } else {
                status = .available
            }
            rungs.append(TournamentRung(round: index + 1, boss: boss, member: member,
                                        technique: story.techniques.first { $0.id == boss.technique },
                                        status: status, lockReason: reason))
            previous = member
            previousBeaten = beaten
        }
        return rungs
    }

    /// The next boss to beat (nil once the ladder is cleared).
    func nextTournamentRung(in state: GameState) -> TournamentRung? {
        tournamentBosses(in: state).first { $0.status != .beaten }
    }

    func canStartTournament(_ opponentId: String, in state: GameState) -> Bool {
        canVisit(state) && EndingResolver.prematureEnding(for: state.stats) == nil
            && tournamentBosses(in: state).contains { $0.id == opponentId && $0.status == .available }
    }

    /// Starts a Tournoi boss clash: one action, like a story clash. `finishClash` applies the result.
    func startTournamentClash(_ opponentId: String, in state: inout GameState) throws -> ClashState {
        guard canVisit(state) else { throw GameEngineError.cannotVisit }
        guard canStartTournament(opponentId, in: state),
              let boss = story.tournament.first(where: { $0.opponent == opponentId }) else {
            throw GameEngineError.requirementNotMet
        }
        state.actionsLeft -= 1
        state.metCast.insert(opponentId)
        state.currentLocation = nil
        var clash = ClashState(spec: boss.spec)
        clash.playerMeter = startingMeter(in: state)
        clash.crowdFavorite = ClashTactics.crowdFavorite(in: state.district)
        state.clash = clash
        return clash
    }

    /// The rung a finished clash was played for, if it was a Tournoi clash.
    func tournamentBoss(for clash: ClashState) -> TournamentBoss? {
        guard clash.isBoss, clash.spec.win.setFlags.contains(GameEngine.tournamentFlag(clash.opponentId)) else { return nil }
        return story.tournament.first { $0.opponent == clash.opponentId }
    }

    /// A Tournoi win: the bonus XP, and the crown once the whole ladder is beaten.
    /// (The flag comes with the clash's `set_flags`; the technique unlocks in `finishAction`.)
    func applyTournamentWin(_ boss: TournamentBoss, _ outcome: inout TurnOutcome, in state: inout GameState) {
        ArtistLevel.gain(boss.xp, in: &state, outcome: &outcome)
        if let next = nextTournamentRung(in: state) {
            outcome.notes.append("Tournoi goslo radio : prochain adversaire, \(next.member.name) (niveau \(next.boss.minArtistLevel)).")
        } else if !story.tournament.isEmpty, !state.flags.contains(GameEngine.tournamentChampionFlag) {
            state.flags.insert(GameEngine.tournamentChampionFlag)
            outcome.notes.append("CHAMPION DU TOURNOI GOSLO RADIO ! DJ Noize passe ton son en boucle toute la nuit.")
        }
    }
}

import Foundation

#if DEBUG
/// Shortcuts for testing a chapter without replaying the whole story. Debug builds only:
/// they never ship in a TestFlight or App Store build.
extension GameEngine {
    /// Starts `number` as if every earlier chapter had just been played: their objectives done,
    /// their cinematics seen, a career far enough along to stand a chance against its bosses.
    func debugJump(toChapter number: Int, in state: inout GameState) {
        guard let target = story.chapter(number) else { return }
        for chapter in story.chapters where chapter.number < number {
            state.flags.insert("chapitre_\(chapter.number)")
            state.seenCinematics.formUnion([chapter.intro, chapter.outro].compactMap { $0 })
            for objective in chapter.objectives {
                state.flags.formUnion(objective.conditions.requiredFlags)
                for (counter, minimum) in objective.conditions.minCounters where state.counters[counter] < minimum {
                    state.counters.increment(counter, by: minimum - state.counters[counter])
                }
                if let cinematic = objective.cinematic { state.seenCinematics.insert(cinematic) }
                // Items every choice of the objective's event hands out (Fred's drill, for instance).
                if let storyEvent = objective.event.flatMap({ self.event(withId: $0) }), let first = storyEvent.choices.first {
                    let common = storyEvent.choices.dropFirst().reduce(Set(first.giveItems)) { $0.intersection($1.giveItems) }
                    state.items.formUnion(common)
                }
            }
        }
        if number > 1 && state.counters[.projets] == 0 { state.counters.increment(.projets) }

        state.chapter = number
        state.objectiveIndex = 0
        state.pendingCinematic = target.intro
        state.turn = max(state.turn, min((number - 1) * 3, GameState.totalTurns - 2))
        state.actionsLeft = GameState.actionsPerTurn
        state.ending = nil
        clearActivity(in: &state)
        state.stats = Stats(streams: max(state.stats.streams, 50), credibilite: max(state.stats.credibilite, 50),
                            argent: max(state.stats.argent, 45), mental: max(state.stats.mental, 65))
        let xp = Skills.xpPerLevel * number
        state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, max(0, xp - state.skills.xp($0))) }))
    }

    /// Last action of semester 20: the next one shows the overtime (or the survival ending).
    func debugLastSemester(in state: inout GameState) {
        state.turn = GameState.totalTurns - 1
        state.actionsLeft = 1
        state.ending = nil
        clearActivity(in: &state)
    }

    /// Comfortable stats and max skills, to walk through a boss.
    func debugMaxOut(in state: inout GameState) {
        state.stats = Stats(streams: 80, credibilite: 80, argent: 80, mental: 80)
        state.skills.gain(Dictionary(uniqueKeysWithValues: Skill.allCases.map {
            ($0, max(0, Skills.xpPerLevel * (Skills.maxLevel - 1) - state.skills.xp($0)))
        }))
    }

    private func clearActivity(in state: inout GameState) {
        state.currentEventId = nil
        state.currentLocation = nil
        state.pendingFollowUp = nil
        state.clash = nil
        state.interview = nil
        state.concert = nil
        state.negotiation = nil
        state.writing = nil
        state.position = nil
        state.challengedThisSemester = []
    }
}
#endif

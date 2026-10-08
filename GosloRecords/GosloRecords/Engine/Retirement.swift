import Foundation

/// Free career: no clock ends it. A defeat can, or the player hangs up the mic whenever they like.
extension GameEngine {
    /// After year 10, staying on top gets harder: the public forgets you a little faster every two years.
    static func agingUpkeep(turn: Int) -> [StatKind: Int] {
        let extra = max(0, turn - GameState.totalTurns) / 4 + (turn >= GameState.totalTurns ? 1 : 0)
        return extra > 0 ? [.streams: -min(extra, 6)] : [:]
    }

    /// The player can hang up the mic: nothing in progress (no card, clash or session waiting).
    func canRetire(_ state: GameState) -> Bool {
        !state.isOver && state.currentEventId == nil && state.clash == nil && state.interview == nil
            && state.concert == nil && state.negotiation == nil && state.writing == nil && state.minigame == nil
            && state.pendingFollowUp == nil
    }

    /// Ends the career now, on the ending the stats and the story give.
    func retire(in state: inout GameState) throws {
        guard canRetire(state) else { throw GameEngineError.cannotVisit }
        state.finaleChoicePending = false
        state.ending = EndingResolver.finalEnding(for: state)
    }

    /// After the finale: the career goes on, the new generation wants your crown.
    func keepGoing(in state: inout GameState) {
        state.finaleChoicePending = false
        state.flags.insert(GameEngine.freeCareerFlag)
    }

    static let freeCareerFlag = "carriere_libre"
}

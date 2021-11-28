from abc import ABC, abstractmethod
from collections import defaultdict


class HeartsAgent(ABC):
    NUM_AGENTS = 4

    """
    @param agent_id
    @param cards a list of `Card52` corresponding to the cards in the hand of this agent.
    """
    @abstractmethod
    def __init__(self, agent_id, cards):
        pass

    """
    @returns action agent would take.
    """
    @abstractmethod
    def getNextAction(self):
        pass

    """
    @description called when any agent takes an action (including this one).
    """
    @abstractmethod
    def observeActionTaken(self, agent_id, card):
        pass


class SimpleHeartsAgent(HeartsAgent):
    def __init__(self, agent_id, cards):
        self.agent_id = agent_id
        self.inPlay = []
        self.cardMap = defaultdict(list)
        for card in cards:
            self.cardMap[card.suit].append(card)

    def getNextAction(self):
        # if there's a leading suit, play the last card (for efficiency) with the same suit as the leading suit.
        if len(self.inPlay) > 0:
            leading_suit = self.inPlay[0].suit
            if len(self.cardMap[leading_suit]) > 0:
                return self.cardMap[leading_suit][-1]
        # choose any remaining card
        for _, cards in self.cardMap.items():
            if len(cards) > 0:
                return cards[-1]
        raise RuntimeError(
            f"Agent {self.agent_id} does not have any remaining cards to play.")

    def observeActionTaken(self, agent_id, card):
        if self.agent_id == agent_id:
            # since this agent's action should be the last element from this list, this should be a constant operation.
            self.cardMap[card.suit].remove(card)
        self.inPlay.append(card)
        if len(self.inPlay) == self.NUM_AGENTS:
            self.inPlay.clear()

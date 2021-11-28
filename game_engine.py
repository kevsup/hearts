from card import Card52
from agent import SimpleHeartsAgent

import random


class HeartsEngine:
    NUM_AGENTS = 4
    QUEEN_OF_SPADES = Card52(Card52.Suit.SPADES, 11)
    CARDS_PER_AGENT = 52 // NUM_AGENTS

    def __init__(self):
        self.agents_points = [0 for _ in range(self.NUM_AGENTS)]

    def deal(self):
        cards = [Card52.createFromCardIdx(i) for i in range(52)]
        random.shuffle(cards)
        assert len(cards) % self.NUM_AGENTS == 0
        self.agents = [SimpleHeartsAgent(i,
                                         cards[i * self.CARDS_PER_AGENT:(i + 1) * self.CARDS_PER_AGENT]) for i in range(self.NUM_AGENTS)]

    """
    @returns winner agent_id of trick
    """

    def trick(self, start_agent_id):
        in_trick = []  # (agent_id, Card52)
        for offset in range(self.NUM_AGENTS):
            curr_agent_id = (start_agent_id + offset) % self.NUM_AGENTS
            agent = self.agents[curr_agent_id]
            card = agent.getNextAction()
            in_trick.append((curr_agent_id, card))
            # notify all agents of a move
            for notified_agent in self.agents:
                notified_agent.observeActionTaken(agent.agent_id, card)
        # update points based on winner of trick (ignores the rule reset rule when player takes all 13 hearts and the queen of spades, for sake of reduced complexity)
        winner_agent_id = self._determine_trick_winner(in_trick)
        self.agents_points[winner_agent_id] += sum(
            card.suit == Card52.Suit.HEARTS for _, card in in_trick)
        if self.QUEEN_OF_SPADES in map(lambda ac: ac[1], in_trick):
            self.agents_points[winner_agent_id] += 13
        return winner_agent_id

    def play(self, win_points):
        start_agent_id = 0
        while True:
            self.deal()
            num_tricks_per_round = 52 // self.NUM_AGENTS
            for _ in range(num_tricks_per_round):
                start_agent_id = self.trick(start_agent_id)
                if any(map(lambda points: points >= win_points, self.agents_points)):
                    points, winner_agent_id = sorted(
                        [(points, i) for i, points in enumerate(self.agents_points)])[0]
                    print(
                        f"Winner: {winner_agent_id} with {points} points!")
                    return

    @staticmethod
    def _determine_trick_winner(in_trick):
        leading_suit = in_trick[0][1].suit
        _, winner_agent_id = sorted(map(lambda agent_id_card: (
            agent_id_card[1].num if agent_id_card[1].suit == leading_suit else float("inf"), agent_id_card[0]), in_trick))[0]
        return winner_agent_id

if __name__ == '__main__':
    engine = HeartsEngine()
    engine.play(50)

from abc import ABC, abstractmethod
from enum import Enum


class Card:
    NUM_CARDS = 52
    NUM_CARDS_PER_SUIT = 13

    assert NUM_CARDS % NUM_CARDS_PER_SUIT == 0

    class Suit(Enum):
        DIAMONDS = 0
        CLUBS = 1
        SPADES = 2
        HEARTS = 3

        @classmethod
        def getSuitShortStr(cls, suit):
            if suit == cls.SPADES:
                return "S"
            elif suit == cls.HEARTS:
                return "H"
            elif suit == cls.CLUBS:
                return "C"
            elif suit == cls.DIAMONDS:
                return "D"
            raise Exception(f"Unexpected suit {suit}")

        @classmethod
        def getShortStrSuit(cls, suit_str):
            if suit_str == "S":
                return cls.SPADES
            elif suit_str == "H":
                return cls.HEARTS
            elif suit_str == "C":
                return cls.CLUBS
            elif suit_str == "D":
                return cls.DIAMONDS
            raise Exception(f"Unexpected suit_str {suit_str}")

    def __init__(self, suit, num):
        assert type(suit) is self.Suit
        assert num >= 2 and num <= (self.NUM_CARDS_PER_SUIT + 1)
        self.suit = suit
        self.num = num

    def __eq__(self, other):
        return (self.suit, self.num) == (other.suit, other.num)

    def __hash__(self):
        return (self.suit, self.num).__hash__()

    def __str__(self):
        return f"Card({(self.suit, self.num)})"

    """
    @param card_idx: an idx within [0, NUM_CARDS) corresponding to the idx'th card
    @returns Card6 instance
    """
    @classmethod
    def createFromCardIdx(cls, card_idx):
        assert card_idx >= 0 and card_idx < cls.NUM_CARDS
        return Card(cls.Suit(card_idx // cls.NUM_CARDS_PER_SUIT), 2 + (card_idx % (cls.NUM_CARDS_PER_SUIT)))

from abc import ABC, abstractmethod
from enum import Enum


class Card52:
    NUM_CARDS_PER_SUIT = 13

    class Suit(Enum):
        SPADES = 0
        CLUBS = 1
        HEARTS = 2
        DIAMONDS = 3

    def __init__(self, suit, num):
        assert type(suit) is self.Suit
        assert num >= 1 and num <= self.NUM_CARDS_PER_SUIT
        self.suit = suit
        self.num = num

    def __eq__(self, other):
        return (self.suit, self.num) == (other.suit, other.num)

    """
    @param card_idx: an idx within [0, 51] corresponding to the idx'th card
    @returns Card52 instance
    """
    @classmethod
    def createFromCardIdx(cls, card_idx):
        assert card_idx >= 0 and card_idx < 52
        return Card52(cls.Suit(card_idx // cls.NUM_CARDS_PER_SUIT), 1 + card_idx % cls.NUM_CARDS_PER_SUIT if card_idx > 0 else cls.NUM_CARDS_PER_SUIT)

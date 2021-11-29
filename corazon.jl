using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, MCTS, BasicPOMCP, PyCall

py"""
import sys
sys.path.insert(0, ".")
"""

suits = ["S","H"]
py"""
from card import Card
def getAllCards(suits):
    return [f"{i}{suit_str}" for i in range(1, Card.NUM_CARDS_PER_SUIT + 1) for suit_str in suits]
"""
cards = py"getAllCards"(suits)
encoding_base = 4
num_agents = 2
num_states = (encoding_base ^ (2 + length(cards)))
total_rows = 2 + length(cards)

next_suit = Dict("S"=>"H", "H"=>"D")
card_status = ["seen","m1","m2","in_play"]


function state2info(s)
    base_string = string(s, base=encoding_base)
    base_string = repeat("0",total_rows - length(base_string)) * base_string
    remaining_moves = parse(Int, base_string[1])

    leading_suit = "none"
    if remaining_moves < 3
        leading_suit = suits[parse(Int, base_string[2]) + 1]
    end

    player_cards = [card_status[parse(Int, num)+1] for num in base_string[3:length(base_string)]]
    return remaining_moves, leading_suit, player_cards
end

function info2state(remaining_moves, leading_suit, player_cards)
    base_string = string(remaining_moves)
    if remaining_moves == 1
        base_string *= "0"
    else
        base_string *= string(findfirst(isequal(leading_suit), suits) - 1)
    end
    
    card_string = join([string(findfirst(isequal(card), card_status) - 1) for card in player_cards])
    s = parse(Int64, base_string * card_string, base=encoding_base)
    return s
end

function dummyMoves(s, a)
    rm, ls, pc = state2info(s)
    res = []
    for i = 1:rm
        m2_cards = cards[pc.=="m2"]
        curr_suit = ls == "none" ? string(a[length(a)]) : ls
        while true
            lowest_num = 4
            for ii = 1:length(m2_cards)
                if string(m2_cards[ii][length(m2_cards[ii])]) == curr_suit && !(m2_cards[ii] in res)
                    curr_num = parse(Int, m2_cards[ii][1:length(m2_cards[ii])-1])
                    if curr_num < lowest_num
                        lowest_num = curr_num
                    end
                end
            end
            if lowest_num < 4
                card = string(lowest_num) * curr_suit
                push!(res, card)
                break
            else
                curr_suit = next_suit[string(curr_suit)]
            end
        end
    end
    return res
end

states = Array((1:num_states))

function getNextAction(remaining_moves, leading_suit, player_cards)
    state = info2state(remaining_moves, leading_suit, player_cards)
    m = QuickMDP(
        states = states,
        actions = cards,
        initialstate = state, # placeholder
        discount = 0.95,

        transition = function (s, a)
            # placeholder
            return Uniform(states)
        end,

        reward = function (s, a)
            # if end up with heart, return -1
            # if end up with Queen spades, return -13
            # else return 0
            return 3.14
        end
    )
    solver = DPWSolver(depth=1)
    policy = solve(solver, m)
    a = action(policy, state)
    println("a: $a")
    return a
end

seen = []

function observeActionTaken(action)
    global seen
    push!(seen, action)
    if size(seen) == size(cards)
        seen = []
    end
    println("After observeActionTaken seen set to: $seen")
end

py"""
from game_engine import HeartsEngine
from agent import MDPHeartsAgent

def runGame(seen, getNextAction, observeActionTaken):
    def customAgentGenFn(agent_id, cards):
        return MDPHeartsAgent(agent_id, cards, seen, getNextAction, observeActionTaken)
    engine = HeartsEngine.createWithOneCustomAgent(customAgentGenFn)
    engine.play(5)
"""

py"runGame"(seen, getNextAction, observeActionTaken)
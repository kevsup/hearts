using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, MCTS, BasicPOMCP, DiscreteValueIteration, PyCall

py"""
import sys
sys.path.insert(0, ".")
"""

################ CONSTANTS ############################

SUITS = ["D","C","S","H"]

CARDS = []
for suit in SUITS
    for num = 2:14
        # 2 through Ace
        push!(CARDS, string(num) * suit)
    end
end
CARDS = convert(Vector{String}, CARDS)

TOTAL_ROWS = 2 + length(CARDS)

LOOKAHEAD_DEPTH = 2

ENCODING_BASE = 4

NEXT_SUIT = Dict("D"=>"C", "C"=>"S", "S"=>"H", "H"=>"D")

CARD_STATUS = ["seen","m1","m2","in_play"]

MAX_DEDUCTION = 1e5

################ HELPER FUNCTIONS ############################

function state2info(s)
    base_string = s
    base_string = repeat("0",TOTAL_ROWS - length(base_string)) * base_string
    remaining_moves = parse(Int, base_string[1])

    leading_suit = "none"
    if remaining_moves < ENCODING_BASE - 1
        leading_suit = SUITS[parse(Int, base_string[2]) + 1]
    end

    player_cards = [CARD_STATUS[parse(Int, num)+1] for num in base_string[3:length(base_string)]]
    return remaining_moves, leading_suit, player_cards
end

function info2state(remaining_moves, leading_suit, player_cards)
    base_string = string(remaining_moves)
    if remaining_moves == 3
        base_string *= "0"
    else
        base_string *= string(findfirst(isequal(leading_suit), SUITS) - 1)
    end
    
    card_string = join([string(findfirst(isequal(card), CARD_STATUS) - 1) for card in player_cards])

    return base_string * card_string
end

function getValSuit(card)
    value = parse(Int, card[1:length(card)-1])
    suit = string(card[length(card)])
    return value, suit
end

function dummyMoves(s, a)
    rm, ls, pc = state2info(s)
    res = []
    for i = 1:rm
        m2_cards = CARDS[pc.=="m2"]
        if length(m2_cards) == 0
            continue
        end
        curr_suit = ls == "none" ? string(a[length(a)]) : ls
        while true
            lowest_num = 15
            for ii = 1:length(m2_cards)
                card = m2_cards[ii]
                val, suit = getValSuit(card)

                if suit == curr_suit && !(card in res)
                    if val < lowest_num
                        lowest_num = val 
                    end
                end
            end
            if lowest_num < 15
                card = string(lowest_num) * curr_suit
                push!(res, card)
                break
            else
                curr_suit = NEXT_SUIT[string(curr_suit)]
            end
        end
    end
    return res
end

function transition_string(s, a)
    rm, ls, pc = state2info(s)
    if ls == "none"
        val, suit = getValSuit(a)
        ls = suit
    end

    opponent_moves = dummyMoves(s, a)
    in_play = vcat(CARDS[pc.=="in_play"],a,opponent_moves)
    
    next_pc = pc
    for i = 1:length(next_pc)
        if CARDS[i] in in_play
            next_pc[i] = "seen"
        end
    end

    max_val = 0
    max_card = ""
    for i = 1:length(in_play)
        card = in_play[i]
        val, suit = getValSuit(card)
        if suit == ls && val > max_val
            max_val = val
            max_card = card
        end
    end

    leading_player = findfirst(isequal(max_card), in_play)
    our_agent = findfirst(isequal(a), in_play)
    if leading_player <= our_agent
        leading_player += ENCODING_BASE
    end

    next_rm = leading_player - our_agent - 1
    counter = 0
    for pc in next_pc
        if pc == "seen"
            counter += 1
        end
    end
    if next_rm < ENCODING_BASE - 1 && counter < length(next_pc)
        num_prelim_moves = ENCODING_BASE - next_rm - 1
        m2_cards = CARDS[next_pc.=="m2"]
        first_card = m2_cards[1]
        val, next_ls = getValSuit(first_card)
        next_pc[findfirst(isequal(first_card),CARDS)] = "in_play"
        temp_state = info2state(num_prelim_moves - 1, next_ls, next_pc)
        prelim_moves = vcat(first_card,dummyMoves(temp_state, first_card))

        for i = 1:length(CARDS)
            if CARDS[i] in prelim_moves
                next_pc[i] = "in_play"
            end
        end
    else
        next_ls = SUITS[1]
    end

    sp = info2state(next_rm, next_ls, next_pc)

    #println("next state = ", sp)

    return sp
end

function transition(s, a)
    rm, ls, pc = state2info(s)
    if ls == "none"
        val, suit = getValSuit(a)
        ls = suit
    end

    actionSuits = Set()
    for a in CARDS[pc.=="m1"]
        val, suit = getValSuit(a)
        push!(actionSuits, suit)
    end
    
    val, suit = getValSuit(a)
    if (suit != ls && (ls in actionSuits)) || (a in CARDS[pc.=="seen"])
        #println("illegal move = ", a)
        return Deterministic(s)
    end

    sp = transition_string(s, a)
    return Deterministic(sp)
end

function getStatesSet!(curr_state, states_set, actions, lookahead)
    if length(actions) == 0 || lookahead == 0
        return
    end
    rm, ls, pc = state2info(curr_state)
    actionSuits = Set()
    for a in actions
        val, suit = getValSuit(a)
        push!(actionSuits, suit)
    end
    
    for i = 1:length(actions)
        val, suit = getValSuit(actions[i])
        if suit == ls || !(ls in actionSuits)
            next_state = transition_string(curr_state, actions[i])
            if !in(next_state, states_set)
                push!(states_set, next_state)
            end
            getStatesSet!(next_state, states_set, deleteat!(copy(actions), i), lookahead - 1)
        end
    end
end

update_reward = function(card)
    r = 0
    if string(card) == "12S"
        r = -13
    end
    val, suit = getValSuit(card)
    if suit == "H"
        r = -1
    end
    return r
end

function reward(s,a)
    r = 0
    rm, ls, pc = state2info(s)
    if ls == "none"
        ls = string(a[length(a)])
    end

    # Give max deduction if agent plays card not in its hand.
    m1_cards = CARDS[pc.=="m1"]
    if !(a in m1_cards)
        return -MAX_DEDUCTION
    end

    # Give max deduction if agent has leading suit card but doesn't play it.
    has_ls = false
    for card in m1_cards
        _, suit = getValSuit(card)
        if suit == ls
            has_ls = true
            break
        end
    end
    _, a_suit = getValSuit(a)
    if has_ls && !(a_suit == ls)
        return -MAX_DEDUCTION
    end 
    
    # Determine if the highest card is played by our agent.
    opponent_moves = dummyMoves(s, a)
    in_play = vcat(CARDS[pc.=="in_play"],a,opponent_moves)
    highest_card = ""
    highest_val = 0
    for card in in_play
        val, suit = getValSuit(card)
        if val > highest_val && suit == ls
            highest_val = val
            highest_card = card
        end
    end

    if highest_card == a
        for card in in_play
            r += update_reward(card)
        end
    end

    return r
end

################ END OF HELPER FUNCTIONS ############################

# queen of spades in play
#INITIAL_STATE = "220000000000110000000000002210000002223122222222222211"
INITIAL_STATE = "222122212221221221212221222122222222213122212221222122"

#=
# verify decoder
rm, ls, pc = state2info(INITIAL_STATE)
pc_str = join(pc,",")
println("remaining_moves: $rm, leading suit: $ls, player cards: $pc_str")

# verify encoder
state = info2state(rm, ls, pc)
println("state: $state")

ACTIONS = CARDS[pc.=="m1"]
STATES_SET = Set([INITIAL_STATE])

println("states set size: ", length(STATES_SET))
println("actions: $ACTIONS")
println("in play: ", CARDS[pc.=="in_play"])
=#

function getNextAction(remaining_moves, leading_suit, player_cards)
    # println("$remaining_moves $leading_suit $player_cards")
    state = info2state(remaining_moves, leading_suit, player_cards)
    states_set = Set([state])
    actions = CARDS[player_cards.=="m1"]
    getStatesSet!(state, states_set, actions, LOOKAHEAD_DEPTH)
    m = QuickMDP(
        states = states_set,
        actions = actions,
        initialstate = state,
        discount = 1.0,
        transition = transition,
        reward = reward,
        isterminal = s -> (function (s)
            rm, ls, pc = state2info(s)
            new_actions = CARDS[pc.=="m1"]
            return (length(actions) - length(new_actions) >= LOOKAHEAD_DEPTH)
        end)(s)
    )
    # note: MCTS and DPW seem to struggle with getting stuck in branches
    #       e.g. with a Queen of Spades in play, the MCTS will choose to play the King of Spades smh
    # surprisingly, our state space is not too large to use value iteration, which plays reasonably
    solver = ValueIterationSolver(max_iterations=100)
    policy = solve(solver, m)
    a = action(policy, state)
    println("a: $a")
    return a
end

seen = []

function observeActionTaken(action)
    global seen
    push!(seen, action)
    if size(seen) == size(CARDS)
        seen = []
    end
    # println("After observeActionTaken seen set to: $seen")
end

py"""
from game_engine import HeartsEngine
from agent import MDPHeartsAgent
from collections import defaultdict
def runGame(seen, getNextAction, observeActionTaken, numRuns):
    def customAgentGenFn(agent_id, cards):
        return MDPHeartsAgent(agent_id, cards, seen, getNextAction, observeActionTaken)
    winnerCount = defaultdict(int)
    for i in range (numRuns):
        engine = HeartsEngine.createWithOneCustomAgent(customAgentGenFn)
        winnerAgentId, points = engine.play(50)
        winnerCount[winnerAgentId] += 1
    print(f"Winners: {winnerCount}")
"""

py"runGame"(seen, getNextAction, observeActionTaken, 5)
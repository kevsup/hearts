using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, MCTS, BasicPOMCP, DiscreteValueIteration

suits = ["D","C","S","H"]
cards = []
for suit in suits
    for num = 2:14
        # 2 through Ace
        push!(cards, string(num) * suit)
    end
end
cards = convert(Vector{String}, cards)
println("cards $cards")

lookahead_depth = 6

encoding_base = 4
num_agents = 2
total_rows = 2 + length(cards)
num_states = (encoding_base ^ total_rows)

# queen of spades in play
initial_state = "222122212221221221212221222122222222213122212221222122"

next_suit = Dict("D"=>"C", "C"=>"S", "S"=>"H", "H"=>"D")
card_status = ["seen","m1","m2","in_play"]

MAX_DEDUCTION = 1e5


function state2info(s)
    base_string = s
    base_string = repeat("0",total_rows - length(base_string)) * base_string
    remaining_moves = parse(Int, base_string[1])

    leading_suit = "none"
    if remaining_moves < 3
        leading_suit = suits[parse(Int, base_string[2]) + 1]
    end

    player_cards = [card_status[parse(Int, num)+1] for num in base_string[3:length(base_string)]]
    return remaining_moves, leading_suit, player_cards
end

# verify decoder
rm, ls, pc = state2info(initial_state)
pc_str = join(pc,",")
println("remaining_moves: $rm, leading suit: $ls, player cards: $pc_str")

function info2state(remaining_moves, leading_suit, player_cards)
    base_string = string(remaining_moves)
    if remaining_moves == 3
        base_string *= "0"
    else
        base_string *= string(findfirst(isequal(leading_suit), suits) - 1)
    end
    
    card_string = join([string(findfirst(isequal(card), card_status) - 1) for card in player_cards])

    #s = parse(Int, base_string * card_string, base=encoding_base)
    return base_string * card_string
end

# verify encoder
state = info2state(rm, ls, pc)
println("state: $state")

function getValSuit(card)
    value = parse(Int, card[1:length(card)-1])
    suit = string(card[length(card)])
    return value, suit
end

function dummyMoves(s, a)
    rm, ls, pc = state2info(s)
    res = []
    for i = 1:rm
        m2_cards = cards[pc.=="m2"]
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
                curr_suit = next_suit[string(curr_suit)]
            end
        end
    end
    return res
end

# verify dummyMoves
#println(join(dummyMoves(initial_state, "13S"), ","))

function transition_string(s, a)
    rm, ls, pc = state2info(s)
    if ls == "none"
        val, suit = getValSuit(a)
        ls = suit
    end
    opponent_moves = dummyMoves(s, a)
    #println("rm: $rm ls: $ls pc: $pc")
    #println("om: $opponent_moves")
    in_play = vcat(cards[pc.=="in_play"],a,opponent_moves)
    #println("in play: $in_play")
    
    next_pc = pc
    for i = 1:length(next_pc)
        if cards[i] in in_play
            next_pc[i] = "seen"
        end
    end

    #println("next pc: $next_pc")

    max_val = 0
    max_card = ""
    #println("ls = $ls")
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
    #println("max card: $max_card")
    #println("max val: $max_val")
    #println("leading player: $leading_player")
    #println("our agent: $our_agent")
    if leading_player <= our_agent
        leading_player += encoding_base
    end

    next_rm = leading_player - our_agent - 1

    #println("next rm: $next_rm")

    # anticipate preliminary moves if our agent does not play first
    counter = 0
    for pc in next_pc
        if pc == "seen"
            counter += 1
        end
    end
    if next_rm < encoding_base - 1 && counter < length(next_pc)
        num_prelim_moves = encoding_base - next_rm - 1
        m2_cards = cards[next_pc.=="m2"]
        #println("new m2 cards: $m2_cards")
        first_card = m2_cards[1]
        val, next_ls = getValSuit(first_card)
        next_pc[findfirst(isequal(first_card),cards)] = "in_play"
        temp_state = info2state(num_prelim_moves - 1, next_ls, next_pc)
        prelim_moves = vcat(first_card,dummyMoves(temp_state, first_card))

        for i = 1:length(cards)
            if cards[i] in prelim_moves
                next_pc[i] = "in_play"
            end
        end
    else
        next_ls = suits[1]
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
    for a in cards[pc.=="m1"]
        val, suit = getValSuit(a)
        push!(actionSuits, suit)
    end
    
    val, suit = getValSuit(a)
    if (suit != ls && (ls in actionSuits)) || (a in cards[pc.=="seen"])
        #println("illegal move = ", a)
        return Deterministic(s)
    end

    opponent_moves = dummyMoves(s, a)
    #println("rm: $rm ls: $ls pc: $pc")
    #println("om: $opponent_moves")
    in_play = vcat(cards[pc.=="in_play"],a,opponent_moves)
    #println("in play: $in_play")
    
    next_pc = pc
    for i = 1:length(next_pc)
        if cards[i] in in_play
            next_pc[i] = "seen"
        end
    end

    #println("next pc: $next_pc")

    max_val = 0
    max_card = ""
    #println("ls = $ls")
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
    #println("max card: $max_card")
    #println("max val: $max_val")
    #println("leading player: $leading_player")
    #println("our agent: $our_agent")
    if leading_player <= our_agent
        leading_player += encoding_base
    end

    next_rm = leading_player - our_agent - 1

    #println("next rm: $next_rm")

    # anticipate preliminary moves if our agent does not play first
    counter = 0
    for pc in next_pc
        if pc == "seen"
            counter += 1
        end
    end
    if next_rm < encoding_base - 1 && counter < length(next_pc)
        num_prelim_moves = encoding_base - next_rm - 1
        m2_cards = cards[next_pc.=="m2"]
        #println("new m2 cards: $m2_cards")
        first_card = m2_cards[1]
        val, next_ls = getValSuit(first_card)
        next_pc[findfirst(isequal(first_card),cards)] = "in_play"
        temp_state = info2state(num_prelim_moves - 1, next_ls, next_pc)
        prelim_moves = vcat(first_card,dummyMoves(temp_state, first_card))

        for i = 1:length(cards)
            if cards[i] in prelim_moves
                next_pc[i] = "in_play"
            end
        end
    else
        next_ls = suits[1]
    end

    sp = info2state(next_rm, next_ls, next_pc)

    #println("next state = ", sp)

    return Deterministic(sp)
end

# verify transition function
transition(initial_state, "4S")


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

actions = cards[pc.=="m1"]
states_set = Set([initial_state])
getStatesSet!(initial_state, states_set, actions, lookahead_depth)

states_array = (x->string(x)).(states_set)

println("states set size: ", length(states_set))


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
    m1_cards = cards[pc.=="m1"]
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
    in_play = vcat(cards[pc.=="in_play"],a,opponent_moves)
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

    #=
    if s == initial_state
        println("action = $a, OG state")
    else
        println("action = $a, state = $s")
    end
    println("reward = $r")
    =#

    return r
end

rm, ls, pc = state2info(initial_state)
actions = cards[pc.=="m1"]
println("actions: $actions")
println("in play: ", cards[pc.=="in_play"])

function isTerminal(s)
    rm, ls, pc = state2info(s)
    new_actions = cards[pc.=="m1"]
    return length(actions) - length(new_actions) >= lookahead_depth
end

m = QuickMDP(
    states = states_set,
    actions = actions,
    initialstate = initial_state,
    discount = 1.0,
    transition = transition,
    reward = reward,
    isterminal = s -> isTerminal(s))

# note: MCTS and DPW seem to struggle with getting stuck in branches
#       e.g. with a Queen of Spades in play, the MCTS will choose to play the King of Spades smh
# surprisingly, our state space is not too large to use value iteration, which plays reasonably

#solver = MCTSSolver(n_iterations=20, depth=lookahead_depth, exploration_constant=1.0)
#solver = DPWSolver(n_iterations=2000, depth=lookahead_depth, exploration_constant=1.0)
solver = ValueIterationSolver(max_iterations=100)
policy = solve(solver, m)

a = action(policy, initial_state)
println("a: $a")

v = value(policy, initial_state)
println("v: $v")


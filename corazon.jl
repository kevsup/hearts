using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, MCTS, BasicPOMCP

cards = ["3S","12S","13S","6H","3H","3C","4C","5C"]
encoding_base = 4
num_agents = 2
total_rows = 2 + length(cards)
num_states = (encoding_base ^ total_rows)

suits = ["D","C","S","H"]
next_suit = Dict("D"=>"C", "C"=>"S", "S"=>"H", "H"=>"D")
card_status = ["seen","m1","m2","in_play"]

MAX_DEDUCTION = 1e5


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

# verify decoder
rm, ls, pc = state2info(435626)
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

    s = parse(Int, base_string * card_string, base=encoding_base)
    return s
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
println(join(dummyMoves(959914, "13S"), ","))

function transition(s, a)
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
    if next_rm < encoding_base - 1
        num_prelim_moves = encoding_base - next_rm - 1
        m2_cards = cards[next_pc.=="m2"]
        #println("new m2 cards: $m2_cards")
        first_card = m2_cards[1]
        val, next_ls = getValSuit(first_card)
        next_pc[findfirst(isequal(first_card),cards)] = "in_play"
        temp_state = info2state(num_prelim_moves - 1, next_ls, next_pc)
        prelim_moves = vcat(first_card,dummyMoves(temp_state, first_card))

        #println("prelim moves: $prelim_moves")
        
        for i = 1:length(cards)
            if cards[i] in prelim_moves
                next_pc[i] == "in_play"
            end
        end
    else
        next_ls = "none"
    end

    sp = info2state(next_rm, next_ls, next_pc)

    println("next state: $sp")

    return Deterministic(sp)
end

transition(435626, "4S")

update_reward = function(a)
    r = 0
    if string(a[1:length(a)-1]) == "13"
        r -= 13
    end
    if string(a[length(a)]) == "H"
        r -= 1
    end
    return r
end

states = Array((1:num_states))
initial_state = 435626
rm, ls, pc = state2info(initial_state)
actions = cards[pc.=="m1"]
println("actions: $actions")

m = QuickMDP(
    states = states,
    actions = cards[pc.=="m1"],
    initialstate = initial_state,
    discount = 0.95,

    transition = transition,

    reward = function (s, a)
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
        is_highest = true
        if string(a[length(a)]) == ls
            r += update_reward(a)
            for move in opponent_moves
                if parse(Int, a[1:length(a)-1]) < parse(Int, move[1:length(move)-1])
                    is_highest = false
                    break
                end
                r += update_reward(move)
            end
        else
            is_highest = false
        end
    
        if !is_highest
            r = 0
        end
        return r
    end
)

#solver = MCTSSolver(n_iterations=10000, depth=20, exploration_constant=5.0)
solver = DPWSolver(depth=1)
policy = solve(solver, m)

a = action(policy, initial_state)
println("a: $a")

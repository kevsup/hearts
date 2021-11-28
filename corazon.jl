using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, MCTS

cards = ["3S","12S","13S","6H","3H"]
encoding_base = 4
num_agents = 2
num_states = (encoding_base ^ (3 + length(cards))) * 2
total_rows = 2 + length(cards)
our_cards = ["6H", "KS"]

suits = ["D","C","S","H"]
next_suit = Dict("D"=>"C", "C"=>"S", "S"=>"H", "H"=>"D")
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

# verify decoder
rm, ls, pc = state2info(14998)
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

function dummyMoves(s, a)
    rm, ls, pc = state2info(s)
    res = []
    for i = 1:rm
        m2_cards = cards[pc.=="m2"]
        curr_suit = ls == "none" ? a[length(a)] : ls
        while true
            lowest_num = 15
            for ii = 1:length(m2_cards)
                if m2_cards[ii][length(m2_cards[ii])] == curr_suit && !(m2_cards[ii] in res)
                    curr_num = parse(Int, m2_cards[ii][1:length(m2_cards[ii])-1])
                    if curr_num < lowest_num
                        lowest_num = curr_num
                    end
                end
            end
            if lowest_num < 15
                card = string(lowest_num) * curr_suit
                append!(res, card)
                break
            else
                curr_suit = next_suit[curr_suit]
            end
        end
        append!(res, )
    end
    return res
end

println(join(dummyMoves(14998, "13S"), ","))

m = QuickMDP(
    states = Array((1:num_states)),
    actions = our_cards,
    initialstate = 238, # placeholder
    discount = 0.95,

    transition = function (s, a)
        # placeholder
        return initialstate
    end,

    reward = function (s, a)
        # if end up with heart, return -1
        # if end up with Queen spades, return -13
        # else return 0
        return 3.14
    end
)

solver = MCTSSolver(n_iterations=50, depth=20, exploration_constant=5.0)
policy = solve(solver, m)

a = action(policy, "left")
println("a: $a")


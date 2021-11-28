using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP

cards = ["3S","QS","KS","6H","3H"]
encoding_base = 5
num_agents = 4
num_states = (encoding_base ^ (1 + length(cards))) * num_agents
our_cards = ["6H", "KS"]

suits = ["none","D","C","S","H"]
card_status = ["seen",1,2,3,"in_play"]


function state2info(s)
    base_string = string(s, base=encoding_base)
    leading_player = parse(Int, base_string[1]) + 1
    leading_suit = suits[parse(Int,base_string[2]) + 1]
    player_cards = [card_status[parse(Int, num)+1] for num in base_string[3:length(base_string)]]
    return leading_player, leading_suit, player_cards
end

function info2state(leading_player, leading_suit, player_cards)
    base_string = [string(leading_player - 1), string(findfirst(isequal(leading_suit), suits) - 1)]
    card_string = [string(findfirst(isequal(card, card_status) - 1)) for card in player_cards]
    base_string = vcat(base_string, card_string)
    s = parse(Int, base_string, base=encoding_base)
    return s
end

function dummyMoves(s, a)

end

m = QuickPOMDP(
    states = Array((1:num_states)),
    actions = our_cards,
    observations = Array((0:1)),    # might not be needed here
    initialstate = Uniform(states), # placeholder
    discount = 0.95,

    transition = function (s, a)
        # placeholder
        return initialstate
    end,

    observation = function (s, a, sp)
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

solver = QMDPSolver()
policy = solve(solver, m)

rsum = 0.0
for (s,b,a,o,r) in stepthrough(m, policy, "s,b,a,o,r", max_steps=10)
    println("s: $s, b: $([pdf(b,s) for s in states(m)]), a: $a, o: $o")
    global rsum += r
end
println("Undiscounted reward was $rsum.")

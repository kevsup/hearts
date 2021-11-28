using POMDPs, QuickPOMDPs, POMDPModelTools, POMDPSimulators, QMDP, MCTS, StaticArrays

m = QuickMDP(
    states = ["left", "right"],
    actions = ["left", "right", "listen"],
    initialstate = "left",
    discount = 0.95,

    transition = function (s, a)
        if a == "listen"
            return Deterministic(s) # tiger stays behind the same door
        else # a door is opened
            return Uniform(["left", "right"]) # reset
        end
    end,

    reward = function (s, a)
        if a == "listen"
            return -1.0
        elseif s == a # the tiger was found
            return -100.0
        else # the tiger was escaped
            return 10.0
        end
    end
)

solver = MCTSSolver(n_iterations=50, depth=20, exploration_constant=5.0)
policy = solve(solver, m)

a = action(policy, "left")
println("a: $a")

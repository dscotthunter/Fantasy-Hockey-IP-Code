#=
This code implements the No Stacking, Type 1, Type 2, Type 3, Type 4, and Type 5 formulations
described in the paper Winning Daily Fantasy Hockey Contests Using Integer Programming by
Hunter, Vielma, and Zaman. We have made an attempt to describe the code in great detail, with the
hope that you will use your expertise to build better formulations.
=#

# To install DataFrames, simply run Pkg.add("DataFrames")
using DataFrames

#=
GLPK is an open-source solver, and additionally Cbc is an open-source solver. This code uses GLPK
because we found that it was slightly faster than Cbc in practice. For those that want to build
very sophisticated models, they can buy Gurobi. To install GLPKMathProgInterface, simply run
Pkg.add("GLPKMathProgInterface")
=#
using GLPKMathProgInterface

# Once again, to install run Pkg.add("JuMP")
using JuMP

#=
Variables for solving the problem (change these)
=#
# num_lineups is the total number of lineups
num_lineups = 100

# num_overlap is the maximum overlap of players between the lineups that you create
num_overlap = 7

# path_skaters is a string that gives the path to the csv file with the skaters information (see example file for suggested format)
path_skaters = "example_skaters.csv"

# path_goalies is a string that gives the path to the csv file with the goalies information (see example file for suggested format)
path_goalies = "example_goalies.csv"

# path_to_output is a string that gives the path to the csv file that will give the outputted results
path_to_output= "output.csv"



# This is a function that creates one lineup using the No Stacking formulation from the paper
function one_lineup_no_stacking(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for skaters in lineup.
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup.
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight Skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)

    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 2 and 3 defenders
    @addConstraint(m, 2 <= sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})
    @addConstraint(m, sum{defenders[i]*skaters_lineup[i], i=1:num_skaters} <= 3)

    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)

    # at least 3 different teams for the 8 skaters constraints
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)

    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies})


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end





# This is a function that creates one lineup using the Type 1 formulation from the paper
function one_lineup_Type_1(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for skaters in lineup
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)


    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 2 and 3 defenders
    @addConstraint(m, 2 <= sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})
    @addConstraint(m, sum{defenders[i]*skaters_lineup[i], i=1:num_skaters} <= 3)


    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)


    # At least 3 different teams for the 8 skaters constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)


    # No goalies going against skaters constraint
    @addConstraint(m, constr[i=1:num_goalies], 6*goalies_lineup[i] + sum{goalie_opponents[k, i]*skaters_lineup[k], k=1:num_skaters}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end





# This is a function that creates one lineup using the Type 2 formulation from the paper
function one_lineup_Type_2(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for skaters in lineup
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)


    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # exactly 2 defenders
    @addConstraint(m, 2 == sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})

    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)


    # at least 3 different teams for the 8 skaters constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)


    # No goalies going against skaters constraint
    @addConstraint(m, constr[i=1:num_goalies], 6*goalies_lineup[i] + sum{goalie_opponents[k, i]*skaters_lineup[k], k=1:num_skaters}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end




# This is a function that creates one lineup using the Type 3 formulation from the paper
function one_lineup_Type_3(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())


    # Variable for skaters in lineup
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight Skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)


    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 2 and 3 defenders
    @addConstraint(m, 2 <= sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})
    @addConstraint(m, sum{defenders[i]*skaters_lineup[i], i=1:num_skaters} <= 3)


    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)


    # at least 3 different teams for the 8 skaters constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)



    # No goalies going against skaters
    @addConstraint(m, constr[i=1:num_goalies], 6*goalies_lineup[i] + sum{goalie_opponents[k, i]*skaters_lineup[k], k=1:num_skaters}<=6)

    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)



    # The defenders must be on Power Play 1 constraint
    @addConstraint(m, sum{sum{defenders[i]*P1_info[i,j]*skaters_lineup[i], i=1:num_skaters}, j=1:num_teams} ==  sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)



    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end




# This is a function that creates one lineup using the Type 4 formulation from the paper
function one_lineup_Type_4(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())


    # Variable for skaters in lineup
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight Skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)

    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 2 and 3 defenders
    @addConstraint(m, 2 <= sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})
    @addConstraint(m, sum{defenders[i]*skaters_lineup[i], i=1:num_skaters} <= 3)

    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)


    # exactly 3 different teams for the 8 skaters constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} == 3)


    # No goalies going against skaters
    @addConstraint(m, constr[i=1:num_goalies], 6*goalies_lineup[i] + sum{goalie_opponents[k, i]*skaters_lineup[k], k=1:num_skaters}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)



    # The defenders must be on Power Play 1
    @addConstraint(m, sum{sum{defenders[i]*P1_info[i,j]*skaters_lineup[i], i=1:num_skaters}, j=1:num_teams} ==  sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)



    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end


# This is a function that creates one lineup using the Type 5 formulation from the paper
function one_lineup_Type_5(skaters, goalies, lineups, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for skaters in lineup
    @defVar(m, skaters_lineup[i=1:num_skaters], Bin)

    # Variable for goalie in lineup
    @defVar(m, goalies_lineup[i=1:num_goalies], Bin)


    # One goalie constraint
    @addConstraint(m, sum{goalies_lineup[i], i=1:num_goalies} == 1)

    # Eight skaters constraint
    @addConstraint(m, sum{skaters_lineup[i], i=1:num_skaters} == 8)



    # between 2 and 3 centers
    @addConstraint(m, sum{centers[i]*skaters_lineup[i], i=1:num_skaters} <= 3)
    @addConstraint(m, 2 <= sum{centers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 3 and 4 wingers
    @addConstraint(m, sum{wingers[i]*skaters_lineup[i], i=1:num_skaters} <= 4)
    @addConstraint(m, 3<=sum{wingers[i]*skaters_lineup[i], i=1:num_skaters})

    # between 2 and 3 defenders
    @addConstraint(m, 2 <= sum{defenders[i]*skaters_lineup[i], i=1:num_skaters})
    @addConstraint(m, sum{defenders[i]*skaters_lineup[i], i=1:num_skaters} <= 3)


    # Financial Constraint
    @addConstraint(m, sum{skaters[i,:Salary]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Salary]*goalies_lineup[i], i=1:num_goalies} <= 50000)


    # exactly 3 different teams for the 8 skaters constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{skaters_teams[t, i]*skaters_lineup[t], t=1:num_skaters})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} == 3)



    # No goalies going against skaters
    @addConstraint(m, constr[i=1:num_goalies], 6*goalies_lineup[i] + sum{goalie_opponents[k, i]*skaters_lineup[k], k=1:num_skaters}<=6)



    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)

    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*skaters_lineup[k], k=1:num_skaters})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*skaters_lineup[j], j=1:num_skaters} + sum{lineups[num_skaters+j,i]*goalies_lineup[j], j=1:num_goalies} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{skaters[i,:Projection]*skaters_lineup[i], i=1:num_skaters} + sum{goalies[i,:Projection]*goalies_lineup[i], i=1:num_goalies} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        skaters_lineup_copy = Array(Int64, 0)
        for i=1:num_skaters
            if getValue(skaters_lineup[i]) >= 0.9 && getValue(skaters_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_goalies
            if getValue(goalies_lineup[i]) >= 0.9 && getValue(goalies_lineup[i]) <= 1.1
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(1,1))
            else
                skaters_lineup_copy = vcat(skaters_lineup_copy, fill(0,1))
            end
        end
        return(skaters_lineup_copy)
    end
end



#=
formulation is the type of formulation that you would like to use. Feel free to customize the formulations. In our paper we considered
the Type 4 formulation in great detail, but we have included the code for all of the formulations dicussed in the paper here. For instance,
if you would like to create lineups without stacking, change one_lineup_Type_4 below to one_lineup_no_stacking
=#
formulation = one_lineup_Type_4








function create_lineups(num_lineups, num_overlap, path_skaters, path_goalies, formulation, path_to_output)
    #=
    num_lineups is an integer that is the number of lineups
    num_overlap is an integer that gives the overlap between each lineup
    path_skaters is a string that gives the path to the skaters csv file
    path_goalies is a string that gives the path to the goalies csv file
    formulation is the type of formulation you would like to use (for instance one_lineup_Type_1, one_lineup_Type_2, etc.)
    path_to_output is a string where the final csv file with your lineups will be
    =#


    # Load information for skaters table
    skaters = readtable(path_skaters)

    # Load information for goalies table
    goalies = readtable(path_goalies)

    # Number of skaters
    num_skaters = size(skaters)[1]

    # Number of goalies
    num_goalies = size(goalies)[1]

    # wingers stores the information on which players are wings
    wingers = Array(Int64, 0)

    # centers stores the information on which players are centers
    centers = Array(Int64, 0)

    # defenders stores the information on which players are defenders
    defenders = Array(Int64, 0)

    #=
    Process the position information in the skaters file to populate the wingers,
    centers, and defenders with the corresponding correct information
    =#
    for i =1:num_skaters
        if skaters[i,:Position] == "LW" || skaters[i,:Position] == "RW" || skaters[i,:Position] == "W"
            wingers=vcat(wingers,fill(1,1))
            centers=vcat(centers,fill(0,1))
            defenders=vcat(defenders,fill(0,1))
        elseif skaters[i,:Position] == "C"
            wingers=vcat(wingers,fill(0,1))
            centers=vcat(centers,fill(1,1))
            defenders=vcat(defenders,fill(0,1))
        elseif skaters[i,:Position] == "D" || skaters[i,:Position] == "LD" || skaters[i,:Position] == "RD"
            wingers=vcat(wingers,fill(0,1))
            centers=vcat(centers,fill(0,1))
            defenders=vcat(defenders,fill(1,1))
        else
            wingers=vcat(wingers,fill(0,1))
            centers=vcat(centers,fill(0,1))
            defenders=vcat(defenders,fill(1,1))
        end
    end


    # A forward is either a center or a winger
    forwards = centers+wingers



    # Create team indicators from the information in the skaters file
    teams = unique(skaters[:Team])

    # Total number of teams
    num_teams = size(teams)[1]

    # player_info stores information on which team each player is on
    player_info = zeros(Int, size(teams)[1])

    # Populate player_info with the corresponding information
    for j=1:size(teams)[1]
        if skaters[1, :Team] == teams[j]
            player_info[j] =1
        end
    end
    skaters_teams = player_info'


    for i=2:num_skaters
        player_info = zeros(Int, size(teams)[1])
        for j=1:size(teams)[1]
            if skaters[i, :Team] == teams[j]
                player_info[j] =1
            end
        end
        skaters_teams = vcat(skaters_teams, player_info')
    end



    # Create goalie identifiers so you know who they are playing
    opponents = goalies[:Opponent]
    goalie_teams = goalies[:Team]
    goalie_opponents=[]
    for num = 1:size(teams)[1]
        if opponents[1] == teams[num]
            goalie_opponents = skaters_teams[:, num]
        end
    end
    for num = 2:size(opponents)[1]
        for num_2 = 1:size(teams)[1]
            if opponents[num] == teams[num_2]
                goalie_opponents = hcat(goalie_opponents, skaters_teams[:,num_2])
            end
        end
    end




    # Create line indicators so you know which players are on which lines
    L1_info = zeros(Int, num_skaters)
    L2_info = zeros(Int, num_skaters)
    L3_info = zeros(Int, num_skaters)
    L4_info = zeros(Int, num_skaters)
    for num=1:size(skaters)[1]
        if skaters[:Team][num] == teams[1]
            if skaters[:Line][num] == "1"
                L1_info[num] = 1
            elseif skaters[:Line][num] == "2"
                L2_info[num] = 1
            elseif skaters[:Line][num] == "3"
                L3_info[num] = 1
            elseif skaters[:Line][num] == "4"
                L4_info[num] = 1
            end
        end
    end
    team_lines = hcat(L1_info, L2_info, L3_info, L4_info)


    for num2 = 2:size(teams)[1]
        L1_info = zeros(Int, num_skaters)
        L2_info = zeros(Int, num_skaters)
        L3_info = zeros(Int, num_skaters)
        L4_info = zeros(Int, num_skaters)
        for num=1:size(skaters)[1]
            if skaters[:Team][num] == teams[num2]
                if skaters[:Line][num] == "1"
                    L1_info[num] = 1
                elseif skaters[:Line][num] == "2"
                    L2_info[num] = 1
                elseif skaters[:Line][num] == "3"
                    L3_info[num] = 1
                elseif skaters[:Line][num] == "4"
                    L4_info[num] = 1
                end
            end
        end
        team_lines = hcat(team_lines, L1_info, L2_info, L3_info, L4_info)
    end
    num_lines = size(team_lines)[2]




    # Create power play indicators
    PP_info = zeros(Int, num_skaters)
    for num=1:size(skaters)[1]
        if skaters[:Team][num]==teams[1]
            if skaters[:Power_Play][num] == "1"
                PP_info[num] = 1
            end
        end
    end

    P1_info = PP_info

    for num2=2:size(teams)[1]
        PP_info = zeros(Int, num_skaters)
        for num=1:size(skaters)[1]
            if skaters[:Team][num] == teams[num2]
                if skaters[:Power_Play][num] == "1"
                    PP_info[num]=1
                end
            end
        end
        P1_info = hcat(P1_info, PP_info)
    end


    # Lineups using formulation as the stacking type
    the_lineup= formulation(skaters, goalies, hcat(zeros(Int, num_skaters + num_goalies), zeros(Int, num_skaters + num_goalies)), num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    the_lineup2 = formulation(skaters, goalies, hcat(the_lineup, zeros(Int, num_skaters + num_goalies)), num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
    tracer = hcat(the_lineup, the_lineup2)
    for i=1:(num_lineups-2)
        try
            thelineup=formulation(skaters, goalies, tracer, num_overlap, num_skaters, num_goalies, centers, wingers, defenders, num_teams, skaters_teams, goalie_opponents, team_lines, num_lines, P1_info)
            tracer = hcat(tracer,thelineup)
        catch
            break
        end
    end


    # Create the output csv file
    lineup2 = ""
    for j = 1:size(tracer)[2]
        lineup = ["" "" "" "" "" "" "" "" ""]
        for i =1:num_skaters
            if tracer[i,j] == 1
                if centers[i]==1
                    if lineup[1]==""
                        lineup[1] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[2]==""
                        lineup[2] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[9] ==""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                elseif wingers[i] == 1
                    if lineup[3] == ""
                        lineup[3] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[4] == ""
                        lineup[4] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[5] == ""
                        lineup[5] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                elseif defenders[i]==1
                    if lineup[6] == ""
                        lineup[6] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[7] ==""
                        lineup[7] = string(skaters[i,1], " ", skaters[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                end
            end
        end
        for i =1:num_goalies
            if tracer[num_skaters+i,j] == 1
                lineup[8] = string(goalies[i,1], " ", goalies[i,2])
            end
        end
        for name in lineup
            lineup2 = string(lineup2, name, ",")
        end
        lineup2 = chop(lineup2)
        lineup2 = string(lineup2, """

        """)
    end
    outfile = open(path_to_output, "w")
    write(outfile, lineup2)
    close(outfile)
end




# Running the code
create_lineups(num_lineups, num_overlap, path_skaters, path_goalies, formulation, path_to_output)

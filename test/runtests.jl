using MySudoku
using Test

for puzzle in puzzles
    sol, success = solve(puzzle)
    for r in eachrow(sol)
        println(r)
    end
    @test success
end
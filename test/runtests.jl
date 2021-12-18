using SudokuHuman
using Test

for puzzle in puzzles
    sol = solve(puzzle)
    @test check(sol)
end
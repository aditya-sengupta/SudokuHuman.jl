module MySudoku
    using StaticArrays
    using LinearAlgebra
    import Base.show, Base.eachrow, Base.eachcol, Base.copy

    struct Sudoku
        grid::MMatrix{9,9,Int64}
    end

    include("puzzles.jl")

    export puzzles, Sudoku, make_puzzles
    export check, possibilities, update, solve, print

    topleft(i) = 3 * ((i - 1) ÷ 3) + 1

    function Base.show(io::IO, s::Sudoku)
        println("   -----    -----    -----")
        for (i, r) in enumerate(eachrow(s.grid))
            Base.print(" | ")
            for (j, v) in enumerate(r)
                Base.print((v > 0 ? string(v) : "-") * " ")
                if j % 3 == 0
                    Base.print(" | ")
                end
            end
            println()
            if i % 3 == 0
                println("   -----    -----    -----")
            end
        end
    end

    Base.eachrow(s::Sudoku) = Base.eachrow(s.grid)
    Base.eachcol(s::Sudoku) = Base.eachcol(s.grid)
    eachblock(m::AbstractMatrix) = (vec(m[x...]) for x in (((3 * (i ÷ 3) + 1):(3 * (i ÷ 3) + 3), (3 * (i % 3) + 1):(3 * (i % 3) + 3)) for i in 0:8))
    eachblock(s::Sudoku) = eachblock(s.grid)
    Base.copy(s::Sudoku) = Sudoku(copy(s.grid))

    function check(block, type; verbose=true)
        if length(Set(block)) < 9
            if verbose
                println("Found $(type) without all of 1-9.")
            end
            return false
        end
        return true
    end

    function check(s::Sudoku; verbose=true)
        solved = true

        for row in eachrow(s.grid)
            solved = solved && check(row, "row"; verbose=verbose)
        end

        for col in eachrow(s.grid)
            solved = solved && check(col, "col"; verbose=verbose)
        end

        for i in [1, 4, 7]
            for j in [1, 4, 7]
                square = s.grid[i:i+2, j:j+2]
                solved = solved && check(square, "square"; verbose=verbose)
            end
        end

        solved
    end

    function possibilities(s::Sudoku, i, j)
        if s.grid[i,j] != 0
            return [s.grid[i,j]]
        end
        values = 1:9
        values = setdiff(values, s.grid[i,:])
        values = setdiff(values, s.grid[:,j])
        tli, tlj = topleft(i), topleft(j)
        values = setdiff(values, s.grid[tli:tli+2, tlj:tlj+2])
        values
    end

    function update(s::Sudoku)
        change = false
        for i in 1:9
            for j in 1:9
                if s.grid[i, j] == 0
                    poss = possibilities(s, i, j)
                    if length(poss) == 1
                        s.grid[i,j] = poss[1]
                        change = true
                    end
                end
            end
        end

        possibilities_matrix = hcat([[possibilities(s, i, j) for i in 1:9] for j in 1:9]...)

        for gen in (Base.eachrow, Base.eachcol, eachblock)
            for (possibilities_vector, grid_vector) in zip(gen(possibilities_matrix), gen(s.grid))
                fishing = [findall(k in x for x in possibilities_vector) for k in 1:9] # indices where the value at index could be
                knowns = Dict{Int64,Int64}() # maps index to its known value
                for (l, f) in enumerate(fishing)
                    if length(f) == 1
                        knowns[f[1]] = l
                    end
                end
                vacancies = findall(x -> x == 0, grid_vector) # all the indices we need to fill in
                newlocs = intersect(vacancies, keys(knowns))
                if length(newlocs) > 0
                    for n in newlocs
                        grid_vector[n] = knowns[n]
                        change = true
                    end
                end
            end
        end

        change
    end

    function solve(s::Sudoku)
        change = true
        solution = Base.copy(s)
        while change
            change = update(solution)
        end
        solution
    end
end
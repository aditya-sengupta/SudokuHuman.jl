"""
A Sudoku solver whose steps are transparent to humans!
"""

module SudokuHuman
    using StaticArrays
    using LinearAlgebra
    import Base.show, Base.eachrow, Base.eachcol, Base.copy
    import Base.Iterators: product, drop

    struct Sudoku
        grid::MMatrix{9,9,Int64}
    end

    include("puzzles.jl")

    export puzzles, Sudoku, make_puzzles
    export check, update!, solve

    topleft(i) = 3 * ((i - 1) ÷ 3) + 1

    function blockof(i, j)
        tli, tlj = topleft(i), topleft(j)
        return (tli:(tli+2), tlj:(tlj+2))
    end

    function Base.show(io::IO, s::Sudoku)
        println("  -----   -----   -----")
        for (i, r) in enumerate(eachrow(s.grid))
            Base.print("| ")
            for (j, v) in enumerate(r)
                Base.print((v > 0 ? string(v) : "-") * " ")
                if j % 3 == 0
                    Base.print("| ")
                end
            end
            println()
            if i % 3 == 0
                println("  -----   -----   -----")
            end
        end
    end

    Base.eachrow(s::Sudoku) = Base.eachrow(s.grid)
    Base.eachcol(s::Sudoku) = Base.eachcol(s.grid)
    Base.eachrow(arr::AbstractArray{T, 3} where T) = eachslice(arr, dims=1)
    Base.eachcol(arr::AbstractArray{T, 3} where T) = eachslice(arr, dims=2)
    blockindsof(i) = ((3 * ((i-1) ÷ 3) + 1):(3 * ((i-1) ÷ 3) + 3), (3 * ((i-1) % 3) + 1):(3 * ((i-1) % 3) + 3))
    blockinds() = (blockindsof(i) for i in 1:9)
    eachblock(arr::AbstractArray{T, 3} where T) = (reshape(arr[x..., :], (9,9)) for x in blockinds())
    eachblock(m::AbstractMatrix) = (vec(m[x...]) for x in blockinds())

    eachblock(s::Sudoku) = eachblock(s.grid)
    Base.copy(s::Sudoku) = Sudoku(Base.copy(s.grid))

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

    function indexof(desc::String, iternum::Int64, pos::Int64)
        if desc == "row"
            return (iternum, pos)
        elseif desc == "col"
            return (pos, iternum)
        elseif desc == "block"
            blockinds = blockindsof(iternum)
            return first(drop(product(blockinds...), pos - 1))
        end
    end

    function update!(s::Sudoku, flags::AbstractArray{Bool, 3}, index::Tuple{Int64,Int64})
        val = s.grid[index...]
        if val > 0
            flags[index[1], 1:9, val] .= false # nothing in the row can be 'val'
            flags[1:9, index[2], val] .= false # nothing in the col can be 'val'
            flags[blockof(index...)..., val] .= false # nothing in the block can be 'val'
            flags[index..., 1:9] .= false # this index can't be anything
            flags[index..., val] = true # except for the value we just found
        end
    end

    function solve(s::Sudoku)
        solution = Base.copy(s)
        flags = @MArray ones(Bool, 9, 9, 9)
        for index in product(1:9, 1:9)
            update!(solution, flags, index)
        end

        num_found = sum(vec(solution.grid) .> 0)
        last_num_found = sum(vec(solution.grid) .> 0)
        while num_found < 81
            # first check: for each square, is there only one possible answer?
            for index in product(1:9, 1:9)
                slice = flags[index..., 1:9] # look at all the possible values "index" could take on
                if sum(slice) == 1 && solution.grid[index...] == 0 # I know something and I didn't know it before this
                    val = findfirst(slice)
                    println("$index can only be $val")
                    solution.grid[index...] = val
                    update!(solution, flags, index) # eliminate possibilities from new information
                    num_found += 1
                end
            end

            # second check: for each (row, column, block), is there only one possible place a certain value could go?
            for (desc, gen) in zip(("row", "col", "block"), (Base.eachrow, Base.eachcol, eachblock))
                for (num, (possibilities, grid_vector)) in enumerate(zip(gen(flags), gen(solution.grid)))
                    # "possibilities" is a 9x9: (i, j) is "could position i in the row (resp. column, block) be value j?"
                    # grid_vector is a length-9 vector with the known values
                    vacancies = findall(x -> x == 0, grid_vector) # all the indices we need to fill in
                    knownvals = findall(x -> x == 1, vec(sum(possibilities, dims=1))) # all the numbers we know
                    knowns = hcat([findall(x -> x == 1, possibilities[:,k]) for k in knownvals]...)
                    println("$desc $num needs $vacancies and we know $knowns")
                    newlocs = intersect(vacancies, knowns) # where's the new information
                    if length(newlocs) > 0
                        for n in newlocs
                            val = findfirst(x -> x == 1, possibilities[n,:])
                            println("$desc $num's only possible location for $val is $n")
                            grid_vector[n] = findfirst(x -> x == 1, possibilities[n,:])
                            update!(solution, flags, indexof(desc, num, n))
                            num_found += 1
                        end
                    end
                end
            end

            if num_found == last_num_found # we didn't find anything new this iteration
                return solution, flags
            end
            last_num_found = num_found
        end
        solution, flags
    end
end
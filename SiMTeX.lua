local P = {}

P.smart_matrix_separator = ','
P.smart_matrix_env_stack = {}

function P.SmartMatrix(rows, columns, contents, brackets)
    columns = tonumber(columns)
    rows = tonumber(rows)

    if not columns and not rows then
        tex.error("Either column or row count must be specified.")
        return
    end

    local elems = {}

    for elem in contents:gmatch('[^,]+') do
        table.insert(elems, elem)
    end

    if columns and rows and columns * rows ~= #elems then
        tex.error(string.format("Matrix was [%sx%s] needing [%s] elements, but [%s] elements were given",
                rows, columns, rows * columns, #elems))
        return
    elseif columns and #elems % columns ~= 0 then
        tex.error(string.format("Matrix was [*x%s] needing a multiple of [%s] elements, but [%s] elements were given",
                columns, columns, #elems))
        return
    elseif rows and #elems % rows ~= 0 then
        tex.error(string.format("Matrix was [%sx*] needing a multiple of [%s] elements, but [%s] elements were given",
                rows, rows, #elems))
        return
    end

    -- All inputs should be fine now, continue with constructing the matrix.

    if columns then
        rows = #elems / columns
    elseif rows then   
        columns = #elems / rows
    end

    local matrix_env = "matrix"

    if #P.smart_matrix_env_stack > 0 then
        matrix_env = P.smart_matrix_env_stack[#P.smart_matrix_env_stack]
    end

    local latex_out = { }
    table.insert(latex_out, string.format("\\begin{%s%s}", brackets, matrix_env))
    
    for r=0, rows - 1 do
        for c=0, columns - 1 do 
            table.insert(latex_out, elems[r * columns + c + 1])

            if c ~= columns - 1 then
                table.insert(latex_out, '&')
            end
        end

        if r ~= rows - 1 then
            table.insert(latex_out, '\\\\')
        end
    end

    table.insert(latex_out, string.format("\\end{%s%s}", brackets, matrix_env))

    tex.print(table.concat(latex_out))
end

function P.pushSmartMatEnv(env)
    table.insert(P.smart_matrix_env_stack, env)
end

function P.popSmartMatEnv()
    if #P.smart_matrix_env_stack > 0 then
        table.remove(P.smart_matrix_env_stack, #P.smart_matrix_env_stack)
    end
end

return P

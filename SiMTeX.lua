local P = {}

P.SmartMatrixSeparator = ','

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

    tex.print(string.format("\\begin{%sNiceMatrix}", brackets))
    
    for r=0, rows - 1 do
        for c=0, columns - 1 do 
            tex.print(elems[r * columns + c + 1])

            if c ~= columns - 1 then
                tex.print('&')
            end
        end

        if r ~= rows - 1 then
            tex.print('\\\\')
        end
    end

    tex.print(string.format("\\end{%sNiceMatrix}", brackets))

end

return P

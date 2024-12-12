local P = {}

-- Smart Matrix

local SMat = {}

SMat.smart_matrix_separator = ','
SMat.smart_matrix_env_stack = {}

function SMat.SmartMatrix(rows, columns, contents, brackets)
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

    if #SMat.smart_matrix_env_stack > 0 then
        matrix_env = SMat.smart_matrix_env_stack[#SMat.smart_matrix_env_stack]
    end

    local latex_out = {}
    table.insert(latex_out, string.format("\\begin{%s%s}", brackets, matrix_env))

    for r = 0, rows - 1 do
        for c = 0, columns - 1 do
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

function SMat.pushSmartMatEnv(env)
    table.insert(SMat.smart_matrix_env_stack, env)
end

function SMat.popSmartMatEnv()
    if #SMat.smart_matrix_env_stack > 0 then
        table.remove(SMat.smart_matrix_env_stack, #SMat.smart_matrix_env_stack)
    end
end

P.SMat = SMat

-- Code Inclusions

local CodeInc = {}

function CodeInc.extractCStyleScope(code, scope_start)
    
    local line_start, line_end = CodeInc.findLineWithExpr(code, scope_start)

    if line_start == nil then
        error(("Could not find any line containint '%s'"):format(line_start))
    end

    -- now search for the first curly bracket, this will mark the start of the scope.

    local scope_depth = -1
    local scope_start = nil
    local scope_end = nil

    for i=line_start, #code do
        if code[i] == '{' then
            scope_depth = scope_depth + 1
            scope_start = i
            break
        end
    end

    if scope_depth then
        error(("Could not find a scope starter ({) after character no. %s"):format(line_start))
    end

    -- now continue until we go out of scope

    local is_inside_string = false

    for i=scope_start+1, #code do

        if code[i] == '{' then
            scope_depth = scope_depth + 1
        elseif code[i] == '}' then
            scope_depth = scope_depth - 1
        end

        if scope_depth < 0 then
            scope_end = i
            break
        end
    end

    return code:sub(scope_start, scope_end)
end

-- Returns the starting and ending index of the line, where the given expression is present in the passed string
-- Returns nil if no such line could be found.
function CodeInc.findLineWithExpr(text, expr)
    local current_index = 1

    -- Loop through each line of the passed string
    while true do
        local newline_index = text:find("\n", 1, true)

        if newline_index ~= nil then
            local line = text:sub(1, newline_index)
            local found_expr_index = line:find(expr, 1, true)
            if found_expr_index ~= nil and found_expr_index == 1 then
                return current_index, current_index + #line - 2
            else
                current_index = current_index + #line
                text = text:sub(newline_index + 1)
            end
        elseif text:find(expr, 1, true) then
            return current_index, #expr
        else
            return nil
        end
    end
end

return P

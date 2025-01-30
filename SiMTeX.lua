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
            if found_expr_index ~= nil then
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

function CodeInc.calcIndentation(line)
    return #line:match("^%s*")
end

function CodeInc.extractPythonScope(code, scope_start)
    -- find scope start

    local line_start, line_end = CodeInc.findLineWithExpr(code, scope_start)
    local scope_start_line = code:sub(line_start, line_end)

    local scope_indentation = CodeInc.calcIndentation(scope_start_line)


    -- loop through lines until we find a non empty line, that is a line which has something different that whitespace
    -- which has the same indentation, or less, than the scope start.



    -- exclude this line, and go back till the nearest non empty line, different from code_start.
end

function CodeInc.extractCStyleScope(code, scope_start)
    local line_start, line_end = CodeInc.findLineWithExpr(code, scope_start)

    if line_start == nil then
        error(("Could not find any line containint '%s'"):format(line_start))
    end

    -- now search for the first curly bracket, this will mark the start of the scope.

    local scope_depth = -1
    local scope_start = nil
    local scope_end = nil

    for i = line_start, #code do
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

    for i = scope_start + 1, #code do
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

P.CodeInc = CodeInc

-- Python Exec

PythonExec = {
    python_procs = {}
}

-- Tries to execute the given SiMTeX registered python function from the given file,
-- with the given arguments.
--
-- If file_name has not been passed before, a new python process is created for this file.
function PythonExec.execPythonFunc(file_name, func_name, args)
    -- check if we already have a python process for this file,
    -- that way we avoid the initial runtime spent on importing modules for each execPythonFunc call.
    if not PythonExec.python_procs[file_name] then
        -- create python process
        print("PYTHON\tSTART")

        local py_exec = ""

        if package.config:sub(1, 1) == '\\' then
            py_exec = "py"
        else
            py_exec = "python"
        end

        local python_pipe, err = io.popen(py_exec .. " " .. file_name, "w")
        
        if python_pipe == nil then
            error(("Could not open python file %s: %s"):format(file_name, err))
            return
        end
        
        PythonExec.python_procs[file_name] = {
            pipe = python_pipe
        }
        
        -- setup file communication.
        
        -- first, get a temporary file to use for communication.
        print("COMM\tFILE OPEN START")
        
        local out_file_path = os.tmpname()
        local out_file, err = io.open(out_file_path, "wb")
        
        if not out_file then
            error(("Could not open file %s: %s"):format(out_file_path, err))
            return
        end
        
        local in_file_path = os.tmpname()
        io.open(in_file_path, "w"):close()
        local in_file, err = io.open(in_file_path, "rb")
        
        if not in_file then
            error(("Could not open file %s: %s"):format(out_file_path, err))
            return
        end
        
        print("STDIN\tSTART")
        -- send file info to the python process.
        python_pipe:write(out_file_path .. "\n")
        python_pipe:write(in_file_path .. "\n")
        python_pipe:flush()
        print("STDIN\tEND")

        -- finally, cache the connection, so we do not have to do this again.
        PythonExec.python_procs[file_name].in_file_path = in_file_path
        PythonExec.python_procs[file_name].in_file = in_file
        PythonExec.python_procs[file_name].out_file_path = out_file_path
        PythonExec.python_procs[file_name].out_file = out_file
    end

    -- we are guaranteed to have a connection by now
    local in_file = PythonExec.python_procs[file_name].in_file
    local out_file = PythonExec.python_procs[file_name].out_file

    -- send function info to python process.
    PythonExec.sendMessage(out_file, func_name)
    PythonExec.sendMessage(out_file, args)

    -- receive results.
    local status = PythonExec.recvMessage(in_file)
    local response = PythonExec.recvMessage(in_file)

    -- tex.print is weird with newlines in strings,
    -- so we just call tex.print for each newline to avoid these issues.
    for line in response:gmatch("[^\r\n]+") do
        tex.print(line)
    end

    if status == "error" then
        error(response)
    end
end

-- send a message via. a TCP socket.
function PythonExec.sendMessage(file, message)
    print("LUA\tSEND")
    local message_length = string.pack(">I4", #message)
    file:write(message_length .. message)
    file:flush()
end

-- receive a message via. a TCP socket.
-- format assumed is first 4 bytes is length of the message, followed by the message itself.
function PythonExec.recvMessage(file)
    print("LUA\tRECV")
    local message_length = PythonExec.recvBytes(file, 4)
    local length = string.unpack(">I4", message_length)

    return PythonExec.recvBytes(file, length)
end

function PythonExec.recvBytes(file, byte_count, timeout)
    if timeout == nil then
        timeout = 10
    end

    local msg = ""

    local start_time = os.clock()

    while byte_count > 0 do
        local data = file:read(byte_count)
        if data then
            msg = msg .. data
            byte_count = byte_count - #data
        else
            if os.clock() - start_time > timeout then
                error(string.format("Timeout while reading from file '%s' after %d seconds.", file, timeout))
            end
        end
    end

    return msg
end

-- closes all currently open connections, and shutdown all python processes.
function PythonExec.cleanup()
    for python_file, proc in pairs(PythonExec.python_procs) do
        -- ok just send an exit signal here to the process.
        PythonExec.sendMessage(proc.out_file, "exit")
        PythonExec.sendMessage(proc.out_file, "")
        proc.pipe:close()
        proc.in_file:close()
        proc.out_file:close()
        os.remove(proc.in_file_path)
        os.remove(proc.out_file_path)
    end
end

P.PythonExec = PythonExec

return P

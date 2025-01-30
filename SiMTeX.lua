local P = {}

-- forward declare packages which will be setup in SiMTeX.initialize()
local socket = nil

-- custom implementation of lua's built in searcher functions for the path and cpath variables.
local function lua_src_searcher(name)
    local file, err = package.searchpath(name, package.path)
    if err then
        return string.format("[lua source (path) searcher]: module not found: '%s'%s", name, err)
    else
        return loadfile(file)
    end
end

local function lua_bin_searcher(name)
    local file, err = package.searchpath(name, package.cpath)
    if file == nil then
        return string.format("[lua binary (cpath) searcher]: module not found: '%s'%s", name, err)
    else
        local symbol = name:gsub("%.", "_")
        return package.loadlib(file, "luaopen_" .. symbol)
    end
end

-- Sets up package paths and searchers to support local module directories.
-- if module dir is an empty string, no additional paths are added,
-- otherwise it is assumed the module dir was created with a luarocks --tree like function call.
--
-- This function should be called before any othe function is called from this module.
function P.initialize(module_dir)
    -- update package paths with local module dir folders.
    if module_dir:match("^%s*$") == nil then
        local lua_version = _VERSION:match("Lua (%d+%.%d+)")

        package.path = module_dir .. "/share/lua/" .. lua_version .. "/?.lua;" .. package.path

        package.cpath = module_dir .. "/lib/lua/" .. lua_version .. "/?.so;" .. package.cpath
        package.cpath = module_dir .. "/lib/lua/" .. lua_version .. "/?.dll;" .. package.cpath
    end

    -- luatex replaces luas built in searchers with some wierd KPSE searchers,
    -- which do not make use of the package.path or package.cpath variables,
    -- so we have to add lua's built in searchers back in for the above modifications to take effect.
    table.insert(package.searchers, lua_src_searcher)
    table.insert(package.searchers, lua_bin_searcher)

    -- now require modules.
    socket = require("socket")
end

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
    -- initialize has not been called, this will not work.
    if socket == nil then
        return
    end

    -- check if we already have a python process for this file,
    -- that way we avoid the initial runtime spent on importing modules for each execPythonFunc call.
    if not PythonExec.python_procs[file_name] then
        -- create python process
        local python_pipe, err = io.popen("py " .. file_name, "w")

        if python_pipe == nil then
            error(("Could not open python file %s: %s"):format(file_name, err))
            return
        end

        PythonExec.python_procs[file_name] = {
            pipe = python_pipe
        }

        -- setup server <-> client connection between the just started python process.

        local comm_server, err = socket.bind("127.0.0.1", 0)
        comm_server:settimeout(5)

        if not comm_server then
            error(("Could not bind to port: %s"):format(err))
            return
        end

        local ip, port = comm_server:getsockname()

        -- send connection info to the python process.
        python_pipe:write(ip .. '\n' .. port .. '\n')
        python_pipe:flush()

        -- wait for connection from the python process.
        local comm_client, err = comm_server:accept()

        if not comm_client then
            error(("Could not accept connection: %s"):format(err))
            return
        end

        comm_client:settimeout(30)

        -- finally, cache the connection, so we do not have to do this again.
        PythonExec.python_procs[file_name].comm_server = comm_server
        PythonExec.python_procs[file_name].comm_client = comm_client
    end

    -- we are guaranteed to have a connection by now
    local client = PythonExec.python_procs[file_name].comm_client

    -- send function info to python process.
    PythonExec.sendMessage(client, func_name)
    PythonExec.sendMessage(client, args)

    -- receive results.
    local status = PythonExec.recvMessage(client)
    local response = PythonExec.recvMessage(client)

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
function PythonExec.sendMessage(socket, message)
    local message_length = string.pack(">I4", #message)
    socket:send(message_length .. message)
end

-- receive a message via. a TCP socket.
-- format assumed is first 4 bytes is length of the message, followed by the message itself.
function PythonExec.recvMessage(socket)
    local message_length = socket:receive(4)
    local length = string.unpack(">I4", message_length)
    return socket:receive(length)
end

-- closes all currently open connections, and shutdown all python processes.
function PythonExec.cleanup()
    for _, proc in pairs(PythonExec.python_procs) do
        if proc.comm_client then
            proc.comm_client:close()
        end

        proc.pipe:close()
    end
end

P.PythonExec = PythonExec

return P

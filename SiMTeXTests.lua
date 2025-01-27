SiMTeX = require('SiMTeX')

local python_code = [[
import 123

            def foo():
                print(123)

                test

                for i in range(inner_scope):
                    print(123)


class bar:
    def __init__():
        foobar = 123

        for bar in foo:
            print(hej med dig dette er noget python kode)

]]

print(SiMTeX.CodeInc.extractPythonScope(python_code, "def foo"))

print(python_code)

cmd = io.popen("cmd.exe", "w")

cmd:close()

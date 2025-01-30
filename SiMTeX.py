import socket
import traceback
from typing import Callable
from inspect import signature

## SiMTeXInput provides a series of default input parsers for the SiMTeX class.
class SiMTeXInput:
    # The raw parser simply returns the latex input as a string.
    @staticmethod
    def raw() -> Callable[[str], tuple[str]]:
        return lambda i: (i,)

    # The singleValue parser converts the latex string into the given type.
    @staticmethod
    def singleValue(type: type) -> Callable[[str], tuple[any]]:
        return lambda i: (type(i),)

    # the multValues parser works like the singleValue parser,
    # but does this for multiple parameters.
    #
    # The latex string is split into tokes by the given separator.
    @staticmethod
    def multValues(
        types: type | list[type], sep: str = " "
    ) -> Callable[[str], tuple[any]]:
        if type(types) is list or type(types) is tuple:

            def parser(i: str):
                values = i.split(sep)

                if len(values) != len(types):
                    raise ValueError("Number of values does not match number of types")

                return (t(v) for t, v in zip(types, values))

            return parser
        else:
            return lambda i: (types(v) for v in i.split(sep))


##
## The SiMTeX class provides an interface for python processes to interface with the SiMTeX latex package.
## With this class, python functions can be registered, so they can be called from a latex document.
##
## For this to work, SiMTeX.run must be called at the end of the document.
## This spins up a client which will try to connect to a server provided by a SiMTeX latex package instance.
##
class SiMTeX:
    # holds all currently registered functions.
    # each entry should contain a cmd field, holding the function itself,
    # as well as an input_parser field, holding the function which will parse the input given from latex.
    cmds = {}

    # Register a function to be callable from a latex document.
    # optionally provide an input parser, which transform the input given from latex, into input suitable for the function.
    # The input given from latex will always be a single string.
    # SiMTeXInput provides a series of default input parser factories,
    # and auto_push_cmd automatically generates a parser based on the function signature.
    @staticmethod
    def push_cmd(
        cmd: Callable, input_parser: Callable[[str], tuple[any]] = SiMTeXInput.raw()
    ):
        SiMTeX.cmds[cmd.__name__] = {"cmd": cmd, "input_parser": input_parser}

    # Auto generates an input parser for the given function and passes this to push_cmd.
    # the input parser is based on the functions signature, and the annotations used for the parameters.
    # if a parameter has no annotation, it is assumed to be of a string type.
    #
    # the parser splits the latex input by the given separator ' ' by default,
    # and then tries to convert each token to the corresponding parameter type of the function.
    @staticmethod
    def auto_push_cmd(cmd: Callable, sep: str = " "):
        # construct input parser from function signature
        sig = signature(cmd)

        pos_params = []
        var_param = None

        # retreive parameter info.
        for param in sig.parameters.values():
            if (
                param.kind == param.POSITIONAL_ONLY
                or param.kind == param.POSITIONAL_OR_KEYWORD
            ):
                pos_params.append(param)
            elif param.kind == param.VAR_POSITIONAL:
                var_param = param
                break

        # construct the parser.
        def parser(i: str):
            tokens = i.split(sep)

            if not var_param and len(tokens) != len(pos_params):
                raise ValueError("Number of values does not match number of parameters")

            # try to typecast all the tokens from str to the corresponding parameter type.
            for i in range(len(pos_params)):
                annotation = pos_params[i].annotation

                if annotation is param.empty:
                    continue

                tokens[i] = annotation(tokens[i])

            # now deal with the remaining variadic arguments (if present in the func sig)
            if var_param and var_param.annotation is not param.empty:
                var_annotation = var_param.annotation

                for i in range(len(pos_params), len(tokens)):
                    tokens[i] = var_annotation(tokens[i])

            return tuple(tokens)

        SiMTeX.push_cmd(cmd, parser)

    # runs the given command with the given input.
    @staticmethod
    def run_cmd(cmd_name: str, cmd_input: str):
        cmd = SiMTeX.cmds[cmd_name]
        return cmd["cmd"](*cmd["input_parser"](cmd_input))

    # setup a client connection to a latex compiler instance running the SiMTeX package.
    # this call is blocking for the duration of the build process.
    @staticmethod
    def run():
        # receive connection info from build process throug stdin.
        ip = input()
        port = int(input())

        # setup TCP client socket.
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect((ip, port))
        client.setblocking(True)

        # start message loop.
        while True:
            # receive exec info from latex.
            func_name = SiMTeX.recv_message(client)
            args = SiMTeX.recv_message(client)

            # run command and send responses to latex.
            try:
                output = SiMTeX.run_cmd(func_name, args)
                SiMTeX.send_message(client, "success")
                SiMTeX.send_message(client, output)
            except Exception as e:
                err_msg = (
                    "\n\n\\begin{lstlisting}[breaklines=true]\n"
                    + traceback.format_exc()
                    + "\n\\end{lstlisting}\n\n"
                )
                SiMTeX.send_message(client, "error")
                SiMTeX.send_message(client, err_msg)

    # send a message through a TCP client socket.
    @staticmethod
    def send_message(client: socket.socket, message: str):

        message = str(message)
        length = len(message)

        client.sendall(length.to_bytes(4, byteorder="big"))
        client.sendall(message.encode("utf-8"))

    # receive a message through a TCP client socket.
    # format is assumed to start with a 4 byte integer, representing the length of the message,
    # followed by the message itself.
    @staticmethod
    def recv_message(client: socket.socket) -> str:
        length_bytes = client.recv(4)

        if not length_bytes:
            return None

        length = int.from_bytes(length_bytes, byteorder="big")
        message = client.recv(length)

        return message.decode("utf-8")

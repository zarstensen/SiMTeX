import sys
import socket
import traceback

class SiMTeXInput:
    @staticmethod
    def raw():
        return lambda i: (i,)
    
    @staticmethod
    def singleValue(type: type):
        return lambda i: (type(i),)
    
    @staticmethod
    def multValues(types: type | list[type], sep: str = ' '):
        if type(types) is list or type(types) is tuple:
            def parser(i: str):
                values = i.split(sep)

                if len(values) != len(types):
                    raise ValueError('Number of values does not match number of types')
                
                return (t(v) for t, v in zip(types, values))
            return parser
        else:
            return lambda i: (types(v) for v in i.split(sep))



class SiMTeX:
    cmds = { }
    
    @staticmethod
    def register_cmd(cmd, input_parser=SiMTeXInput.raw):
        SiMTeX.cmds[cmd.__name__] = {
        'cmd': cmd,
        'input_parser': input_parser
    }

    @staticmethod
    def run_cmd(cmd_name, cmd_input):
        cmd = SiMTeX.cmds[cmd_name]
        return cmd['cmd'](*cmd['input_parser'](cmd_input))
    
    @staticmethod    
    def run():
        ip = input()
        port = int(input())

        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect((ip, port))
        client.setblocking(True)
        
        while True:
            func_name = SiMTeX.recvMessage(client)
            args = SiMTeX.recvMessage(client)
            
            try:
                output = SiMTeX.run_cmd(func_name, args)
                SiMTeX.sendMessage(client, "success")
                SiMTeX.sendMessage(client, output)
            except Exception as e:
                # traceback.format_exc()
                err_msg = "\n\n\\begin{lstlisting}[breaklines=true]\n" + traceback.format_exc() + "\n\\end{lstlisting}\n\n"
                print(err_msg)
                SiMTeX.sendMessage(client, "error")
                SiMTeX.sendMessage(client, err_msg)

    @staticmethod
    def recvMessage(client):
        length_bytes = client.recv(4)
        if not length_bytes:
            return None
        length = int.from_bytes(length_bytes, byteorder='big')
        message = client.recv(length)
        return message.decode('utf-8')

    @staticmethod
    def sendMessage(client, message):
        message = str(message)
        length = len(message)
        client.sendall(length.to_bytes(4, byteorder='big'))
        client.sendall(message.encode('utf-8'))

        


import sys
import socket

def _def_input_parser(i):
    return (i,)

class SiMTeX:
    cmds = {
        'exit': {
            'cmd': exit,
            'input_parser': lambda i: (int(i),) 
        }
    }
    
    @staticmethod
    def register_cmd(cmd, input_parser=_def_input_parser):
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
            
            SiMTeX.sendMessage(client, SiMTeX.run_cmd(func_name, args))
            

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

        # while True:
        #     print("NEW MSG")
        #     cmd_in = ""
        #     for line in sys.stdin:
        #         print("LINE: ", line)
        #         if line == "¤¤¤END_SIMTEX_MSG¤¤¤\n":
        #             break
                
        #         cmd_in += line

        #     print("STDIN: ", cmd_in)
        #     cmd_in = cmd_in.split(' ', 1)
        #     print(cmd_in)
                        
        #     res = str(SiMTeX.run_cmd(*cmd_in))
            
        #     with open("message.stm", "w") as f:
        #         f.write(res)
        #         f.write(f"\n¤¤¤END_SIMTEX_MSG¤¤¤\n")
        

        

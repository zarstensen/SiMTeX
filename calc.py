from SiMTeX import *
from sympy import *

def addNumbers(a, b):
    return "Numbers are: " + str(a + b)

SiMTeX.register_cmd(addNumbers, lambda i: ( int(x) for x in i.split(' ')))
SiMTeX.run()

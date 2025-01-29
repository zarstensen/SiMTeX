from SiMTeX import *
from sympy import *

def addNumbers(a, b):
    return "Numbers are: " + str(a + b)

def vsum(*args):
    return sum(args)

SiMTeX.register_cmd(addNumbers, SiMTeXInput.multValues([int, int]))
SiMTeX.register_cmd(vsum, SiMTeXInput.multValues(float, sep=','))
SiMTeX.run()

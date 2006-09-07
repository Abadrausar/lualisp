require "Parser"
sexpr = Parser.parseSexpr(arg[1])[1]
print(Sexpr.prettyPrint(sexpr))

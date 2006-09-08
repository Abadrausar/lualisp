-- This software is licensed under the M.I.T. license.
-- The license text is found in "license.txt"
--
-- LispInterpreter.lua
-- Author: David Bergman
--
-- This is a Scheme/Lisp interpreter, written in Lua
--

require "Environment"
require "Parser"

Lisp = { }

function Lisp.evalExpr(env, expr)
   return Lisp.evalSexprList(env, Parser.parseSexpr(expr))
end

function Lisp.evalQuote(env, sexpr)
   local value
   if not sexpr.type then
      error("Invalid S-expr: ", 2)
   end
   if sexpr.type == "CONS" then
      local car = sexpr.car
      if car.type=="OP" and car.lexeme=="," then
	 value = Lisp.evalSexpr(env, sexpr.cdr)
      else	    
	 local evalCar = Lisp.evalQuote(env, car)
	 local cdr = Lisp.evalQuote(env, sexpr.cdr)
	 value = Sexpr.cons(evalCar, cdr)
      end
   else
      value = sexpr
   end
   return value
end

function Lisp.evalSexprList(env, sexprList, index)
   if not index then
      index = 1
   end
   local count = table.getn(sexprList)
   if index > count then
      return nil
   else
      local firstValue = Lisp.evalSexpr(env, sexprList[index])
      if index == count then
	 return firstValue
      else
	 return Lisp.evalSexprList(env, sexprList, index+1)
      end
   end
end

function Lisp.evalSexpr(env, sexpr)
   local value
   if not sexpr.type then
      error("Invalid S-expr: " .. sexpr, 2)
   end
   if sexpr.type == "CONS" then
      -- 1. Cons cell
      local car = sexpr.car
      if car.type=="OP" and car.lexeme=="'" then
	 value = sexpr.cdr
      elseif car.type=="OP" and car.lexeme=="`" then
	 local cdr = Lisp.evalQuote(env, sexpr.cdr)
	 value = cdr
      else
	 local fun = Lisp.evalSexpr(env, car)
	 if not fun or fun.type ~= "FUN" then
	    error("The S-expr did not evaluate to a function: " ..
		  tostring(car))
	 end
	 -- The function can be eithe "lazy", in that it deals
	 -- with evaluation of its arguments itself, a "macro",
	 -- which requires
	 -- a second evaluation after the macro expansion, or
	 -- a regular eager one

	 local args
	 if fun.special == "lazy" or fun.special == "macro"  then
	    args = sexpr.cdr
	 else
	    args = Lisp.evalList(env, sexpr.cdr)
	 end
	 value = fun.fun(env, args)
      end
   elseif sexpr.type == "SYM" then
      -- a. symbol
      value = env[sexpr.lexeme]
      if not value then
	 error("The symbol '" .. sexpr.lexeme .. "' is not defined")
      end
   else
      -- b. constant
      value = sexpr
   end
   return value
end

-- Evaluate each item in a list
function Lisp.evalList(env, list)
   local value
   if list.type=="CONS" then
      value = Sexpr.cons(Lisp.evalSexpr(env, list.car),
			 Lisp.evalList(env, list.cdr))
   else
      value = list
   end
   return value
end

-- Apply an environment and get the substituted S-exp
function Lisp.applyEnv(env, expr)
   local newSexpr
   if expr.type == "CONS" then
      newSexpr = Sexpr.cons(Lisp.applyEnv(env, expr.car),
			    Lisp.applyEnv(env, expr.cdr))
   elseif expr.type == "SYM" then
      newSexpr = env[expr.lexeme]
      if not newSexpr then
	 newSexpr = expr
      end
   else
      newSexpr = expr
   end
   return newSexpr
end

-- Some primitives

function Lisp.prim_car(env, args)
   return args.car.car
end

function Lisp.prim_cdr(env, args)
   return args.car.cdr
end

function Lisp.prim_cons(env, args)
   return Sexpr.cons(args.car, args.cdr.car)
end

function Lisp.prim_plus(env, args)
   local num1 = args.car.lexeme + 0
   local num2 = args.cdr.car.lexeme + 0
   local sum = num1 + num2
   return Sexpr.newAtom(sum)
end

function Lisp.prim_mult(env, args)
   local num1 = args.car.lexeme + 0
   local num2 = args.cdr.car.lexeme + 0
   local prod = num1 * num2
   return Sexpr.newAtom(prod)
end

function Lisp.prim_lambda(env, args)
   local formalParams = args.car
   local body = args.cdr.car
   return Sexpr.newFun("(lambda " ..
		       Sexpr.prettyPrint(formalParams) ..
			  " " .. Sexpr.prettyPrint(body)
			  .. ")",
		       function(env2, actualParams)
			  local localEnv =
			     env:addBindings(formalParams,
					     actualParams)
			  return Lisp.evalSexpr(localEnv,
						body)
		       end)
end

function Lisp.prim_if(env, args)
   local cond = Lisp.evalSexpr(env, args.car)
   local expr
   if cond.type == "LITERAL" and cond.lexeme=="nil" then
      expr = args.cdr.cdr.car
   else
      expr = args.cdr.car
   end
   return Lisp.evalSexpr(env, expr)
end

function Lisp.prim_eq(env, args)
   local arg1 = args.car
   local arg2 = args.cdr.car
   return Sexpr.newBool(arg1.type == arg2.type and
			arg1.type ~= "CONS" and
			   arg1.lexeme == arg2.lexeme)
end

function Lisp.prim_lt(env, args)
   return Sexpr.newBool(args.car.lexeme+0 <
			args.cdr.car.lexeme+0)
end

function Lisp.prim_consp(env, args)
   return Sexpr.newBool(args.car.type == "CONS")
end

function Lisp.prim_neg(env, args)
   return Sexpr.newAtom(- args.car.lexeme)
end

function Lisp.prim_setq(env, args)
   local sym = args.car
   local value = Lisp.evalSexpr(env, args.cdr.car)
   env[sym.lexeme] = value
   return value
end

-- Our eval handles both strings and S-exprs
function Lisp.prim_eval(env, sexpr)
   local value
   local car = sexpr.car
   if car.type == "STR" then
      value = Lisp.evalExpr(env, car.lexeme)
   else
      value = Lisp.evalSexpr(env, car)
   end
   return value
end

-- Evaluate a whole lisp file, and return 't'

function Lisp.prim_load(env, sexpr)
   local filename = sexpr.car.lexeme
   local lastValue = Lisp.runFile(env, filename)
   return Sexpr.newBool(true)
end

-- Echo S-expr standard output
function Lisp.prim_echo(env, sexpr)
   print(Sexpr.prettyPrint(sexpr.car))
   return Sexpr.newBool(true)
end

function Lisp.prim_defmacro(env, sexpr)
   local name = sexpr.car
   local params = sexpr.cdr.car
   local body = sexpr.cdr.cdr.car
   local macro =
      function (env2, e)
	 local paramScope = {}
	 Env.bind(paramScope, params, e)
	 local subsEnv = Env.new(paramScope)
	 local expanded = Lisp.applyEnv(subsEnv, body)
	 local value = Lisp.evalSexpr(env2, expanded)
	 return value
      end
   local fun = Sexpr.newFun("(defmacro " .. name.lexeme ..
			    " " .. Sexpr.prettyPrint(params) ..
			       " " .. Sexpr.prettyPrint(body) ..
			       ")", macro, "macro")
   env[name.lexeme] = fun
   return fun
end

function Lisp.getPrimitiveScope()
   return {
      car = Sexpr.newFun("car", Lisp.prim_car),
      cdr = Sexpr.newFun("cdr", Lisp.prim_cdr),
      cons = Sexpr.newFun("cons", Lisp.prim_cons),
      lambda = Sexpr.newFun("lambda", Lisp.prim_lambda, "lazy"),
      setq = Sexpr.newFun("setq", Lisp.prim_setq, "lazy"),
      ["<"] = Sexpr.newFun("<", Lisp.prim_lt),
      ["+"] = Sexpr.newFun("+", Lisp.prim_plus),
      ["*"] = Sexpr.newFun("*", Lisp.prim_mult),
      neg = Sexpr.newFun("neg", Lisp.prim_neg),
      eq = Sexpr.newFun("eq", Lisp.prim_eq),
      consp = Sexpr.newFun("consp", Lisp.prim_consp),
      eval = Sexpr.newFun("eval", Lisp.prim_eval),
      load = Sexpr.newFun("load", Lisp.prim_load),
      echo = Sexpr.newFun("echo", Lisp.prim_echo),
      defmacro = Sexpr.newFun("defmacro", Lisp.prim_defmacro,
			      "lazy"),
      ["if"] = Sexpr.newFun("if", Lisp.prim_if, "lazy")
   }
end

function Lisp.getGlobalEnv()
   local env =  Env.new(Lisp.getPrimitiveScope())
   -- Run the prelude
   Lisp.runFile(env, "Prelude.lsp")
   return env
end

function Lisp.runFile(env, filename)
   -- Read the file
   local file = io.open(filename, "r")
   local code = file:read("*all")
   local lastValue = Lisp.evalExpr(env, code)
   file:close()
   return lastValue
end

-- The top read-eval loop...

function Lisp.readEval()
   local env = Lisp.getGlobalEnv()
   local line
   repeat
      io.write("> ")
      line = io.read()
      if line and not line ~= ":q" then
	 local ok
	 local value
	 ok, value = pcall(Lisp.evalExpr, env, line)
	 if ok then
	    if value then
	       print(Sexpr.prettyPrint(value))
	    end
	 else
	    print("#error: ", value)
	 end
      end
   until not line or line == ":q"
end

-- This software is licensed under the M.I.T. license.
-- The license text is found in "license.txt"
--
-- Sexpr.lua
-- Author: David Bergman
--
-- Deals with (unevaluated or not) S-expressions, which are simply
-- atoms or CONS cells
--
-- The atoms are either
-- 1. Literals (t or nil)
-- 2. Numericals
-- 3. Operators [',`] 
-- 4. Symbols
-- 5. Function references

Sexpr = {}

Sexpr.constants = { ["t"] = true, ["nil"] = true }
Sexpr.mt = {}
function Sexpr.mt.__tostring(expr)
   local str
   if expr.type == "CONS" then
      str = "(" .. tostring(expr.car) .. " . " .. tostring(expr.cdr) .. ")"
   else
      str = "atom[type=" .. expr.type .. ", lex=\"" .. expr.lexeme .. "\"]"
   end
   return str
end

-- Atoms

function Sexpr.newBool(cond)
   local atom
   if cond then
      atom = Sexpr.newAtom("t")
   else
      atom = Sexpr.newAtom("nil")
   end
   return atom
end

function Sexpr.newString(content)
   local atom = { type="STR", lexeme=content }
   setmetatable(atom, Sexpr.mt)
   return atom
end

function Sexpr.newOperator(op)
   local type
   if op == "(" then
      type = "LEFTPAREN"
   elseif op == ")" then
      type = "RIGHTPAREN"
   else
      type = "OP"
   end
   local atom = { type=type, lexeme=op }
   setmetatable(atom, Sexpr.mt)
   return atom
end

function Sexpr.newAtom(atom)
   -- Make sure to use the string from here on
   atom = tostring(atom)
   local sexpr
   -- three cases
   if Sexpr.constants[atom] then
      -- 1. Constant
      sexpr = { type="LITERAL", lexeme=atom }
   elseif string.find(atom, "^%d+$") then
      -- 2. Numerical
      sexpr = { type="NUM", lexeme=atom }
   else
      -- 3. Symbol
      sexpr = { type="SYM", lexeme=atom }
   end
   setmetatable(sexpr, Sexpr.mt)
   return sexpr
end

-- Create a new function reference, where the
-- special parameter can be nil (for a normal function)
-- or 'lazy' for functions handling their own internal
-- evaluation, or 'macro' for functions mereley replacing
-- their body, for further evaluation
function Sexpr.newFun(name, fun, special)
   return { type="FUN", lexeme=name, fun=fun, special=special }
end 

function Sexpr:car()
   return self.car
end

function Sexpr:cdr()
   return self.cdr
end

function Sexpr.cons(a, b)
   local sexpr = { type="CONS", car = a, cdr = b } 
   setmetatable(sexpr, Sexpr.mt)
   return sexpr
end


-- Pretty printer

function Sexpr.prettyPrint(sexpr, inList)
   local pretty
   if sexpr.type == "CONS" then
      local str = {}
      -- If we are inside a list, we skip the initial
      -- '('
      if inList then
	 table.insert(str, " ")
      else
	 table.insert(str, "(")
      end
      table.insert(str, Sexpr.prettyPrint(sexpr.car))      
      
      -- Pretty print the CDR part in list mode
      table.insert(str, Sexpr.prettyPrint(sexpr.cdr, true))
      
      -- Close with a ')' if we were not in a list mode already
      if not inList then
	 table.insert(str, ")")
      end
      pretty = table.concat(str)
   else
      local str = {}
      if inList and
	 (sexpr.type ~= "LITERAL" or sexpr.lexeme ~= "nil") then
	 table.insert(str, " . ")
      end
      if sexpr.type == "FUN" then
	 if sexpr.special == "macro" then
	    table.insert(str, "#macro'")
	 else
	    table.insert(str, "#'")
	 end
      end
      -- We just add the lexeme, unless we are a nil in the
      -- end of a list...
      if not inList or sexpr.type ~= "LITERAL" or
	 sexpr.lexeme ~= "nil" then
	 if sexpr.type == "STR" then
	    table.insert(str, "\"")
	 end
	 table.insert(str, sexpr.lexeme)
	 if sexpr.type == "STR" then
	    table.insert(str, "\"")
	 end
      end
      pretty = table.concat(str)
   end
   return pretty
end

			 

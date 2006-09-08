-- This software is licensed under the M.I.T. license.
-- The license text is found in "license.txt"
--
-- Parser.lua
-- Author: David Bergman
-- 
-- A Scheme parser
--

require "Sexpr"

Parser = {
   operators = { ["("] = true, [")"] = true, [","] = true,
      ["'"] = true, ["`"] = true, ["."] = true }
}

-- Parse the code snippet, yielding a list of (unevaluated) S-expr
function Parser.parseSexpr(expr)
   local tokenList = Parser.parseTokens(expr)
   local expr
   local next = 1
   local sexprList = {}
   repeat
      next, sexpr = Parser.createSexpr(tokenList, next)
      if sexpr then
	 table.insert(sexprList, sexpr)
      end
   until not sexpr
   return sexprList
end

function Parser.createSexpr(tokens, start)
   -- If the first token is a '(', we should expect a "list"
   local firstToken = tokens[start]
   if not firstToken then
      return start, nil
   end
   if firstToken.type == "LEFTPAREN" then
      return Parser.createCons(tokens, start+1)
   elseif firstToken.type == "OP" then
      local next, cdr = Parser.createSexpr(tokens, start+1)
      return next, Sexpr.cons(firstToken, cdr)
   else
      return start+1, firstToken
   end
end

function Parser.createCons(tokens, start)   
   -- If the first token is a '.', we just return the second token,
   -- as is,
   -- while skipping a subsequent ')',
   -- else if it is a ')' we return NIL, else
   -- we get the first Sexpr and CONS it with the rest

   local firstTok = tokens[start]
   if not firstTok then
      error("Token index " .. start ..
	    " is out of range when creating CONS S-Expr", 2)
   end
   if firstTok.type == "OP" and firstTok.lexeme == "." then
      -- We skip the last ')'
      local next, cdr = Parser.createSexpr(tokens, start+1)      
      if not tokens[next] or tokens[next].type~="RIGHTPAREN" then
	 error("The CDR part ending with " .. tokens[next-1].lexeme ..
	       " was not followed by a ')'")
      end
      return next+1, cdr
   elseif firstTok.type == "RIGHTPAREN" then
      return start+1, Sexpr.newAtom("nil")
   else
      local next, car = Parser.createSexpr(tokens, start)
      local rest, cdr = Parser.createCons(tokens, next)
      return rest, Sexpr.cons(car, cdr)
   end
end

-- Parse a sub expression, returning both an expression and
-- the index following this sub expression 
function Parser.parseTokens(expr)
   tokens = {}

   -- We do it character by character, using queues to
   -- handle strings as well as regular lexemes

   local currentToken = {}
   local inString = false
   local isEscaping = false
   for i = 1, string.len(expr) do
      local c = string.sub(expr, i, i)
      -- We have seven (7) main cases:
      if isEscaping then
	 -- 1. Escaping this character, whether in a string
	 -- or not
	 --
	 table.insert(currentToken, c)	    
	 isEscaping = false
      elseif c == "\\" then
	 -- 2. An escape character
	 --
	 isEscaping = true
      elseif c == "\""  then
	 -- 3. A quotation mark
	 --
	 -- Two sub cases:
	 if not inString then
	    -- a. starting a new string
	    -- If we already had a token, let us finish that
	    -- up first
	    if table.getn(currentToken) > 0 then
	       table.insert(tokens,
			Sexpr.newAtom(table.concat(currentToken)))
	    end
	    currentToken = {}
	    inString = true
	 else
	    -- b. ending a string
	    table.insert(tokens,
		Sexpr.newString(table.concat(currentToken)))
	    currentToken = {}
	    inString = false
	 end	
      elseif inString then
	 -- 4. inside a string, so just add the character
	 --
	 table.insert(currentToken, c)
      elseif Parser.operators[c] then
	 -- 5. special operator (and not inside string)
	 --
	 -- We add any saved token
	 if table.getn(currentToken) > 0 then
	    table.insert(tokens,
		Sexpr.newAtom(table.concat(currentToken)))
	    currentToken = {}
	 end
	 table.insert(tokens, Sexpr.newOperator(c))
      elseif string.find(c, "%s") then
	 -- 6. A blank character, which should add the current
	 -- token, if any
	 -- 
	 if table.getn(currentToken) > 0 then
	    table.insert(tokens,
		Sexpr.newAtom(table.concat(currentToken)))
	    currentToken = {}
	 end
      else
	 -- 7. A non-blank character being part of the a symbol
	 --
	 table.insert(currentToken, c)
      end
   end
   -- Add any trailing token...
   if table.getn(currentToken) > 0 then
      local atom
      if inString then
	 atom = Sexpr.newString(table.concat(currentToken))
      else
	 atom = Sexpr.newAtom(table.concat(currentToken))
      end
      table.insert(tokens, atom)
   end
   return tokens
end



-- This software is licensed under the M.I.T. license.
-- The license text is found in "license.txt"
--
-- Token.lua
-- 
-- Tokens, which are unevaluated atoms, list delimiters or special
-- operators
--

Token = {}

function Token.newString(str)
   return { .token="STR", .lexeme=str }
end

function Token.newLeftParen()
   return { .token="LEFTPAREN", .lexeme="(" }
end

function Token.newRightParen()
   return { .token="RIGHTPAREN", .lexeme=")" }
end

function Token.newComma()
   return { .token="COMMA", .lexeme=")" }
end

function Token.newQuote()
   return { .token="QUOTE", .lexeme"'" }
end
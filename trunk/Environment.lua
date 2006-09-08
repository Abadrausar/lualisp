-- This software is licensed under the M.I.T. license.
-- The license text is found in "license.txt"
--
-- Environment class
-- Author: David Bergman
-- Env.new : Creating a new environment
-- env[symbol] : lookup symbol (i.e., symbol:lookup(symbol) )
-- Env:lookup : lookup symbol
-- Env:addScope : add local scope

Env = { }

-- Lookup a symbol, going from the most local to the most
-- global scope
function Env:lookup(symbol)
   for i = self.scopeCount, 1, -1 do
      local tab = self.scopes[i]
      local val = tab[symbol]
      if val then
	 return val
      end
   end
   return nil
end

-- Add a new key or change an existing one in the most
-- local scope
function Env:add(key, value)
   self.scopes[self.scopeCount][key] = value
   return self.scopes[self.scopeCount][key]
end

-- Create a string representation of the environment
function Env:tostring()
   local str = {}
   table.insert(str, "Environment[scopeCount=" ..
		self.scopeCount .. "\n")
   for _, scope in ipairs(self.scopes) do
      table.insert(str, "Scope[")
      for key, value in pairs(scope) do
	 table.insert(str, tostring(key))
	 table.insert(str, "=")
	 table.insert(str, tostring(value))
	 table.insert(str, " ")
      end
      table.insert(str, "]\n")
   end
   table.insert(str, "]")
   return table.concat(str)
end

function Env:addBindings(formalList, actualList)
   local localScope = {}
   Env.bind(localScope, formalList, actualList)
   return self:addLocalScope(localScope)
end

function Env.bind(scope, formalList, actualList)
   if formalList.type=="CONS" then
      scope[formalList.car.lexeme] = actualList.car
      Env.bind(scope, formalList.cdr, actualList.cdr)
   end      
end

-- Create local scope and return new extended environment
function Env:addLocalScope(localScope)
   -- Add a new empty local scope
   local newScopes = {}
   for _, scope in ipairs(self.scopes) do
      table.insert(newScopes, scope)
   end
   table.insert(newScopes, localScope)
   local newEnv = { scopeCount = self.scopeCount + 1,
      scopes = newScopes,
      add = Env.add, addBindings = Env.addBindins,
      addLocalScope=Env.addLocalScope }
    setmetatable(newEnv, Env.mt)
    return newEnv
end

Env.mt = {
   __index = Env.lookup,
   __newindex = Env.add,
   __tostring = Env.tostring
}

function Env.new(initialScope)
   -- The scopes are stored from most global to most local
   local env =  { scopeCount = 1, scopes = {initialScope},
      add = Env.add,
      addBindings = Env.addBindings,
      addLocalScope = Env.addLocalScope,
      lookup=Env.lookup }
   setmetatable(env, Env.mt)
   return env
end
   


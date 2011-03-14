math.randomseed(os.time())

--------------------------------------------------
--- Die ------------------------------------------
--------------------------------------------------

Die = { prototype = {}, mt = {} }
Die.mt.__index = Die.prototype

function Die.mt.__tostring(self)
   local str = "d" .. self.sides
   if self.value then str = str .. "(" .. self.value .. ")" end
   return str
end

function Die.mt.__eq(d1, d2)
   return d1.sides == d2.sides and
	  d1.value == d2.value
end

function Die.prototype.roll(self)
   self.value = math.random(self.sides)
end

function Die.prototype.clone(self)
   return D(self.sides, self.value)
end

function Die.new(sides, value)
   local die = {sides = sides, value = value}
   setmetatable(die, Die.mt)
   return die
end

D = Die.new

--------------------------------------------------
--- Array utils ----------------------------------
--------------------------------------------------

array = {}
array.__index = function(tbl, fn)
				   return rawget(tbl,fn) or array[fn] or table[fn]
				end

setmetatable(array, { __call = function(array, tbl)
								  if not tbl then tbl = {} end
								  setmetatable(tbl, array)
								  return tbl
							   end })

function array.map(tbl, fn)
   local ret = array{}
   for i = 1, #tbl do
	  ret[i] = fn(tbl[i], i)
   end
   return ret
end

function array.__eq(t1, t2)
   local size = #t1
   if #t2 ~= size then return false end
   for i = 1, size do
	  if t1[i] ~= t2[i] then return false end
   end
   return true
end

function array.inject(tbl, fn)
   local val = tbl[1]
   local i = 2

   while i <= #tbl do
	  val = fn(val, tbl[i])
	  i = i + 1
   end

   return val
end

function array.select(tbl, fn)
   local selected = array{}
   tbl:map(function(e)
			  if fn(e) then selected:insert(e) end
		   end)
   return selected
end

function array.compact(tbl)
   return tbl:select(function(e) return e ~= nil end)
end

function array.any(tbl, fn)
   for i = 1, #tbl do
	  if fn(tbl[i]) then return true end
   end
   return false
end

function array.all(tbl, fn)
   for i = 1, #tbl do
	  if not fn(tbl[i]) then return false end
   end
   return true
end

function array.find(tbl, fn)
   for i = 1, #tbl do
	  if fn(tbl[i]) then return i, tbl[i] end
   end
   return nil
end

--------------------------------------------------
--- Dice Pool ------------------------------------
--------------------------------------------------

Pool = { prototype = {}, mt = {} }
Pool.mt.__index = function(tbl, fn)
					 return rawget(tbl, fn) or
					 Pool.prototype[fn] or
					 array.__index(tbl,fn)
				  end

Pool.mt.__tostring = function(self)
						return "[" .. self:map(tostring):concat(", ") .. "]"
					 end

Pool.mt.__eq = array.__eq

setmetatable(Pool.mt, getmetatable(array))

function Pool.new(number, die)
   local dice = {}
   setmetatable(dice, Pool.mt)

   if number and die then
	  if type(die) == "number" then die = D(die) end
	  for i = 1, number do dice:insert(die:clone()) end
   end

   return dice
end

function Pool.prototype.insert(pool, die)
   if getmetatable(die) ~= Die.mt then
	  error("Can only insert dice into a dice pool")
   else
	  pool[#pool + 1] = die
	  return pool
   end
end

function Pool.prototype.roll(pool)
   pool:map(Die.prototype.roll)
end

function Pool.prototype.clone(pool)
   local dice = pool:map(Die.prototype.clone)
   setmetatable(dice, Pool.mt)
   return dice
end

function Pool.prototype.values(pool)
   return pool:map(function(d) return d.value end)
end

--------------------------------------------------
--- Dice pool matchers ---------------------------
--------------------------------------------------

-- Returns true if a pool matches a pattern of dice values
-- Patterns are tables that contain numbers and strings.
-- All dice matched to equal strings must have equal values,
-- for example:
-- Pattern {"a", "a", "b", "b"}
-- would match the pools:
-- {1, 1, 3, 3}, {2, 2, 2, 2, 5}, {3, 3, 3, 4, 4}
-- but not the pools:
-- {1, 2, 3, 4}, {1, 1, 2}
function Pool.prototype.matches(pool, pattern)
   if #pool < #pattern then return false end
   if not pool:all(function(d) return d.value end) then error("All dice must have values") end
   pool = pool:clone()

   -- val(n) makes a predicate that checks if a die's value == v
   local val = function(v) return function(d) return d.value == v end end

   -- First go through and strip out all the constant ones
   local stripped_pattern = array{}
   for pi = 1, #pattern do
	  if type(pattern[pi]) == "number" then
		 local idx = pool:find(val(pattern[pi]))
		 if idx then pool:remove(idx)
		 else return false end -- Couldn't match this die, failed.
	  else
		 stripped_pattern:insert(pattern[pi])
	  end
   end

   -- We only had constant values, so we're done
   if #stripped_pattern == 0 then return true end

   -- Takes a table and returns a list of the sizes of groups, in descending order:
   -- {1, 2, 1, 1, 3} ==> {3, 1, 1}
   local function counts(tbl)
	  local g = {} -- Map from tbl element to count of that element
	  local c = {} -- Value set of g

	  for k,v in ipairs(tbl) do
		 g[v] = g[v] or 0 ; g[v] = g[v] + 1
	  end

	  for k,v in pairs(g) do table.insert(c,v) end
	  table.sort(c, function(a,b) return a > b end)
	  return c
   end

   local pattern_counts = counts(stripped_pattern)
   local dice_counts = counts(pool:values())

   -- table.sort(pattern_counts, function(a,b) return a > b end)

   for i = 1, #pattern_counts do
	  if #dice_counts == 0 then return false end -- Out of dice, not out of pattern
	  table.sort(dice_counts, function(a,b) return a > b end)

	  if pattern_counts[i] > dice_counts[1] then
		 -- Group is more than largest set of dice
		 return false
	  else
		 -- Assign dice from the largest dice group
		 dice_counts[1] = dice_counts[1] - pattern_counts[i]
		 -- Remove that group if it's empty
		 if dice_counts[1] == 0 then table.remove(dice_counts, 1) end
	  end
   end

   return true
end
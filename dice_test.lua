require("dice")

test("D should make a die",
	 function()
		local d = D(6)
		assert(d ~= nil)
	 end)

test("D should set the sides for the die",
	function()
		local d = D(6)
		assert(d.sides == 6)
	end)

test("D should set the value if you pass two args",
	function()
		local d = D(6, 3)
		assert(d.value == 3)
	end)

test("D:roll should randomize the value",
	function()
		local d = D(6, 10) -- Use an invalid value so we can see it change
		d:roll()
		assert(d.value >= 1 and d.value <= 6)
	end)

test("tostring should work on a die",
	 function()
		local d1, d2 = D(6),  D(6,3)
		assert(tostring(d1) == "d6")
		assert(tostring(d2) == "d6(3)")
	 end)

--------------------------------------------------
--- Array utilities ------------------------------
--------------------------------------------------

test("map should work",
	 function()
		local a = array{2, 3, 4}
		local a2 = a:map(function(n) return n * n end)
		assert(a2 == array{4, 9, 16})
		assert(a == array{2, 3, 4})
	 end)

test("inject should work",
	 function()
		local add = function(a,b) return a+b end
		local a = array{1, 3, 7}
		assert(11 == a:inject(add))
		-- Test again with one element
		assert(5 == array{5}:inject(add))
		-- Test with empty array
		assert(nil == array{}:inject(add))
	 end)

test("select should work",
	 function()
		local odd = function(n) return n % 2 == 1 end
		assert(array{1,2,3}:select(odd) == array{1,3})
		assert(array{}:select(odd) == array{})
		assert(array{2,4,6}:select(odd) == array{})
	 end)

test("compact should work",
	 function()
		assert(array{1, nil, 3}:compact() == array{1,3})
		assert(array{1, 2, 3}:compact() == array{1,2,3})
		assert(array{nil, nil}:compact() == array{})
		assert(array{}:compact() == array{})
	 end)

test("find should work",
	 function()
		local a = array{2, 3, 4}
		local a2 = array{2, 4, 6}
		local odd = function(n) return n % 2 == 1 end
		local idx, el = a:find(odd)

		assert(idx == 2)
		assert(el == 3)
		assert(not a2:find(odd))
	 end)

--------------------------------------------------
--- Dice pool ------------------------------------
--------------------------------------------------

test("dice pools can be created",
	 function()
		local dp = Pool.new(3, D(6))
		local dp2 = Pool.new(3, 6)
		assert(#dp == 3)
		assert(dp == dp2)
	 end)

test("can't insert non-dice into a pool",
	 function()
		local dp = Pool.new()
		local bad = function() dp:insert("not a die") end
		assert(not pcall(bad))
	 end)

test("can roll a dice pool",
	 function()
		local dp = Pool.new(5, 10)
		dp:roll()
		assert(dp:all(function(d) return d.value >= 1 and d.value <= 10 end))
	 end)

test("can clone a dice pool",
	 function()
		local dp = Pool.new(1, 10)
		local dp2 = dp:clone()
		dp[1].value = 1
		dp2[1].value = 2
		assert(dp ~= dp2)
	 end)

--------------------------------------------------
--- Dice pool matches ----------------------------
--------------------------------------------------

test("can match a pool of just constant values",
	 function()
		local p1 = Pool.new(5, D(6))
		local p2 = p1:clone()

		p1:map(function(d,i) d.value = i end)
		p2:map(function(d) d.value = 2 end)

		assert(p1:matches{1, 2, 3, 4, 5})
		assert(p1:matches{3, 2, 5, 4, 1})
		assert(p1:matches{3, 1, 4})

		assert(p2:matches{2, 2, 2})
		assert(p2:matches{2, 2, 2, 2, 2})

		assert(not p1:matches{1, 1})
		assert(not p1:matches{6})
		assert(not p1:matches{1, 2, 3, 4, 5, 6})
		assert(not p2:matches{1})
	 end)

test("can match a pool with placeholders",
	 function()
		local p1 = Pool.new(5, D(6))
		local p2 = p1:clone()

		p1[1].value = 1
		p1[2].value = 1
		p1[3].value = 2
		p1[4].value = 2
		p1[5].value = 2

		p2:map(function(d) d.value = 3 end)

		local p3 = p1:clone()
		p3[4].value = 3
		p3[5].value = 4

		assert(p1:matches{"a"})
		assert(p1:matches{"a", "a"})
		assert(p1:matches{"a", "a", "a", "b", "b"})
		assert(p1:matches{2, 2, "a", "b", "b"})
		assert(not p1:matches{2, 2, "b", "b", "b"})
		assert(p1:matches{"a", "a", "b", "b", 2})
		assert(not p1:matches{"a", "a", "b", "b", 1})
		assert(p1:matches{"a", "a", "b", "b", "c"})
		assert(p1:matches{"a", "a", "b", "b"})

		assert(p2:matches{"a", "a", "a", "a", "a"})
		assert(p2:matches{"a", "a", "b", "b", 3})
		assert(p2:matches{"a", "a", "b", "b", "b"})
		assert(p2:matches{"a", "b", "c", "d", "e"})
		assert(not p2:matches{"a", "a", "a", "a", "a", "a"})
		assert(not p2:matches{"a", "b", "c", "d", "e", "f"})
		assert(not p2:matches{"a", "b", "c", "d", "e", 2})
		assert(not p2:matches{"a", 2})

		assert(p3:matches{"a", "a"})
		assert(not p3:matches{"a", "a", "a"})
		assert(p3:matches{"a", "a", "b"})
	 end)
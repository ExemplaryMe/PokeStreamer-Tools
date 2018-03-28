-- local mdbg = require("mobdebug")
-- mdbg.start()
-- Based on the Pokemon gen 4 lua script by MKDasher
-- Modified by EverOddish for automatic image updates
-- Modified by dfoverdx for using a NodeJS server for automatic image updates and SoulLink
-----------
-- 1 = Diamond/Pearl, 2 = HeartGold/SoulSilver, 3 = Platinum, 4 = Black, 5 = White, 6 = Black 2, 7 = White 2
local game = 2

-- 1 = Diamond, HeartGold, Platinum, Black, white, Black 2, White 2
-- 2 = Pearl, SoulSilver
local subgame = 2

-- Set this to true if you and a partner are doing a SoulLink run (this will additionally access information in Bill's 
-- 	  PC).  If you are using a version other than HeartGold/SoulSilver, see the note below.
local run_soul_link = true

local print_debug_messages = false

-- Currently the memory address of Bill's PC are unknown for all versions but HeartGold/SoulSilver
-- This value is required for playing SoulLinked
-- If you would like to be able to detect what Pokemon are stored in boxes:
-- 	  • temporarily set this value to true
-- 	  • go to a PC and open up Bill's PC (don't yet deposit the pokemon)
-- 	  • run this script in DeSmuME
-- 	      • it will print out the first 0x40 bytes of the first member of your party
-- 	      • copy the value between the dashed lines
-- 	      • open up find_memory_address_gen4_gen5.lua in a text editor
-- 	      • paste the value in the "needle = " line (overwriting the current numeric values) and save the file
--        • set print_first_pokemon_bytes back to false in auto_layout_gen4_gen5.lua
-- 	  • stop running this script in DeSmuMe
-- 	  • deposit your first pokemon into Bill's PC in Box 1
-- 	  • open and run find_memory_address_gen4_gen5.lua in DeSmuMe
-- 	  • copy the outputed value (it should look like 0x02XXXXXX)
-- 	  • open auto_layout_gen4_gen5_tables.lua
-- 	  • replace the proper "nil" value with the value outputed from the script and save
-- Now you should be able to run auto_layout_gen4_gen5.lua  
-- If you want to help other players out, post the value (and which game you're using) in the 
--    dxdt#pokemon-streamer-tools Discord channel (https://discord.gg/FKDntWR), and I will add it to the github repo
local print_first_pokemon_bytes = false
-----------

local print_debug = require("print_debug")
print_debug = print_debug(print_debug_messages)
local debug_current_slot
local first_pokemon_bytes_by_level = {}
local num_loops = 0

local Pokemon = require("pokemon")
dofile "send_data_to_server.lua"
dofile "pokemon_name_to_pokedex_id.lua"

local gen

local pointer
local pidAddr
local pid = 0
local trainerID, secretID, lotteryID
local shiftvalue
local checksum = 0
local in_battle = false

local mode = 1
local modetext = "Party"
local submode = 1
local modemax = 5
local submodemax = 6
local tabl = {}
local prev = {}

local leftarrow1color, rightarrow1color, leftarrow2color, rightarrow2color

local delta_boxes = {}
local last_boxes = {}
for i = 1, 18 do
	last_boxes[i] = nil
end

local need_to_read_boxes = false
local last_box_check = 0
local check_box_frequency = 5 -- seconds

local last_party = {}
local first_run = true
local last_check = 0
local is_zero_hp = {}

local prng
local is_shiny

--BlockA
local pokemonID = 0
local heldItem = 0
local OTID, OTSID
local friendship_or_steps_to_hatch
local ability
local hpev, atkev, defev, speev, spaev, spdev
local evs = {}

--BlockB
local move = {}
local movepp = {}
local hpiv, atkiv, defiv, speiv, spaiv, spdiv
local ivspart = {}, ivs
local isegg
local byte0x40
local is_female
local alternate_form
local nat
local isnicknamed, nickname

local bnd,br,bxr=bit.band,bit.bor,bit.bxor
local rshift, lshift=bit.rshift, bit.lshift
local mdword=memory.readdwordunsigned
local mword=memory.readwordunsigned
local mbyte=memory.readbyteunsigned

--BlockD
local location_met
local pkrs
local level_met

--currentStats
local level, hpstat, maxhpstat, atkstat, defstat, spestat, spastat, spdstat
local currentFoeHP = 0

local hiddentype, hiddenpower

--offsets
local BlockAoff, BlockBoff, BlockCoff, BlockDoff

local first_pokemon_bytes

dofile "auto_layout_gen4_gen5_tables.lua"

local xfix = 10
local yfix = 10
function displaybox(a,b,c,d,e,f)
	gui.box(a+xfix,b+yfix,c+xfix,d+yfix,e,f)
end

function display(a,b,c,d)
	gui.text(xfix+a,yfix+b,c, d)
end

function drawarrowleft(a,b,c)
	gui.line(a+xfix,b+yfix+3,a+2+xfix,b+5+yfix,c)
	gui.line(a+xfix,b+yfix+3,a+2+xfix,b+1+yfix,c)
	gui.line(a+xfix,b+yfix+3,a+6+xfix,b+3+yfix,c)
end

function drawarrowright(a,b,c)
	gui.line(a+xfix,b+yfix+3,a-2+xfix,b+5+yfix,c)
	gui.line(a+xfix,b+yfix+3,a-2+xfix,b+1+yfix,c)
	gui.line(a+xfix,b+yfix+3,a-6+xfix,b+3+yfix,c)
end

function mult32(a,b)
	local c=rshift(a,16)
	local d=a%0x10000
	local e=rshift(b,16)
	local f=b%0x10000
	local g=(c*f+d*e)%0x10000
	local h=d*f
	local i=g*0x10000+h
	return i
end

function getbits(a,b,d)
	return rshift(a,b)%lshift(1,d)
end

function gettop(a)
	return(rshift(a,16))
end

function menu()
	tabl = input.get()
	leftarrow1color = "white"
	leftarrow2color = "white"
	rightarrow1color = "white"
	rightarrow2color = "white"
	if tabl["1"] and not prev["1"] then
		game = game + 1
		if game == 8 then
			game = 1
		end
	end
	if tabl["7"] then
		leftarrow2color = "yellow"
	end
	if tabl["8"] then
		rightarrow2color = "yellow"
	end
	if tabl["3"] then
		leftarrow1color = "yellow"
	end
	if tabl["4"] then
		rightarrow1color = "yellow"
	end
	if tabl["7"] and not prev["7"] and mode < 5 then
		submode = submode - 1
		if submode == 0 then
			submode = submodemax
		end
	end
	if tabl["8"] and not prev["8"] and mode < 5 then
		submode = submode + 1
		if submode == submodemax + 1 then
			submode = 1
		end
	end
	if tabl["3"] and not prev["3"] then
		mode = mode - 1
		if mode == 0 then
			mode = modemax
		end
	end
	if tabl["4"] and not prev["4"] then
		mode = mode + 1
		if mode == modemax + 1 then
			mode = 1
		end
	end
	if tabl["0"] and not prev["0"] then
		if yfix == 10 then
			yfix = -185
		else
			yfix = 10
		end
	end
	prev = tabl
	if mode == 1 then
		modetext = "Party"
	elseif mode == 2 then
		modetext = "Enemy"
	elseif mode == 3 then
		modetext = "Enemy 2"
	elseif mode == 4 then
		modetext = "Partner"
	else -- mode == 5
		modetext = "Wild"
	end
end

function getGen()
	if game < 4 then
		return 4
	else
		return 5
	end
end

function getGameName()
	local gameNames = {
		{ "Diamond", "Pearl" },
		{ "HeartGold", "SoulSilver" },
		"Platinum",
		"Black",
		"White",
		"Black 2",
		"white 2"
	}

	if game < 3 then
		return gameNames[game][subgame]
	else
		return gameNames[game]
	end
end

function getPointer()
	if game == 1 then
		return memory.readdword(0x02106FAC)
	elseif game == 2 then
		return memory.readdword(0x0211186C)
	else -- game == 3
		return memory.readdword(0x02101D2C)
	end
	-- haven't found pointers for BW/B2W2, probably not needed anyway.
end

function getCurFoeHP()
	if game == 1 then -- Pearl
		if mode == 4 then -- Partner's hp
			return memory.readword(pointer + 0x5574C)
		elseif mode == 3 then -- Enemy 2
			return memory.readword(pointer + 0x5580C)
		else
			return memory.readword(pointer + 0x5568C)
		end
	elseif game == 2 then --Heartgold
		if mode == 4 then -- Partner's hp
			return memory.readword(pointer + 0x56FC0)
		elseif mode == 3 then -- Enemy 2
			return memory.readword(pointer + 0x57080)
		else
			return memory.readword(pointer + 0x56F00)
		end
	else--if game == 3 then --Platinum
		if mode == 4 then -- Partner's hp
			return memory.readword(pointer + 0x54764)
		elseif mode == 3 then -- Enemy 2
			return memory.readword(pointer + 0x54824)
		else
			return memory.readword(pointer + 0x546A4)
		end
	end
end

function getPidAddr()
	if game == 1 then --Pearl
		enemyAddr = pointer + 0x364C8
		if mode == 5 then
			return pointer + 0x36C6C
		elseif mode == 4 then
			return memory.readdword(enemyAddr) + 0x774 + 0x5B0 + 0xEC*(submode-1)
		elseif mode == 3 then
			return memory.readdword(enemyAddr) + 0x774 + 0xB60 + 0xEC*(submode-1)
		elseif mode == 2 then
			return memory.readdword(enemyAddr) + 0x774 + 0xEC*(submode-1)
		else
			return pointer + 0xD2AC + 0xEC*(submode-1)
		end
	elseif game == 2 then --HeartGold
		enemyAddr = pointer + 0x37970
		if mode == 5 then
			return pointer + 0x38540
		elseif mode == 4 then
			return memory.readdword(enemyAddr) + 0x1C70 + 0xA1C + 0xEC*(submode-1)	
		elseif mode == 3 then
			return memory.readdword(enemyAddr) + 0x1C70 + 0x1438 + 0xEC*(submode-1)
		elseif mode == 2 then
			return memory.readdword(enemyAddr) + 0x1C70 + 0xEC*(submode-1)
		else
			return pointer + 0xD088 + 0xEC*(submode-1)
		end
	elseif game == 3 then --Platinum
		enemyAddr = pointer + 0x352F4
		if mode == 5 then
			return pointer + 0x35AC4
		elseif mode == 4 then
			return memory.readdword(enemyAddr) + 0x7A0 + 0x5B0 + 0xEC*(submode-1)
		elseif mode == 3 then
			return memory.readdword(enemyAddr) + 0x7A0 + 0xB60 + 0xEC*(submode-1) 
		elseif mode == 2 then
			return memory.readdword(enemyAddr) + 0x7A0 + 0xEC*(submode-1) 
		else
			return pointer + 0xD094 + 0xEC*(submode-1)
		end
	elseif game == 4 then --Black
		if mode == 5 then
			return 0x02259DD8
		elseif mode == 4 then
			return 0x0226B7B4 + 0xDC*(submode-1)
		elseif mode == 3 then
			return 0x0226C274 + 0xDC*(submode-1)
		elseif mode == 2 then
			return 0x0226ACF4 + 0xDC*(submode-1)
		else -- mode 1
			return 0x022349B4 + 0xDC*(submode-1) 
		end
	elseif game == 5 then --White
		if mode == 5 then
			return 0x02259DF8
		elseif mode == 4 then
			return 0x0226B7D4 + 0xDC*(submode-1)
		elseif mode == 3 then
			return 0x0226C294 + 0xDC*(submode-1)	
		elseif mode == 2 then
			return 0x0226AD14 + 0xDC*(submode-1)
		else -- mode 1
			return 0x022349D4 + 0xDC*(submode-1) 
		end
	elseif game == 6 then --Black 2
		if mode == 5 then
			return 0x0224795C
		elseif mode == 4 then
			return 0x022592F4 + 0xDC*(submode-1)
		elseif mode == 3 then
			return 0x02259DB4 + 0xDC*(submode-1)			
		elseif mode == 2 then
			return 0x02258834 + 0xDC*(submode-1)
		else -- mode 1
			return 0x0221E3EC + 0xDC*(submode-1)
		end
	else --White 2
		if mode == 5 then
			return 0x0224799C
		elseif mode == 4 then
			return 0x02259334 + 0xDC*(submode-1)
		elseif mode == 3 then
			return 0x02259DF4 + 0xDC*(submode-1)
		elseif mode == 2 then
			return 0x02258874 + 0xDC*(submode-1)
		else -- mode 1
			return 0x0221E42C + 0xDC*(submode-1)
		end
	end
end

function getNatClr(a)
	color = "yellow"
	if nat % 6 == 0 then
		color = "yellow"
	elseif a == "atk" then
		if nat < 5 then
			color = "#0080FFFF"
		elseif nat % 5 == 0 then
			color = "red"
		end
	elseif a == "def" then
		if nat > 4 and nat < 10 then
			color = "#0080FFFF"
		elseif nat % 5 == 1 then
			color = "red"
		end
	elseif a == "spe" then
		if nat > 9 and nat < 15 then
			color = "#0080FFFF"
		elseif nat % 5 == 2 then
			color = "red"
		end
	elseif a == "spa" then
		if nat > 14 and nat < 20 then
			color = "#0080FFFF"
		elseif nat % 5 == 3 then
			color = "red"
		end
	elseif a == "spd" then
		if nat > 19 then
			color = "#0080FFFF"
		elseif nat % 5 == 4 then
			color = "red"
		end
	end
	return color
end

function read_pokemon_words(addr, num_words)
	local pid = memory.readdword(addr)
	in_battle = check_is_in_battle(addr, pid)
	local num_bytes = num_words * 2
	local bytes

	-- check that num_words > 0x88 in case we're looking at a boxed pokemon...?  doesn't make sense that this would ever
	-- happen, but doesn't hurt to check either
	if in_battle and num_bytes > 0x88 then
		-- we can get live stats for the battle stat block -- don't trust it for other things like exp
		-- bytes = memory.readbyterange(addr, 0x88)
		local battle_addr = addr + 0x4E9F0
		bytes = memory.readbyterange(battle_addr, 0x88)
		local battle_bytes = memory.readbyterange(battle_addr + 0x88, num_bytes - 0x88)
		for _, b in ipairs(battle_bytes) do
			bytes[#bytes + 1] = b
		end
	else
		bytes = memory.readbyterange(addr, num_bytes)
	end

	local words = {}

	-- PID is taken as a whole, and memory is in little-endian, so reverse the words
	words[1] = getbits(pid, 16, 16)
	words[2] = getbits(pid, 0, 16)

	for i = 5, #bytes, 2 do
		words[#words + 1] = bytes[i] + lshift(bytes[i + 1], 8)
	end

	return words
end

function do_print_first_pokemon_bytes(pidAddr)
	local byte_str = ""
	for i, b in ipairs(memory.readbyterange(pidAddr, 0x88)) do
		byte_str = byte_str .. string.format(" 0x%02x,", b)
	end

	-- first_pokemon_bytes = string.format("{ %s }", table.concat(memory.readbyterange(pidAddr, 0x27), ", "))
				
	print("---------------------------")
	print("{" .. byte_str .. " }")
	print("---------------------------")	
end

function inspect_and_send_boxes()
	need_to_read_boxes = false
	local cur_boxes = {}
	local box_offset = bills_pc_address[game][subgame]
	local last_pkmn, cur_pkmn, should_update, words

	for box = 1, 18 do
		cur_boxes[box] = {}
		for box_slot = 1, 30 do
			words = read_pokemon_words(box_offset + (box - 1) * box_size + (box_slot - 1) * box_slot_size, 136)
			if last_boxes[box] == nil or Pokemon.get_words_string(words) ~= last_boxes[box].data_str then	
				cur_pkmn = Pokemon.parse_gen4_gen5(words, true, gen)
				
				if last_boxes[box] == nil then
					cur_boxes[box][box_slot] = cur_pkmn or Pokemon()
					if cur_pkmn ~= nil then
						delta_boxes[#delta_boxes + 1] = {
							box_id = box,
							slot_id = box_slot,
							pokemon = cur_pkmn
						}
					end
				else
					last_pkmn = last_boxes[box][box_slot]
					if cur_pkmn ~= nil and cur_pkmn ~= last_pkmn then
						cur_boxes[box][box_slot] = cur_pkmn
						delta_boxes[#delta_boxes + 1] = {
							box_id = box,
							slot_id = box_slot,
							pokemon = cur_pkmn
						}
					else
						cur_boxes[box][box_slot] = last_pkmn
					end
				end
			end
		end
	end

	last_boxes = cur_boxes
	if #delta_boxes > 0 and not_need_to_read_boxes then
		send_slots(delta_boxes, gen, game, subgame)
		delta_boxes = {}
	end
end

function kill_pokemon(pidAddr)
	local pid = memory.readdword(pidAddr)
	local death_code, frozen_code = Pokemon.get_death_codes(pid)
	memory.writeword(pidAddr + 71 * 2, death_code)

	-- if in battle
	if memory.readdword(pidAddr + 0x4E9F0) == pid then
		pidAddr = pidAddr + 0x4E9F0
		for i = 0, 3 do
			-- memory.writebyte(pidAddr + 0x88 + (i * 0x400000), frozen_code)
			memory.writeword(pidAddr + 71 * 2 + (i * 0x400000), death_code)
		end
	end
end

-- attempt to check if in battle by comparing pid against all 4 places it seems to appear when in battle
-- far from foolproof, but slightly better than nothing
function check_is_in_battle(addr, pid)
	local battle_addr = addr + 0x4E9F0
	for i = 0, 3 do
		if memory.readdword(battle_addr + (i * 0x400000), death_code) ~= pid then
			return false
		end
	end

	return true
end

-- attempt to check if in battle by examining enemy memory
-- doesn't actually work.... may debug this later
-- function get_is_in_battle()
-- 	submode = 1
-- 	getPidAddr() -- this sets enemyAddr
-- 	local enemyWords = read_pokemon_words(enemyAddr, Pokemon.word_size_in_party)
-- 	local enemy = Pokemon.parse_gen4_gen5(enemyWords, false, gen, true)
-- 	print(enemy ~= nil)
-- end

local printed_slot_1 = false
function fn()
	--menu()
	current_time = os.clock() -- use clock() rather than time() so we can check more than once per second
	if need_to_read_boxes or run_soul_link and current_time - last_box_check > check_box_frequency then
		gen = getGen()
		inspect_and_send_boxes()
		last_box_check = current_time
	end

	if current_time - last_check > .5 then
		gen = getGen()
		pointer = getPointer()
		party = {}

		-- in_battle = get_is_in_battle()

		for q = 1, 6 do
			submode = q
			pidAddr = getPidAddr()

			if print_first_pokemon_bytes then do_print_first_pokemon_bytes(pidAddr) end

			local words = read_pokemon_words(pidAddr, Pokemon.word_size_in_party)
			
			if last_party == nil or last_party[q] == nil or in_battle or Pokemon.get_words_string(words) ~= last_party[q].data_str then
				party[q] = Pokemon.parse_gen4_gen5(words, false, gen)
			else
				party[q] = last_party[q]
			end
		end

		local send_data = {}
		if first_run then
			reset_server()
			last_party = {}
			for k, pkmn in pairs(party) do
				last_party[k] = pkmn or Pokemon() -- invalid pokemon are returned as nil from parse_gen4_gen5
				print("Slot " .. k .. ": " .. tostring(pkmn))
				send_data[#send_data + 1] = { slot_id = k, pokemon = pkmn }
			end
			first_run = false
		else
			for q = 1, 6 do
				p = party[q]
				lp = last_party[q]
				if p ~= nil then
					if lp == nil or p ~= lp then
						print("Slot " .. q .. ": " .. tostring(lp) .. " -> " .. tostring(p))
						send_data[#send_data + 1] = { slot_id = q, pokemon = p }
					end
				else
					party[q] = lp
				end
			end
			
			last_party = party
			party = {}
		end

		if (#send_data > 0) then
			send_slots(send_data, gen, game, subgame)
		end

		last_check = current_time
	end
end

gui.register(fn)
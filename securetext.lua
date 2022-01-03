VERSION = "1.0"

local micro = import("micro")
local config = import("micro/config")
local os = import("os")
local buffer = import("micro/buffer")
local util = import("micro/util")

-- getTextLoc and getText lifted from manipulator plugin
local function getTextLoc(pane)
    local a, b, c = nil, nil, pane.Cursor
    if c:HasSelection() then
        if c.CurSelection[1]:GreaterThan(-c.CurSelection[2]) then
            a, b = c.CurSelection[2], c.CurSelection[1]
        else
            a, b = c.CurSelection[1], c.CurSelection[2]
        end
    else
        local eol = string.len(pane.Buf:Line(c.Loc.Y))
        a, b = c.Loc, buffer.Loc(eol, c.Y)
    end
    return buffer.Loc(a.X, a.Y), buffer.Loc(b.X, b.Y)
end

-- Returns the current marked text or whole line
local function getText(pane, a, b)
    local txt, buf = {}, pane.Buf

    -- Editing a single line?
    if a.Y == b.Y then
        return buf:Line(a.Y):sub(a.X+1, b.X)
    end

    -- Add first part of text selection (a.X+1 as Lua is 1-indexed)
    table.insert(txt, buf:Line(a.Y):sub(a.X+1))

    -- Stuff in the middle
    for lineNo = a.Y+1, b.Y-1 do
        table.insert(txt, buf:Line(lineNo))
    end

    -- Insert last part of selection
    table.insert(txt, buf:Line(b.Y):sub(1, b.X))

    return table.concat(txt, "\n")
end

local function doEncryption(bp, password)
	local a, b = getTextLoc(bp)
	local textToEncrypt = getText(bp, a, b)
	local encryptedText, err = util.Encrypt(textToEncrypt, password)
	if err == nil then
		bp.Buf:Replace(a, b, encryptedText)
	else
		micro.InfoBar():Error("error creating cipher: ", err.String)
	end
end

local function doDecryption(bp, password)
	local a, b = getTextLoc(bp)
	local textToDecrypt = getText(bp, a, b)
	local decryptedText, err = util.Decrypt(textToDecrypt, password)
	if err == nil then
		bp.Buf:Replace(a, b, decryptedText)
	else
		micro.InfoBar():Error("error creating cipher: ", err)
	end
end

function decryptText(bp, args)
	if #args >= 1 then
		doDecryption(bp, args[1])
	else
		local params = makeParamsData(bp, "decrypt")
		micro.InfoBar():Prompt("Password: ", "", "", nil, params)
	end
end

function encryptText(bp, args)
	if #args >= 2 then
		if args[1] == args[2] then
			doEncryption(bp, args[1])
		else
			micro.InfoBar():Error("Password does not match password confirmation; text not encrypted")
		end
	else
		if #args == 1 then
			local params = makeParamsData(bp, "encrypt", args[1])
			micro.InfoBar():Prompt("Confirm password: ", "", "", nil, params)
		else
			local params = makeParamsData(bp, "encrypt")
			micro.InfoBar():Prompt("Password: ", "", "", nil, params)
		end
	end
end

function makeParamsData(bufferPane, action, password)
	local bp = bufferPane
	local action = action
	local password1 = password
	local callback = function(response)
		if #response == 0 then
			local newCallback = makeParamsData(bp, action, password1)
			micro.InfoBar():Prompt("Password cannot be empty, please re-enter: ", "", "", nil, newCallback)
		else
			if action == "decrypt" then
				-- decrypt, just need password
				doDecryption(bp, response)
			else
				-- encrypt, need password and password confirmation
				if password1 == nil then
					local newCallback = makeParamsData(bp, action, response)
					micro.InfoBar():Prompt("Confirm password: ", "", "", nil, newCallback)
				else
					if password1 == response then
						doEncryption(bp, response)
					else
						micro.InfoBar():Error("Password does not match password confirmation; text not encrypted")
					end
				end
			end
		end
	end

	return callback
end

function init()
	config.MakeCommand("decrypt", decryptText, config.NoComplete)
	config.MakeCommand("encrypt", encryptText, config.NoComplete)
end

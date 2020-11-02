local discordia = require("discordia")
local json = require("json")
local timer = require("timer")
local options = discordia.storage.options

local utils = {}

utils.s = function(n)
	return n==1 and "" or "s"
end

utils.escapePatterns = function(str)
	return str:gsub("([^%w])", "%%%1")
end

utils.createLookupTable = function(input)
	local output={}
	for _,v in pairs(input) do
		output[v]=true
	end
	return output
end

local jsonColumns=utils.createLookupTable{
	"disabled_commands",
	"disabled_modules",
	"persistent_roles",
	"command_permissions",
	"roles"
}
local booleanColumns=utils.createLookupTable{
	"delete_command_messages",
	"is_active"
}

utils.divmod = function(a, b)
	return math.floor(a/b), a%b
end

utils.secondsToTime = function(seconds)
	seconds = tonumber(seconds)
	if seconds<=0 then
		return "N/A"
	else
		local day, min, hour, sec
		min, sec = utils.divmod(seconds, 60)
		hour, min = utils.divmod(min, 60)
		day, hour = utils.divmod(hour, 24)
		local output = {}
		if day>0 then
			table.insert(output, day.." day"..utils.s(day))
		end
		if hour>0 then
			table.insert(output, hour.." hour"..utils.s(hour))
		end
		if min>0 then
			table.insert(output, min.." minute"..utils.s(min))
		end
		if sec>0 then
			table.insert(output, sec.." second"..utils.s(sec))
		end
		return table.concat(output, ", ")
	end
end

utils.formatRow = function(row)
	if type(row)~="table" then return end
	for k,v in pairs(row) do
		v=v[1]
		if jsonColumns[k] then
			v=json.decode(v)
		elseif booleanColumns[k] then
			v=v==1LL
		end
		row[k]=v
	end
	return row
end

utils.getGuildSettings = function(id, conn)
	local settings,_ = conn:exec("SELECT * FROM guild_settings WHERE guild_id="..id..";","k")
	return utils.formatRow(settings)
end

utils.sendEmbed = function(channel, text, color, footer_text, footer_icon, messageContent)
	local colorValue=color and discordia.Color.fromHex(color).value or nil
	local msg=channel:send{
		content=messageContent,
		embed={
			description=text,
			color=colorValue,
			footer={
				text=footer_text,
				icon_url=footer_icon
			}
		}
	}
	return msg
end

utils.sendEmbedSafe = function(channel, text, color, footer_text, footer_icon, messageContent)
	if not channel then return false end
	return utils.sendEmbed(channel, text, color, footer_text, footer_icon, messageContent)
end

utils.logError = function(guild, err)
	guild.client._api:executeWebhook("772712556271239188", "sEUwA9w2UZvfwOlF-cqx7TN_M0OHsssMEuIrAjb6HlS40hPnlMXQLvv_qXAgkIrkx0bo", {
		embeds = {{
			title = "Bot crashed!",
			description = "```\n"..err.."```",
			color = discordia.Color.fromHex("ff0000").value,
			timestamp = discordia.Date():toISO('T', 'Z'),
			footer = {
				text = "Guild: "..guild.name.." ("..guild.id..")"
			}
		}
	}})
end

utils.name = function(user, guild)
	local member = guild and guild:getMember(user.id)
	if member then
		return member.name~=user.name and member.name.." ("..user.tag..")" or user.tag
	end
	return user.tag
end

utils.secondsFromString = function(str)
	local timeModifiers = {
		m = 60,
		h = 3600,
		d = 86400,
		w = 604800
	}
	local seconds = 0
	for num, mod in str:gmatch("(%d+)(%a)") do
		if not (num and mod and timeModifiers[mod]) then
			num, mod = 0, 0
		else
			num, mod = tonumber(num), timeModifiers[mod]
		end
		seconds = seconds + num*mod
	end
	return seconds
end

utils.memberFromString = function(str, guild)
	local id = str:match("^%<%@%!?(%d+)%>$") or str:match("^(%d+)$")
	return id and guild:getMember(id)
end

utils.userFromString = function(str, client)
	local id = str:match("^%<%@%!?(%d+)%>$") or str:match("^(%d+)$")
	return id and client:getUser(id)
end

utils.channelFromString = function(str, client)
	local id = str:match("^%<%#(%d+)%>$") or str:match("^(%d+)$")
	return id and client:getChannel(id)
end

utils.roleFromString = function(str, guild)
	local id = str:match("^%<%@%&(%d+)%>$") or str:match("^(%d+)$")
	return id and guild:getRole(id)
end

utils.messageFromString = function(str, channel)
	local id = str:gsub("https://discord%.com/channels/%d+/%d+/",""):match("^(%d+)$")
	return id and channel:getMessage(id)
end

-- Like Emitter:waitFor, but waits for either of two events
-- If there is a timeout and it's reached, returns false; otherwise returns the name of the event that was emitted
utils.waitForAny = function(client, nameA, nameB, timeout, predicateA, predicateB)
	local thread = coroutine.running()
	local fnA, fnB

	fnA = client:onSync(nameA, function(...)
		if predicateA and not predicateA(...) then return end
		if timeout then
			timer.clearTimeout(timeout)
		end
		client:removeListener(nameA, fnA)
		client:removeListener(nameB, fnB)
		return assert(coroutine.resume(thread, nameA, ...))
	end)

	fnB = client:onSync(nameB, function(...)
		if predicateB and not predicateB(...) then return end
		if timeout then
			timer.clearTimeout(timeout)
		end
		client:removeListener(nameA, fnA)
		client:removeListener(nameB, fnB)
		return assert(coroutine.resume(thread, nameB, ...))
	end)

	timeout = timeout and timer.setTimeout(timeout, function()
		client:removeListener(nameA, fnA)
		client:removeListener(nameB, fnB)
		return assert(coroutine.resume(thread, false))
	end)

	return coroutine.yield()
end

return utils
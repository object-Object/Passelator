local commandHandler = require("commandHandler")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")

return {
	name = "code",
	description = "Displays or sets the game code/link for a group.",
	usage = "<group number> [new game code/link]",
	visible = true,
	botGuildPermissions = {},
	botChannelPermissions = {"addReactions", "manageMessages"},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		local groupNum = args[1]:gsub("#", "")
		local stmt = conn:prepare("SELECT creator_id, code, message_id FROM groups WHERE guild_id = ? AND group_num = ?;")
		local row = utils.formatRow(stmt:reset():bind(message.guild.id, groupNum):resultset("k"))
		stmt:close()
		if not row then
			utils.sendEmbed(message.channel, "Invalid group number.", "ff0000")
			return
		end

		local creator = message.client:getUser(row.creator_id)
		local newCode = argString:gsub("^"..args[1].."%s+", "")

		local promptMessage
		if #args==1 then
			-- display code
			utils.sendEmbed(message.channel, "Game code/link for Group #"..groupNum..": **"..row.code.."**", "00ff00")
			return
		elseif message.author~=creator then
			-- not the creator, ask creator to confirm/deny
			promptMessage = message:reply{
				content = creator.mentionString,
				embed = {
					description = "Only the group's creator may set the game code/link.\n"..creator.mentionString..", react :white_check_mark: to confirm, or :x: to deny, setting the game code/link for Group #"..groupNum.." to the following code: **"..newCode.."**",
					color = discordia.Color.fromHex("00ff00").value,
					footer = {
						text = "This message will expire in 15 minutes."
					}
				}
			}
			promptMessage:addReaction("✅")
			promptMessage:addReaction("❌")
			local success, reaction, userId = message.client:waitFor("reactionAdd", 900000, function(r, u) -- 900000 ms = 15 min
				return r.message.id==promptMessage.id and (
					u==creator.id and (r.emojiHash=="✅" or r.emojiHash=="❌") or
					u==message.author.id and r.emojiHash=="❌"
				)
			end)
			if not success then
				promptMessage:clearReactions()
				promptMessage:setEmbed{
					description = "Only the group's creator may set the game code/link.\nMessage expired.",
					color = discordia.Color.fromHex("ff0000").value
				}
				return
			elseif reaction.emojiHash=="❌" then
				promptMessage:clearReactions()
				if userId==creator.id then
					promptMessage:setEmbed{
						description = "Only the group's creator may set the game code/link.\nGroup creator denied setting this code.",
						color = discordia.Color.fromHex("ff0000").value
					}
				else
					promptMessage:setEmbed{
						description = "Only the group's creator may set the game code/link.\nUser cancelled setting this code.",
						color = discordia.Color.fromHex("ff0000").value
					}
				end
				return
			end
		end

		local stmt2 = conn:prepare("UPDATE groups SET code = ? WHERE guild_id = ? AND group_num = ?;")
		stmt2:reset():bind(newCode, message.guild.id, groupNum):step()
		stmt2:close()

		local groupChannel = message.guild:getChannel(guildSettings.group_channel_id)
		local groupMessage = groupChannel:getMessage(row.message_id)

		groupUtils.updateCode(groupMessage, newCode)

		if promptMessage then
			promptMessage:clearReactions()
			promptMessage:setEmbed{
				description = "The game code/link for Group #"..groupNum.." is now: **"..newCode.."**",
				color = discordia.Color.fromHex("00ff00").value
			}
		else
			utils.sendEmbed(message.channel, "The game code/link for Group #"..groupNum.." is now: **"..newCode.."**", "00ff00")
		end
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}
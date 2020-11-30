local commandHandler = require("commandHandler")
local discordia = require("discordia")
local options = discordia.storage.options

return {
	name = "contact",
	description = "Sends a message to the bot's developer. Use this command to submit feedback, give suggestions, report bugs, etc.\nImages cannot be sent. Use Imgur or a similar service to send a link to the image instead.\nThis command **is not anonymous**. Use `&prefix;contact anonymous` to send an anonymous message. Be aware that sending an anonymous bug report makes debugging more difficult.",
	usage = "<message>",
	visible = true,
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		if argString=="" then
			commandHandler.sendUsage(message.channel, guildSettings, self)
			return
		end

		message.client._api:executeWebhook(options.contactWebhook.id, options.contactWebhook.token, {
			embeds = {{
				author = {
					name = message.author.tag.." ("..message.author.id..")",
					icon_url = message.author.avatarURL
				},
				title = "Contact form submitted!",
				description = message.content, -- not using argString because it strips newlines
				color = discordia.Color.fromHex("00ff00").value,
				timestamp = discordia.Date():toISO('T', 'Z'),
				footer = {
					text = "Guild: "..message.guild.name.." ("..message.guild.id..")"
				}
			}
		}})
	end,
	subcommands = {

		anonymous = {
			name = "contact anonymous",
			description = "Sends an anonymous message to the bot's developer.\nImages cannot be sent. Use Imgur or a similar service to send a link to the image instead.\nBe aware that sending an anonymous bug report makes debugging more difficult.",
			usage = "<message>",
			permissions = nil,
			isDefaultDisabled = nil,
			onEnable = nil,
			onDisable = nil,
			run = function(self, message, argString, args, guildSettings, conn)
				if argString=="" then
					commandHandler.sendUsage(message.channel, guildSettings, self)
					return
				end

				message.client._api:executeWebhook(options.bugReportWebhook.id, options.bugReportWebhook.token, {
					embeds = {{
						title = "Anonymous contact form submitted!",
						description = message.content,
						color = discordia.Color.fromHex("00ff00").value,
						timestamp = discordia.Date():toISO('T', 'Z')
					}
				}})
			end,
			subcommands = {}
		}

	}
}
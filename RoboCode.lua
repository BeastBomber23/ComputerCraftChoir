speaker = peripheral.find("speaker")
modem = peripheral.find("modem")

note = 0

function bootloader()
	modem.open(15)
end

function playNote(instrument, volume)
	speaker.playNote(instrument, volume, note)
	redstone.setOutput("back", true)
	sleep(0.025)
	redstone.setOutput("back", false)
end

function split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

bootloader()

while true do
	event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
	result = split(message, ",")

	if result[3] == tostring(note) then
		playNote(result[1],tonumber(result[2]))
	elseif result[1] == "Distance" then
		note = senderDistance - 3
		print(note)
	end

end

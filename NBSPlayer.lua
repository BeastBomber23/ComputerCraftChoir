modem = peripheral.find("modem")
debugMode = true --Would not recomend turning on. Adds ton of info to computer console for debugging.

currentSong = ""

local notenames = {
  "F#3",
  " G3",
  "G#3",
  " A3",
  "A#3",
  " B3",
  " C4",
  "C#4",
  " D4",
  "D#4",
  " E4",
  " F4",
  "F#4",
  " G4",
  "G#4",
  " A4",
  "A#4",
  " B4",
  " C5",
  "C#5",
  " D5",
  "D#5",
  " E5",
  " F5",
  "F#5"
}

local instnames = {
  "harp",
  "basedrum",
  "snare",
  "hat",
  "guitar",
  "pling",
  "bass"
}

local NBS_MC_inst = {
  [1] = 0,
  [2] = 4,
  [3] = 1,
  [4] = 2,
  [5] = 3,
  [6] = 5,
  [7] = 6
}

--Important
id = 0
subid = 1
maxsubid = 1

song = {}

------------------|
--  Boot Loaders  |
------------------|

function bootloader1()

	print("Setting up variables")
	id = os.clock()

	local FileList = fs.list("/NBS")

	for i, file in ipairs(FileList) do 
	  print(i .. " | " .. file)
	end

	print("")
	print("Type in one of the files given above.")
	print("")

	bootloader2()

end

function bootloader2()
	currentSong = read()

	if fs.exists("/NBS/"..currentSong) then
		currentSong = "/NBS/"..currentSong
		print("Attempting to start song...")
		song = load()
		modem.open(15)

		modem.transmit(15,14,"Distance")

		yes()

	else
		print("Song dosent exist. Retry")
		if debugMode == true then
			print("Given: /NBS/"..currentSong)
		end
		bootloader2()
	end
end

function yes()

	local delay = song.delay
    local lenght = song.lenght
    local tps = 1/delay

    local row = 0

	for _,tick in ipairs(song) do
		playInstruments(id, subid, tick, song)
		row = row + 1
		sleep(delay)
	end
end

--------------|
--  Decoding  |
--------------|

local function yield()
  os.queueEvent("fake")
  os.pullEvent("fake")
end

local function readShort(file)
  return file.read() + file.read() * 256
end

local function readInt(file)
  return file.read() + file.read() * 256 + file.read() * 65536 + file.read() * 16777216
end

local function readString(file)
  local s = ""
  local len = readInt(file)
  for i = 1, len do
    local c = file.read()
    if not c then
      break
    end
    s = s..string.char(c)
  end
  return s
end

local function readNBSHeader(file)
  local header = {}
  header.lenght = readShort(file)
  header.height = readShort(file)
  header.name = readString(file)
  if header.name == "" then
    header.name = "Untitled"
  end
  header.author = readString(file)
  if header.author == "" then
    header.author = "Unknown"
  end
  header.original_author = readString(file)
  if header.original_author == "" then
    header.original_author = "Unknown"
  end
  header.description = readString(file)
  header.tempo = readShort(file) / 100
  header.autosave = file.read()
  header.autosave_duration = file.read()
  header.time_signature = file.read()
  header.minutes_spent = readInt(file)
  header.left_clicks = readInt(file)
  header.right_clicks = readInt(file)
  header.blocks_added = readInt(file)
  header.blocks_removed = readInt(file)
  header.filename = readString(file)
  return header
end

local function nextTick(file, tSong)
  local jump = readShort(file)
  for i = 1, jump - 1 do
    table.insert(tSong, {})
  end
  return jump > 0
end

local function readTick(file)
  local t = {}
  local n = 0
  local jump = readShort(file)
  while jump > 0 do
    n = n + jump
    local instrument = file.read() + 1
    if instrument > 7 then
      return nil
    end
    local note = file.read() - 33
    if note < 0 or note > 24 then
      return nil
    end
    if not t[instrument] then
      t[instrument] = {}
    end
    t[instrument][n] = note
    jump = readShort(file)
  end
  return t
end

------------|
--  Player  |
------------|


function PlayNote(id, subid, inst, note, volume)
  local mcinst = instnames[inst + 1]
  local mcnote = note - 33
  local mcvolume = volume / 200
  modem.transmit(15,14,mcinst .. ","..tostring(mcvolume)..","..tostring(mcnote))
end

function playNotes(id, subid, inst, noteTable, tSong)

  local i = 0
  local layers = tSong.layers

  for layer,note in pairs(noteTable) do
    i = i + 1
    PlayNote(id, subid, inst, note + 33, layers[layer].volume)
  end
end

function playInstruments(id, subid, instTable, tSong)

  for inst, notes in pairs(instTable) do
    playNotes(id, subid, inst - 1, notes, tSong)
  end
  
end

function load(bVerbose)
	local file = fs.open(currentSong, "rb")
	
	if bVerbose then
		print("Reading header...")
		end
		local tSong = {}
		local header = readNBSHeader(file)
		tSong.name = header.name
		tSong.author = header.author
		tSong.original_author = header.original_author
		tSong.lenght = header.lenght / header.tempo
		tSong.delay = 1 / header.tempo

		print("Succesfuly Decoded: " .. tSong.name)
		print("By: " .. tSong.original_author)

		if bVerbose then
			print("Reading ticks...")
		end
		while nextTick(file, tSong) do
		local tick, err = readTick(file, tSong)
			if tick then
				table.insert(tSong, tick)
			else
				file.close()
				return nil, err
			end

		yield()

	end
	pcall(function()
		local layers = {}
		for i=1, header.height do
			table.insert(layers, {name=readString(file), volume=file.read() + 0})
		end
		tSong.layers = layers

		local insts = {}
		for i=1, file.read() + 0 do
			table.insert(insts, {name=readString(file), file=readString(file), pitch=file.read() + 0, key=(file.read() + 0) ~= 0})
		end

		tSong.instruments = insts
	end)

	file.close()
	return tSong
end

bootloader1()

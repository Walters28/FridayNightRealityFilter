local ADDON = ...
local VERSION = "0.1.25-beta"
local PREFIX = "|cff78c8ffFNRF|r "
local MAX_ENTRIES, MAX_BYTES, MAX_TEXT = 100, 24000, 500
local CAPTURE_ENTRIES, CAPTURE_BYTES = 100, 60000
local DEFAULT_BLOCK = {
  "vote for", "vote against", "presidential election", "general election",
  "democrat party", "democratic party", "republican party", "democrats", "republicans",
  "liberal politics", "conservative politics", "left wing politics", "right wing politics",
  "political debate", "political party", "real world politics", "real life politics",
  "vote democrat", "vote republican", "donald trump", "joe biden",
  "kamala harris", "maga politics", "election day", "campaign rally",
  "british parliament",
  "breaking news", "sports score", "football game", "basketball game",
}
local DEFAULT_NAMES = {"trump", "trumper", "trumpers", "hassen"}
-- Confirmed streamer aliases from the first capture.
-- Do not infer "Rat King" or names that could identify an ordinary player.
local STREAMER_ALIASES = {"asmongold", "asmon", "asmonbald"}
local HOMOPHOBIA_TERMS = {"homophobia", "homophobic", "homophobe", "homophobes"}
local IDEOLOGY_TERMS = {
  "communism", "communist", "communists",
  "capitalism", "capitalist", "capitalists",
}
local CRUDE_CHAT = {
  "cock sucking", "anal rascism", "turd cutter", "turd clutter",
  "quiet fatty", "between the cheeks", "charge me for anal",
  "knife in your bathroom", "penis", "vagene", "pedo", "pedos",
  "pussy", "fak u",
}
-- Whole-word profanity seen in the sixth capture. Do not block harmless
-- substrings (for example, "shittake") or generic game complaints.
local PROFANITY_TERMS = {
  "shit", "ffs", "retrotrd", "wtf", "retards", "retarded", "cucked", "cuckservative",
}
-- Iran is a whole word, paired with specific real-world conflict context.
-- The pair does not turn "I ran", player names, or a country alone into a rule.
local IRAN_CONFLICT = {
  "conflict", "israel", "centcom", "centcoms", "nukes", "nuclear", "politicians",
}
local REAL_RELIGION = {
  "ai religion", "real world religion", "religious debate", "religious beliefs",
  "satanism", "satanist", "atheism", "atheist",
  "christianity", "christian", "catholicism", "catholic", "protestantism", "protestant",
  "islam", "muslim", "muslims", "judaism", "jewish", "buddhism", "buddhist",
  "hinduism", "hindu", "worship the clankers", "allahu rackbar",
}
local REAL_EDUCATION = {
  "us education system", "u s education system", "american education system",
  "education system in the us", "education system in the u s",
  "education system in america",
}
local PRONOUN_TOPICS = {
  "my pronouns are", "pronouns are", "what are your pronouns",
  "preferred pronouns", "pronoun debate", "pronoun politics",
  "gender pronouns", "identify as they them",
}
-- Viewpoint-neutral, explicit real-world gender topics. Do not match "trans"
-- alone, ordinary men/women or pronouns, or game character gender alone.
local GENDER_TOPICS = {
  "lgbt", "lgbtq", "lgbtqia", "lbgt",
  "trans woman", "trans women", "trans man", "trans men",
  "trans person", "trans people", "trans rights", "trans community",
  "transgender", "transsexual", "transphobia", "transphobic",
  "nonbinary", "non binary", "cisgender", "cis woman", "cis women",
  "cis man", "cis men", "gender identity", "gender ideology",
  "gender spectrum", "gender fluid", "genderfluid", "gender debate",
  "gender politics", "gender roles", "gender dysphoria", "gender affirming",
  "biological male", "biological female", "sex assigned at birth",
  "assigned male at birth", "assigned female at birth",
  "pronoun discourse", "pronouns in bio", "he him pronouns",
  "she her pronouns", "they them pronouns",
}
-- Explicit phrases observed in the two local 100-message reviews. These avoid
-- blocking country names, ordinary pronouns, classes, or game politics alone.
local EXPLICIT_REALWORLD = {
  "magaspam", "maga", "talking politics", "american politics", "playing politics",
  "political theater", "communist detected", "russian meatgrinder",
  "little american boy", "eu players opinions", "fat pedo", "epstein",
  "europoor", "europoors", "amerifats", "eurolosers",
  "adolf", "goy", "americans think continents", "shits his diaper",
  "the jew rubs his hands", "your men are smaller than our women",
  "draft dodging traitor", "commie plant", "right leaning",
  "lost uk and france", "get tribal white man",
  "body type one and body type two", "bone spurs xd",
  "riots in france", "rioting in france", "epsteinposting",
  "fume about politics", "political banter", "politics dictate my life",
  "joe rogan", "fox news", "hitler", "covid bad", "these protestors need to eat",
  "orange man doesnt hurt me", "victims of orange man",
  "arrested for mean facebook posts",
}
local db, log, capture
local recent, recentOrder = {}, {}
local filterRegistered = false
local stats = {callbacks = 0, eligible = 0, noRule = 0, hidden = 0,
  unreadable = 0, otherChannel = 0, lastChannel = "none",
  lastBase = "none", lastZone = "none"}

local function readable(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then return false end
  return type(value) == "string"
end

local accents = {
  ["á"]="a", ["à"]="a", ["â"]="a", ["ä"]="a", ["ã"]="a", ["å"]="a",
  ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
  ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
  ["ó"]="o", ["ò"]="o", ["ô"]="o", ["ö"]="o", ["õ"]="o",
  ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u", ["ñ"]="n", ["ç"]="c",
  ["Á"]="a", ["À"]="a", ["Â"]="a", ["Ä"]="a", ["Ã"]="a", ["Å"]="a",
  ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
  ["Í"]="i", ["Ì"]="i", ["Î"]="i", ["Ï"]="i",
  ["Ó"]="o", ["Ò"]="o", ["Ô"]="o", ["Ö"]="o", ["Õ"]="o",
  ["Ú"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u", ["Ñ"]="n", ["Ç"]="c",
}
local function normalize(value)
  if not readable(value) then return nil end
  value = value:lower()
  for accented, plain in pairs(accents) do value = value:gsub(accented, plain) end
  -- Remove chat markup and links before matching. No markup is ever executed in review.
  value = value:gsub("|c%x%x%x%x%x%x%x%x", " "):gsub("|r", " ")
  value = value:gsub("|H[^|]*|h", " "):gsub("|h", " ")
  value = value:gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return " " .. value .. " "
end

local function cleanDisplay(value)
  if not readable(value) then return "[unreadable]" end
  return value:gsub("|", " "):gsub("[%c]", " "):sub(1, MAX_TEXT)
end

local function matchRule(normalized, rules)
  if type(rules) ~= "table" then return nil end
  for _, phrase in ipairs(rules) do
    local token = normalize(phrase)
    if token and #token > 2 and normalized:find(token, 1, true) then return phrase end
  end
end

local function safeZoneID(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
  if type(value) == "number" then return value end
end

local function channelKind(name)
  if not readable(name) then return nil end
  name = name:lower():gsub("^%d+%.?%s+", "")
  if name:match("^general%s*%-") or name == "general" then return "general" end
  if name:match("^trade%s*%-") or name == "trade" then return "trade" end
end

local function channelAllowed(channel, zoneID, baseName)
  if not readable(channel) then return false end
  local name = channel:lower()
  local id = safeZoneID(zoneID)
  -- 1 and 2 are the native General and Trade zone-channel IDs. When supplied,
  -- require the name or base name to agree, avoiding lookalike custom channels.
  if id ~= nil then
    if id == 1 then return channelKind(channel) == "general" or channelKind(baseName) == "general" end
    if id == 2 then return channelKind(channel) == "trade" or channelKind(baseName) == "trade" end
    return false
  end
  -- Older clients may omit the static ID. Require a numbered English label.
  -- Both "1. General - Zone" and "1 General - Zone" are accepted.
  return name:match("^%d+%.?%s+general%s*%-") ~= nil
      or name:match("^%d+%.?%s+trade%s*%-") ~= nil
end

local function classify(message)
  local normalized = normalize(message)
  if not normalized then return nil end
  if matchRule(normalized, db.allow) then return nil end
  local custom = matchRule(normalized, db.block)
  if custom then return "custom: " .. custom end
  -- User-requested literal names override the linked-item trade exception.
  -- Padded normalized matching keeps "trumpets" visible.
  local name = matchRule(normalized, DEFAULT_NAMES)
  if name then return "default name: " .. name end
  local streamer = matchRule(normalized, STREAMER_ALIASES)
  if streamer then return "default streamer: " .. streamer end
  -- The associated guild has multiple prefixed/suffixed variants by request.
  -- Keep this substring exception specific to Olympus, after normalization.
  if normalized:find("olympus", 1, true) then
    return "default streamer guild: olympus"
  end
  -- User-requested whole word, before the linked-item trade exception.
  if normalized:find(" cuck ", 1, true) then return "default term: cuck" end
  local homophobia = matchRule(normalized, HOMOPHOBIA_TERMS)
  if homophobia then return "default term: " .. homophobia end
  local ideology = matchRule(normalized, IDEOLOGY_TERMS)
  if ideology then return "default politics: " .. ideology end
  -- The seventh capture used "Iran conflict" and "Israel" without CENTCOM.
  -- Require whole-word Iran plus real-world conflict context.
  if normalized:find(" iran ", 1, true) then
    local context = matchRule(normalized, IRAN_CONFLICT)
    if context then return "default politics: Iran and " .. context end
  end
  local crude = matchRule(normalized, CRUDE_CHAT)
  if crude then return "default non-game: " .. crude end
  local profanity = matchRule(normalized, PROFANITY_TERMS)
  if profanity then return "default profanity: " .. profanity end
  if normalized:find(" fit down ", 1, true) and
     normalized:find(" toilet ", 1, true) then
    return "default non-game: toilet remark"
  end
  -- The captured "anal [linked spell/item]" and "cock [linked spell]"
  -- lines use game links as the punchline. The link and whole word are both
  -- required so ordinary item/spell sharing and game terms remain visible.
  -- The same markers remain after the capture display sanitizer removes pipes.
  local hasGameLink = message:find("Hspell:", 1, true) or
                      message:find("Hitem:", 1, true)
  if hasGameLink and normalized:find(" anal ", 1, true) then
    return "default non-game: crude linked-game joke"
  end
  if hasGameLink and normalized:find(" cock ", 1, true) then
    return "default non-game: crude linked-game joke"
  end
  -- Explicit real-world belief terms and observed off-topic phrases are checked
  -- before the trade-link exception; merely mentioning WoW does not excuse them.
  local religion = matchRule(normalized, REAL_RELIGION)
  if religion then return "default religion: " .. religion end
  -- Country plus education-system context; none of these words blocks alone.
  local education = matchRule(normalized, REAL_EDUCATION)
  if education then return "default education: " .. education end
  -- A real-world country/government reference plus subversion language is
  -- required; "government" alone can describe in-game lore.
  if (normalized:find(" country s government ", 1, true) or
      normalized:find(" countrys government ", 1, true) or
      normalized:find(" national government ", 1, true)) and
     (normalized:find(" subverted ", 1, true) or
      normalized:find(" subversion ", 1, true)) then
    return "default politics: government subversion"
  end
  -- Explicit pronoun labels/debate only; ordinary he/she/they/them and
  -- male/female character discussion are left alone.
  local pronouns = matchRule(normalized, PRONOUN_TOPICS)
  if pronouns then return "default pronouns: " .. pronouns end
  local gender = matchRule(normalized, GENDER_TOPICS)
  if gender then return "default gender topic: " .. gender end
  if normalized:find(" theythem ", 1, true) then return "default pronouns: theythem" end
  if normalized:find(" they them ", 1, true) then
    local lower = message:lower()
    if lower:find("they%s*/%s*them") or lower:find("they%s*%-%s*them") or
       normalized:find(" pronoun ", 1, true) or
       normalized:find(" pronouns ", 1, true) or
       (normalized:find(" male ", 1, true) and
        normalized:find(" female ", 1, true) and
        normalized:find(" character selection ", 1, true)) then
      return "default pronouns: they/them topic"
    end
  end
  -- This observed real-world statistics rant requires several signals;
  -- Norway or ethnicity alone is not a block rule.
  if normalized:find(" norway ", 1, true) and
     normalized:find(" ethnicity ", 1, true) and
     (normalized:find(" statistics ", 1, true) or
      normalized:find(" stereotypes ", 1, true)) then
    return "default politics: Norway ethnicity statistics"
  end
  local explicit = matchRule(normalized, EXPLICIT_REALWORLD)
  if explicit then return "default real-world: " .. explicit end
  local raw = message:lower()
  if raw:find("russia%s*>%s*usa") or raw:find("vietnam%s*>%s*america") or
     raw:find("everyone%s*>%s*usa") then
    return "default politics: real-world country comparison"
  end
  if normalized:find(" americanism ", 1, true) and
     normalized:find(" human rights ", 1, true) then
    return "default politics: Americanism and human rights"
  end
  if normalized:find(" eu ", 1, true) and
     normalized:find(" biggest cucks ", 1, true) then
    return "default real-world: EU directed insult"
  end
  if normalized:find(" select they them ", 1, true) and
     normalized:find(" gender ", 1, true) then
    return "default pronouns: selecting they/them gender"
  end
  if normalized:find(" america ", 1, true) and
     normalized:find(" 4 feet tall ", 1, true) and
     normalized:find(" 100 pounds ", 1, true) then
    return "default real-world: nationality size stereotype"
  end
  if normalized:find(" russia ", 1, true) and
     (normalized:find(" frontlines ", 1, true) or
      normalized:find(" kidnapped ", 1, true)) then
    return "default politics: Russia war context"
  end
  if normalized:find(" viets ", 1, true) and
     normalized:find(" average ", 1, true) then
    return "default real-world: nationality size stereotype"
  end
  if normalized:find(" economy ", 1, true) and
     normalized:find(" soft power ", 1, true) then
    return "default politics: economy and soft power"
  end
  if normalized:find(" news headlines ", 1, true) and
     normalized:find(" no sides ", 1, true) then
    return "default politics: news headlines and sides"
  end
  -- A linked item in an explicit trade message is reliably game related.
  if message:find("|Hitem:", 1, true) and
     (normalized:find(" wts ", 1, true) or normalized:find(" wtb ", 1, true)
      or normalized:find(" wtt ", 1, true)) then return nil end
  -- Require both a real-world group reference and a specific insulting phrase.
  -- "EU" alone can be useful region/guild talk and is never a block term.
  if normalized:find(" eu people ", 1, true) and
     (normalized:find(" subserviant ", 1, true) or
      normalized:find(" subservient ", 1, true) or
      normalized:find(" limp wristed ", 1, true)) then
    return "default: EU people + insulting phrase"
  end
  local rule = matchRule(normalized, DEFAULT_BLOCK)
  if rule then return "default: " .. rule end
end

local function trimLog()
  if type(log.entries) ~= "table" then log.entries = {} end
  local kept, bytes = {}, 0
  -- Walk newest first so both caps discard old entries.
  for i = #log.entries, 1, -1 do
    local entry = log.entries[i]
    if type(entry) == "table" and type(entry.text) == "string" and
       type(entry.channel) == "string" and type(entry.reason) == "string" then
      local item = {
        time = type(entry.time) == "number" and entry.time or 0,
        channel = cleanDisplay(entry.channel):sub(1, 64),
        reason = cleanDisplay(entry.reason):sub(1, 80),
        text = cleanDisplay(entry.text),
      }
      local size = #item.text + #item.channel + #item.reason
      if #kept < MAX_ENTRIES and bytes + size <= MAX_BYTES then
        kept[#kept + 1] = item
        bytes = bytes + size
      end
    end
  end
  log.entries = {}
  for i = #kept, 1, -1 do
    log.entries[#log.entries + 1] = kept[i]
  end
end

local function record(message, channel, reason)
  local now = type(time) == "function" and time() or 0
  log.entries[#log.entries + 1] = {
    time = now,
    channel = cleanDisplay(channel):sub(1, 64),
    reason = cleanDisplay(reason):sub(1, 80),
    text = cleanDisplay(message),
  }
  trimLog()
end

local function captureSize(entry)
  return #entry.channel + #entry.text + #entry.decision + #entry.reason
end

local function sanitizeCapture()
  local kept, bytes = {}, 0
  if type(capture.entries) ~= "table" then capture.entries = {} end
  for _, entry in ipairs(capture.entries) do
    if #kept >= CAPTURE_ENTRIES then break end
    if type(entry) == "table" and type(entry.text) == "string" and
       type(entry.channel) == "string" and type(entry.reason) == "string" and
       (entry.decision == "visible" or entry.decision == "hidden") then
      local item = {
        time = type(entry.time) == "number" and entry.time or 0,
        channel = cleanDisplay(entry.channel):sub(1, 64),
        text = cleanDisplay(entry.text),
        decision = entry.decision,
        reason = cleanDisplay(entry.reason):sub(1, 80),
      }
      local size = captureSize(item)
      if bytes + size > CAPTURE_BYTES then break end
      kept[#kept + 1], bytes = item, bytes + size
    end
  end
  capture.entries, capture.bytes = kept, bytes
  if capture.state ~= "active" and capture.state ~= "completed" and capture.state ~= "stopped" then
    capture.state = "stopped"
  end
  if #kept >= CAPTURE_ENTRIES or bytes >= CAPTURE_BYTES then capture.state = "completed" end
end

local function captureMessage(message, channel, reason)
  if capture.state ~= "active" then return end
  local entry = {
    time = type(time) == "function" and time() or 0,
    channel = cleanDisplay(channel):sub(1, 64),
    text = cleanDisplay(message),
    decision = reason and "hidden" or "visible",
    reason = reason and cleanDisplay(reason):sub(1, 80) or "no matching rule",
  }
  local size = captureSize(entry)
  if #capture.entries >= CAPTURE_ENTRIES or capture.bytes + size > CAPTURE_BYTES then
    capture.state = "completed"
    return
  end
  capture.entries[#capture.entries + 1] = entry
  capture.bytes = capture.bytes + size
  if #capture.entries >= CAPTURE_ENTRIES or capture.bytes >= CAPTURE_BYTES then
    capture.state = "completed"
  end
end

local function firstCallback(message, channel, lineID)
  local now = type(GetTime) == "function" and GetTime() or
    (type(time) == "function" and time() or 0)
  local nativeID = nil
  if type(issecretvalue) ~= "function" or not issecretvalue(lineID) then
    if type(lineID) == "number" and lineID > 0 then nativeID = lineID end
  end
  local key = nativeID and ("id:" .. tostring(nativeID) .. ":" .. channel:sub(1, 80)) or
    ("text:" .. message:sub(1, MAX_TEXT) .. "#" .. #message .. "\0" .. channel:sub(1, 80))
  local previous = recent[key]
  if previous and (nativeID or now - previous < 1) then return false end
  recent[key] = now
  recentOrder[#recentOrder + 1] = {key, now}
  if #recentOrder > 128 then
    local oldest = table.remove(recentOrder, 1)
    if recent[oldest[1]] == oldest[2] then recent[oldest[1]] = nil end
  end
  return true
end

local function filter(_, event, message, _, _, channel, _, _, zoneID, _, baseName, _, lineID)
  if event ~= "CHAT_MSG_CHANNEL" or not db or db.enabled == false then return false end
  stats.callbacks = stats.callbacks + 1
  if not readable(message) or not readable(channel) then
    stats.unreadable = stats.unreadable + 1
    return false
  end
  if type(issecretvalue) == "function" and issecretvalue(zoneID) then
    stats.unreadable = stats.unreadable + 1
    return false
  end
  stats.lastChannel = cleanDisplay(channel):sub(1, 80)
  stats.lastBase = readable(baseName) and cleanDisplay(baseName):sub(1, 80) or "none"
  local id = safeZoneID(zoneID)
  stats.lastZone = id and tostring(id) or "none"
  if not channelAllowed(channel, zoneID, baseName) then
    stats.otherChannel = stats.otherChannel + 1
    return false
  end
  stats.eligible = stats.eligible + 1
  local reason = classify(message)
  if reason then stats.hidden = stats.hidden + 1
  else stats.noRule = stats.noRule + 1 end
  -- A chat event can be delivered to several windows. Capture/log it once.
  if firstCallback(message, channel, lineID) then
    captureMessage(message, channel, reason)
    if reason then record(message, channel, reason) end
  end
  return reason ~= nil
end

local function say(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
  end
end

local function listPhrase(which)
  local values = db[which]
  say(which .. " rules (" .. #values .. "): " .. (#values > 0 and table.concat(values, ", ") or "none"))
end

local function command(input)
  if not readable(input) then return end
  local verb, rest = input:match("^%s*(%S+)%s*(.-)%s*$")
  verb = verb and verb:lower() or "help"
  if verb == "on" or verb == "off" then
    db.enabled = verb == "on"
    say(db.enabled and "enabled" or "disabled")
  elseif verb == "status" then
    say("v" .. VERSION .. " " .. (db.enabled and "enabled" or "disabled") ..
      "; API " .. (filterRegistered and "registered" or "unavailable") ..
      "; " .. #log.entries .. " saved hidden messages; capture " ..
      capture.state .. " " .. #capture.entries .. "/" .. CAPTURE_ENTRIES)
    say("This session, callback calls: " .. stats.callbacks .. ", General/Trade: " ..
      stats.eligible .. ", no rule: " .. stats.noRule .. ", hidden calls: " ..
      stats.hidden .. ", other channels: " .. stats.otherChannel ..
      ", unreadable: " .. stats.unreadable .. "; last channel: " .. stats.lastChannel)
    say("Last base: " .. stats.lastBase .. "; native zone ID: " .. stats.lastZone)
  elseif verb == "test" then
    if rest == "" then say("Use /fnrf test <sample message> (local only)")
    else
      local reason = classify(rest)
      say(reason and ("Sample would hide: " .. cleanDisplay(reason)) or "Sample would remain visible.")
    end
  elseif verb == "capture" then
    local action = rest:lower()
    if action == "start" then
      capture.entries, capture.bytes, capture.state = {}, 0, "active"
      say("New local capture armed: next " .. CAPTURE_ENTRIES .. " unique General/Trade messages.")
    elseif action == "stop" then
      if capture.state == "completed" then say("Completed batch preserved; use capture start to replace it.")
      else capture.state = "stopped"; say("Capture stopped; batch preserved.") end
    elseif action == "status" or action == "" then
      say("Capture " .. capture.state .. ": " .. #capture.entries .. "/" ..
        CAPTURE_ENTRIES .. " messages, " .. capture.bytes .. "/" .. CAPTURE_BYTES .. " field bytes.")
    elseif action == "export" then
      say("Use /reload or normal logout, then close the game and copy WTF/Account/<account>/<realm>/<character>/SavedVariables/FridayNightRealityFilter.lua. Read as text only; the capture is FridayNightRealityFilterCapture.")
    else say("Use /fnrf capture start|status|stop|export") end
  elseif verb == "allow" or verb == "block" then
    local action, phrase = rest:match("^(%S+)%s*(.-)%s*$")
    if action == "list" then listPhrase(verb)
    elseif action == "add" and phrase ~= "" then
      local normalized = normalize(phrase)
      if not normalized or #normalized < 5 or #phrase > 80 or #db[verb] >= 30 then
        say("Use a phrase of 3-80 characters; maximum 30 rules.")
      elseif matchRule(normalized, db[verb]) == phrase then say("Rule already present.")
      else db[verb][#db[verb] + 1] = phrase; say("Added " .. verb .. " rule: " .. cleanDisplay(phrase)) end
    elseif action == "remove" and phrase ~= "" then
      local target = normalize(phrase)
      local removed = false
      for i = #db[verb], 1, -1 do
        if normalize(db[verb][i]) == target then table.remove(db[verb], i); removed = true end
      end
      say(removed and "Rule removed." or "Rule not found.")
    else say("Use /fnrf " .. verb .. " add|remove|list [phrase]") end
  elseif verb == "review" then
    local count = math.min(10, math.max(1, tonumber(rest) or 5))
    if #log.entries == 0 then say("No saved hidden messages.") end
    for i = math.max(1, #log.entries - count + 1), #log.entries do
      local entry = log.entries[i]
      say("#" .. i .. " t=" .. entry.time .. " " .. entry.channel .. " [" .. entry.reason .. "] " .. entry.text)
    end
  elseif verb == "show" then
    local i = tonumber(rest)
    local entry = i and log.entries[i]
    if entry then say("#" .. i .. " t=" .. entry.time .. " " .. entry.channel .. " [" .. entry.reason .. "] " .. entry.text)
    else say("No entry at that number. Use /fnrf review.") end
  elseif verb == "clear" then
    log.entries = {}
    say("Saved hidden-message log cleared.")
  elseif verb == "export" then
    say("Log is saved locally on /reload or normal logout in WTF/Account/<account>/<realm>/<character>/SavedVariables/FridayNightRealityFilter.lua. Close the game before copying it.")
  else
    say("/fnrf on|off|status|test <message>|review [1-10]|show <number>|export|clear")
    say("/fnrf capture start|status|stop|export")
    say("/fnrf allow|block add|remove|list [phrase]")
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
  if event ~= "ADDON_LOADED" or name ~= ADDON then return end
  if type(FridayNightRealityFilterDB) ~= "table" then FridayNightRealityFilterDB = {} end
  if type(FridayNightRealityFilterLog) ~= "table" then FridayNightRealityFilterLog = {} end
  local firstCapture = type(FridayNightRealityFilterCapture) ~= "table"
  if firstCapture then FridayNightRealityFilterCapture = {entries = {}, bytes = 0, state = "active"} end
  db, log, capture = FridayNightRealityFilterDB, FridayNightRealityFilterLog, FridayNightRealityFilterCapture
  if type(db.enabled) ~= "boolean" then db.enabled = true end
  for _, field in ipairs({"allow", "block"}) do
    if type(db[field]) ~= "table" then db[field] = {} end
    local clean = {}
    for _, phrase in ipairs(db[field]) do
      if type(phrase) == "string" and #phrase <= 80 and #clean < 30 then
        clean[#clean + 1] = phrase
      end
    end
    db[field] = clean
  end
  trimLog()
  sanitizeCapture()
  SLASH_FRIDAYNIGHTREALITYFILTER1 = "/fnrf"
  SlashCmdList.FRIDAYNIGHTREALITYFILTER = command
  if type(ChatFrame_AddMessageEventFilter) == "function" then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
    filterRegistered = true
  else
    db.enabled = false
    say("Chat filter API unavailable in this client; addon disabled.")
  end
  frame:UnregisterEvent("ADDON_LOADED")
end)

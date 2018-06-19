require 'common'

local F = far.Flags
local VK = win.GetVirtualKeys()

local function prepareFilterTable(data)
	res = {}
	for v,c in pairs(data) do
		res[#res+1] = {value=v, count=c}
	end
	
	table.sort(res, function(a,b) return (a.value < b.value) end)
	return res
end

local function map(tbl, fn)
	local res = {}
	for i,v in ipairs(tbl) do
		res[i] = fn(tbl[i])
	end
	return res
end

local function get_values(tbl)
	local res = {}
	for i, v in ipairs(tbl) do
		res[v.value] = true
	end
	return res
end
	
--local function get_area_size(items)	
--	local w=0
--	for _, item in ipairs(items) do
--		w = math.max(w, #item.value)
--	end
--	return w, #items
--end


-- =========================== FILTER ============================

local xmlc_filter = {}
local xmlc_filter_mt = {__index=xmlc_filter}


function xmlc_filter.init(xmlc_reader)
	local names = MakeCounter()
	local channels = MakeCounter()
	local rails = MakeCounter()
	local min_coord, max_coord
	
	for i, item in ipairs(xmlc_reader.values) do
		names(item.name)
		channels(item.channel)
		rails(item.rail)
		if not min_coord or min_coord > item.coord then 
			min_coord = item.coord
		end
		if not max_coord or max_coord < item.coord then 
			max_coord = item.coord
		end
	end
	
	local self = {
		initial = {
			names = prepareFilterTable(names),
			channels = prepareFilterTable(channels),
			rails = prepareFilterTable(rails),
			min_coord = min_coord or 0,
			max_coord = max_coord or 0,
		},
		enable = false,
	}
	setmetatable(self, xmlc_filter_mt)
	self:prepare()
	return self
end

function xmlc_filter:prepare()
	self.user = {
		names = get_values(self.initial.names),
		channels = get_values(self.initial.channels),
		rails = get_values(self.initial.rails),
		min_coord = self.initial.min_coord,
		max_coord = self.initial.max_coord,
	}
end

function xmlc_filter:show()

	local dlg_items = {}
		
	for i, item in pairs(self.initial.names) do
		table.insert(dlg_items, {F.DI_CHECKBOX,   1,1+i,15,1+1, 0, 0, 0, 0, item.value})
	end
	
	

--	local function DlgProc(hDlg, Msg, Param1, Param2)
--		if Msg == F.DN_INITDIALOG then
--			--far.Message('DN_INITDIALOG')
--		elseif Msg == F.DN_LISTCHANGE then
--			--far.Message('DN_LISTCHANGE')
--		elseif Msg == F.DN_CONTROLINPUT then 
--			if Param2.EventType == F.KEY_EVENT and Param2.KeyDown and Param2.VirtualKeyCode == VK.SPACE then
--				--far.Message(sprintf('DN_CONTROLINPUT: %s %s %s %s', Param1, Param2.KeyDown, Param2.VirtualKeyCode, Param2.VirtualScanCode))
--				local idx = far.SendDlgMessage(hDlg, F.DM_LISTGETCURPOS, Param1, nil)
--				idx = idx and idx.SelectPos
--				if idx then
--					local item = far.SendDlgMessage(hDlg, F.DM_LISTGETITEM, Param1, idx)
--					local state = bit64.band(item.Flags, F.LIF_CHECKED) ~= 0
--					--far.Message(sprintf('idx = %s %s, %s %X', idx, state, item.Text, item.Flags))
--					local Flags = bit64.bxor(item.Flags, F.LIF_CHECKED)
--					far.SendDlgMessage(hDlg, F.DM_LISTUPDATE, Param1, {Index = idx, Text = item.Text, Flags = Flags})
--					dlg_items[Param1][6][idx].Flags = Flags
--				end
--			end
--		elseif Msg == F.DN_EDITCHANGE then
--			--far.Message('DN_EDITCHANGE')
--		end
--	end

	local guid = win.Uuid("5943454A-B98B-4c94-8146-C212C16C010E")
	local dlg = far.DialogInit(guid, -1, -1, 60, 25, nil, dlg_items, F.FDLG_NONE, nil)
	local rc = far.DialogRun(dlg)
	if rc == 1 then  -- ok
		-- pass
	end
	far.DialogFree(dlg)
	
--	local s = ""
--	for i, n in ipairs(list_items) do
--		s = s .. string.format('%d %s %x\n', i, n.Text, n.Flags)
--	end
--	far.Message(s)
	
end

function xmlc_filter:visible(item)
	if self.enable then
		return true
	end
	
	return self.user.names[item.name] and
		self.user.channels[item.channels] and
		self.user.rails[item.rails] and
		self.user.min_coord <= item.coord and
		self.user.max_coord >= item.coord
end


return xmlc_filter


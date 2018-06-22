require 'common'

local F = far.Flags
local VK = win.GetVirtualKeys()

local sprintf = string.format

	
function table.merge(...)
	local dst = {}
	for _, src in ipairs{...} do
		table.move(src, 1, #src, #dst+1, dst)
	end
	return dst
end

-- =========================== FILTER ITEM ============================

local filter_block = {}
local filter_block_mt = {__index=filter_block}

function filter_block.init(cntr)
	initial = {}
	selected = {}
	for v,c in pairs(cntr) do
		table.insert(initial, {value=v, count=c, text=string.format('%s (%d)', v, c)})
		selected[v] = true
	end
	
	table.sort(initial, function(a,b) return (a.value < b.value) end)
	
	local self = {
		initial=initial,
		selected=selected,
	}

	return setmetatable(self, filter_block_mt)
end

function filter_block:visible(value)
	return self.selected[value]
end

function filter_block:get_area_size(a, b)
	local w = 0
	for i, item in ipairs(self.initial) do
		w = math.max(w, #item.text)
		--far.Message(string.format('%d/%d: %s', i, #self.initial, item.text))
	end
	return w+6, #self.initial+1
end

function filter_block:init_controls(x, y, w, h, title, controls, callbacks)
	local cw, ch = self:get_area_size()
	
	w = w or cw
	h = h or ch
	
	table.insert(controls, {F.DI_SINGLEBOX, 	x, y, x+w, y+h,  0,  0, 0, F.DIF_LEFTTEXT, title})
	local checkbox_items = {}
	
	for i, item in ipairs(self.initial) do
--		local cb = function(s)
--			assert(type(s) == 'boolean')
--			self.selected[item.value] = set
--		end
--		table.insert(callbacks, cb)
--		local ixd_cb = #callbacks
		
		local check = self.selected[item.value] and 1 or 0
		local dlg_item = {
				F.DI_CHECKBOX, 			-- type
				x+1, y+i, x+w-2, y+i,	-- X1, Y1, X2, Y2
				check, 					-- state
				0, 0, 0,				-- hyst, mask,flags
				item.text, 				-- data
				0, 						-- maxlen
				ixd_cb					-- UserData
			}
		table.insert(controls, dlg_item)
		checkbox_items[#controls] = true
	end
	
	local function set_checkboxes(hDlg, check)
		local state = check and F.BSTATE_CHECKED or F.BSTATE_UNCHECKED
		for id, _ in pairs(checkbox_items) do
			far.SendDlgMessage(hDlg, F.DM_SETCHECK, id, state)
		end
	end
		
	table.insert(callbacks, function(hDlg) set_checkboxes(hDlg, true) end)	
	table.insert(controls, {
		F.DI_BUTTON,      	-- type
		x+2,  y+#self.initial+1, 0, 0,   -- X1, Y1, X2, Y2
		0,0,0,				-- state, hyst, mask,
		F.DIF_BTNNOCLOSE,	-- flags
		"+",				-- text
		0, 
		#callbacks
	})

	table.insert(callbacks, function(hDlg) set_checkboxes(hDlg, false) end)	
	table.insert(controls, {
		F.DI_BUTTON,      	-- type
		x+7,  y+#self.initial+1, 0, 0,   -- X1, Y1, X2, Y2
		0,0,0,				-- state, hyst, mask,
		F.DIF_BTNNOCLOSE,	-- flags
		"-",				-- text
		0, 
		#callbacks
		})

	--far.Message(string.format('%s: %d %d | %d', title, h, #self.initial, #ctrls))
	
end

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
		names = filter_block.init(names),
		channels = filter_block.init(channels),
		rails = filter_block.init(rails),
		min_coord = min_coord or 0,
		max_coord = max_coord or 0,
		enable = false,
	}
	self.user_min_coord = self.min_coord
	self.user_max_coord = self.max_coord
	
	setmetatable(self, xmlc_filter_mt)
	
	return self
end

function xmlc_filter:_prepare_dlg()
	local controls = {}
	local callbacks = {}
	
	local function DlgProc(hDlg, Msg, Param1, Param2)
		if Msg == F.DN_INITDIALOG then
			--far.Message('DN_INITDIALOG')
		elseif Msg == F.DN_BTNCLICK then
			local dlg_item_data = far.SendDlgMessage(hDlg, F.DM_GETITEMDATA, Param1, 0)
			if 0 < dlg_item_data and dlg_item_data <= #callbacks then
				callbacks[dlg_item_data](hDlg)
			end
			return true
		end
	end

	local nw, nh = self.names:get_area_size()
	local cw, ch = self.channels:get_area_size()
	local rw, rh = self.rails:get_area_size()
	
	self.names:init_controls(1, 1, nil, nil, 'Names', controls, callbacks)
	self.channels:init_controls(nw+3, 1, nil, nil, 'Channels', controls, callbacks)
	self.rails:init_controls(nw+cw+5, 1, nil, nil, 'Rails', controls, callbacks)
	
	local max_h = math.max(nh, ch, rh)
	
	local guid = win.Uuid("5943454A-B98B-4c94-8146-C212C16C010E")
	local dlg = far.DialogInit(guid, -1, -1, nw+cw+rw+9, max_h+2, nil, controls, F.FDLG_NONE, DlgProc)
	return dlg
end


function xmlc_filter:show()
	local dlg = self:_prepare_dlg()
	local rc = far.DialogRun(dlg)
	if rc == 1 then  -- ok
		-- pass
	end
	-- far.DialogFree (dlg)
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
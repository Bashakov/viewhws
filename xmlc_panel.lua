-- far.Message("load xmlc_panel.lua")

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor

require 'common'

local xmlc_reader = require 'xmlc_reader'

-- =========================== PANEL ============================

local xmlc_panel = {}
local xmlc_panel_mt = {__index=xmlc_panel}


function xmlc_panel.open(file_name)
	local self = {
		file_name = file_name,
		curr_object = nil,
		panel_mode  = nil, -- valid values are: "root", 
		panel_info = {
			title = '',
			modes = {};
		},
		reader = xmlc_reader.new()
	}
	setmetatable(self, xmlc_panel_mt)
	if self.reader:open(file_name) and self:open_root() then
		return self
	end
end

function xmlc_panel:open_root()
  self.panel_mode = "root"
  self.curr_object = ""
  self:prepare_panel_info()
  return true
end

local function add_keybar_label(panel_info, label, vkc, cks)
	local kbl = {
		Text = label;
		LongText = label;
		VirtualKeyCode = vkc;
		ControlKeyState = cks or 0;
	}
	
	for _, item in pairs(panel_info.key_bar) do
		if item.VirtualKeyCode == kbl.VirtualKeyCode and item.ControlKeyState == kbl.ControlKeyState then
			item.Text = kbl.Text
			item.LongText = kbl.LongText
			return
		end
	end
	
	table.insert(panel_info.key_bar, kbl)
end

function xmlc_panel:prepare_panel_info()
	local info = self.panel_info
	info.title =  "XMLC: " .. self.file_name:match("[^\\/]*$")
	if self._curr_object == "" or self._curr_object == nil then
		-- pass
	else
		info.title = info.title .. " [" .. self._curr_object .. "]"
	end
	
	local pm = {
		ColumnTypes  = 'C0,N,C1,C2,C3,C4',
		ColumnWidths = '6,0,6,6,13,10',
		ColumnTitles = {'N', 'Type', 'Rail', 'Chnl', 'Coordinate', 'Value'},
	}
	pm.StatusColumnTypes = pm.ColumnTypes
	pm.StatusColumnWidths = pm.ColumnWidths;
	info.modes = {pm,}
	
	info.key_bar = {}

	for i = VK.F1, VK.F12 do
		add_keybar_label(info, "", i, F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED)
		add_keybar_label(info, "", i, F.LEFT_ALT_PRESSED + F.LEFT_ALT_PRESSED)
		add_keybar_label(info, "", i)
	end
	add_keybar_label(info, "FILTER", VK.F5)
--	add_keybar_label(info, "RAIL", VK.F6)
--	add_keybar_label(info, "CHANNEL", VK.F7)
--	add_keybar_label(info, "SYS_COORD", VK.F8)
	
end



function xmlc_panel:get_panel_info()
  return {
    CurDir           = self.curr_object;
    Flags            = bor(F.OPIF_DISABLESORTGROUPS, F.OPIF_DISABLEFILTER),
    HostFile         = self.file_name,
	KeyBar           = self.panel_info.key_bar;
    PanelTitle       = self.panel_info.title,
	PanelModesArray  = self.panel_info.modes;
    PanelModesNumber = #self.panel_info.modes;
	StartPanelMode   = ("0"):byte();
	StartSortMode    = F.SM_UNSORTED;
  }
end

function xmlc_panel:get_panel_list()
  local rc = false
  if self.panel_mode == "root" then
    rc = self:get_panel_list_root()
--  elseif self._panel_mode=="table" or self._panel_mode=="view" then
--    rc = self:get_panel_list_obj()
--  elseif self._panel_mode == "query" then
--    rc = self:get_panel_list_query()
  end
  return rc
end

local function format_sys_coord(coord)
	local mm = coord % 1000
	local km_m = (coord - mm) /1000
	local m = km_m % 1000
	local km = (km_m-m) / 1000
	return sprintf(' %03d.%03d.%03d', km, m, mm)
end


function xmlc_panel:get_panel_list_root()
	local result = { { FileName=".."; FileAttributes="d"; } }
	
	for i, item in ipairs(self.reader.values) do
		local file_item = {}
		
		file_item.UserData = i
		file_item.FileName = item.name
		file_item.CustomColumnData = {
			sprintf('%5d', i), 
			sprintf('%5d', item.rail), 
			sprintf('%5d', item.channel),
			format_sys_coord(item.coord),
			sprintf('%9d', item.value),
		}
		result[#result+1]= file_item
	end
	return result
end

function xmlc_panel:handle_keyboard(handle, key_event)
	local vcode  = key_event.VirtualKeyCode
	local cstate = key_event.ControlKeyState
	local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
	local shift  = cstate == F.SHIFT_PRESSED

	if vcode == VK.F3 or vcode == VK.F4 then
		self:view_data(vcode == VK.F4)
		return true
	elseif vcode == VK.F5 then
		self:show_filter()
		return true
	end
end

function xmlc_panel:show_filter()
	local names = {}
	for i, item in ipairs(self.reader.values) do
		local v = item.name
		names[v] = (names[v] or 0) + 1
	end
	
	local list_items = {}
	
	for n,c in pairs(names) do
		list_items[#list_items+1] = 
		{ 
			Text = sprintf('%s(%d)', n, c),
			Flags = F.LIF_CHECKED,
		}
	end
	
	local list_flags = F.DIF_LISTNOAMPERSAND + F.DIF_FOCUS -- F.DIF_LISTNOBOX
	local dlg_items = {
		{F.DI_LISTBOX,   1,1,58,22, list_items, 0, 0, list_flags,      "Name"},
	}

	local function DlgProc(hDlg, Msg, Param1, Param2)
		if Msg == F.DN_INITDIALOG then
			--far.Message('DN_INITDIALOG')
		elseif Msg == F.DN_LISTCHANGE then
			--far.Message('DN_LISTCHANGE')
		elseif Msg == F.DN_CONTROLINPUT then 
			if Param2.EventType == F.KEY_EVENT and Param2.KeyDown and Param2.VirtualKeyCode == VK.SPACE then
				--far.Message(sprintf('DN_CONTROLINPUT: %s %s %s %s', Param1, Param2.KeyDown, Param2.VirtualKeyCode, Param2.VirtualScanCode))
				local idx = far.SendDlgMessage(hDlg, F.DM_LISTGETCURPOS, Param1, nil)
				idx = idx and idx.SelectPos
				if idx then
					local item = far.SendDlgMessage(hDlg, F.DM_LISTGETITEM, Param1, idx)
					local state = bit64.band(item.Flags, F.LIF_CHECKED) ~= 0
					--far.Message(sprintf('idx = %s %s, %s %X', idx, state, item.Text, item.Flags))
					local Flags = bit64.bxor(item.Flags, F.LIF_CHECKED)
					far.SendDlgMessage(hDlg, F.DM_LISTUPDATE, Param1, {Index = idx, Text = item.Text, Flags = Flags})
					dlg_items[Param1][6][idx].Flags = Flags
				end
			end
		elseif Msg == F.DN_EDITCHANGE then
			--far.Message('DN_EDITCHANGE')
		end
	end

	local guid = win.Uuid("5943454A-B98B-4c94-8146-C212C16C010E")
	local dlg = far.DialogInit(guid, -1, -1, 60, 25, nil, dlg_items, F.FDLG_NONE, DlgProc)
	local rc = far.DialogRun(dlg)
	if rc == 1 then  -- ok
		-- pass
	end
	far.DialogFree(dlg)
	
	local s = ""
	for i, n in ipairs(list_items) do
		s = s .. string.format('%d %s %x\n', i, n.Text, n.Flags)
	end
	far.Message(s)
	
end


function xmlc_panel:view_data(edit)
	far.Message('not implemented yet')
--	local item = panel.GetCurrentPanelItem(nil, 1)
--	if not item then return end
--	local tmp_file_name = self.reader:Export(item.UserData)
--	if tmp_file_name then
--		if edit then
--			editor.Editor(tmp_file_name, "", nil, nil, nil, nil, F.EF_DISABLESAVEPOS + F.EF_DISABLEHISTORY, nil, nil, 65001)
--		else
--			viewer.Viewer(tmp_file_name, nil, 0, 0, -1, -1, bor(F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE), 65001) -- , F.VF_IMMEDIATERETURN, F.VF_NONMODAL
--		end
--	end
end

return xmlc_panel
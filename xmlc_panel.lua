-- far.Message("load xmlc_panel.lua")

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor

require 'common'

local xmlc_reader = require 'xmlc_reader'
local xmlc_filter = require 'xmlc_filter'

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
		reader = xmlc_reader.new(),
	}
	setmetatable(self, xmlc_panel_mt)
	if self.reader:open(file_name) then
		self.filter = xmlc_filter.init(self.reader)
		self:open_root()
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
	add_keybar_label(info, self.filter.enable and "OFF FLTR" or "ON FLTR", VK.F5)
	add_keybar_label(info, "TUNE FLTR", VK.F6)
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
	--far.Message('get_panel_list_root')
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
		self.filter.enable = not self.filter.enable
		self:prepare_panel_info()
		panel.RedrawPanel (handle, 1) 
		panel.UpdatePanel (handle, 1)
		--far.Message('F5')
		return true
	elseif vcode == VK.F6 then
		self.filter:show()
		panel.UpdatePanel (handle, 1)
		return true		
	end
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
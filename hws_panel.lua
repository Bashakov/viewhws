-- far.Message("load hws_panel.lua")

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor

require 'common'

local hws_reader = require 'hws_reader'

-- =========================== PANEL ============================

local hws_panel = {}
local hws_panel_mt = {__index=hws_panel}


function hws_panel.open(file_name)
	local self = {
		file_name = file_name,
		curr_object = nil,
		panel_mode  = nil, -- valid values are: "root", 
		panel_info = {
			title = '',
			modes = {};
		},
		reader = hws_reader.new()
	}
	setmetatable(self, hws_panel_mt)
	if self.reader:open(file_name) and self:open_root() then
		return self
	end
end

function hws_panel:open_root()
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

function hws_panel:prepare_panel_info()
	local info = self.panel_info
	info.title =  "HWS: " .. self.file_name:match("[^\\/]*$")
	if self._curr_object == "" or self._curr_object == nil then
		-- pass
	else
		info.title = info.title .. " [" .. self._curr_object .. "]"
	end
	
	local pm1 = {
		ColumnTypes  = 'C0,N,C1,C2,C3,C4',
		ColumnWidths = '6,0,6,6,13,10',
		ColumnTitles = {'N', 'Type', 'Rail', 'Chnl', 'Coordinate', 'Value'},
	}
	pm1.StatusColumnTypes = pm1.ColumnTypes
	pm1.StatusColumnWidths = pm1.ColumnWidths;
	info.modes = {pm1,}
	
	info.key_bar = {}

	for i = VK.F1, VK.F12 do
		add_keybar_label(info, "", i, F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED)
		add_keybar_label(info, "", i, F.LEFT_ALT_PRESSED + F.LEFT_ALT_PRESSED)
		add_keybar_label(info, "", i)
	end
	add_keybar_label(info, "NAME", VK.F5)
	add_keybar_label(info, "RAIL", VK.F6)
	add_keybar_label(info, "CHANNEL", VK.F7)
	add_keybar_label(info, "SYS_COORD", VK.F8)
	
end



function hws_panel:get_panel_info()
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

function hws_panel:get_panel_list()
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


function hws_panel:get_panel_list_root()
	local reader = self.reader
	local result = { { FileName=".."; FileAttributes="d"; } }
	
	for i, item in ipairs(self.reader.values) do
		local file_item = {}
		
		file_item.UserData = i
		file_item.FileName = item.name
		--file_item.FileSize =  0
		file_item.CustomColumnData = {
			sprintf('%5d', i), 
			sprintf('%5d', item.rail), 
			sprintf('%5d', item.channel),
			--sprintf('%9d', item.coord),
			format_sys_coord(item.coord),
			sprintf('%9d', item.value),}
		result[#result+1]= file_item
	end
	return result
end

function hws_panel:handle_keyboard(handle, key_event)
	local vcode  = key_event.VirtualKeyCode
	local cstate = key_event.ControlKeyState
	local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
	local shift  = cstate == F.SHIFT_PRESSED

	if vcode == VK.F3 or vcode == VK.F4 then
		self:view_data(vcode == VK.F4)
		return true
	elseif vcode == VK.F5 then
		self.filter_name()
	elseif vcode == VK.F6 then
		self.filter_rail()
	end
end

function hws_panel.filter_name()
	
end

function hws_panel.filter_rail()
	
end

function hws_panel:view_data(edit)
	local item = panel.GetCurrentPanelItem(nil, 1)
	if not item then return end
	local tmp_file_name = self.reader:Export(item.UserData)
	if tmp_file_name then
		if edit then
			editor.Editor(tmp_file_name, "", nil, nil, nil, nil, F.EF_DISABLESAVEPOS + F.EF_DISABLEHISTORY, nil, nil, 65001)
		else
			viewer.Viewer(tmp_file_name, nil, 0, 0, -1, -1, bor(F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE), 65001) -- , F.VF_IMMEDIATERETURN, F.VF_NONMODAL
		end
	end
end

return hws_panel
-- far.Message("load hws_panel.lua")

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor

local sprintf = function(s, ...) return string.format(s, ...) end

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

function hws_panel:prepare_panel_info()
	local info = self.panel_info
	info.title =  "HWS: " .. self.file_name:match("[^\\/]*$")
	if self._curr_object == "" or self._curr_object == nil then
		-- pass
	else
		info.title = info.title .. " [" .. self._curr_object .. "]"
	end
	
	local pm1 = {
		ColumnTypes  = 'N,C0,C1,S',
		ColumnWidths = '0,9,9,9',
		ColumnTitles = {'Type', 'Rail', 'Channel', 'Count'},
	}
	pm1.StatusColumnTypes = pm1.ColumnTypes
	pm1.StatusColumnWidths = pm1.ColumnWidths;
	info.modes = {pm1,}
end

function hws_panel:get_panel_info()
  return {
    CurDir           = self.curr_object;
    Flags            = bor(F.OPIF_DISABLESORTGROUPS, F.OPIF_DISABLEFILTER),
    HostFile         = self.file_name,
    PanelTitle       = self.panel_info.title,
	PanelModesArray  = self.panel_info.modes;
    PanelModesNumber = #self.panel_info.modes;
	StartPanelMode   = ("0"):byte();
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

local function keys(tbl)
	local res = {}
	for n,v in pairs(tbl) do
		res[#res + 1] = n
	end
	return res
end


function hws_panel:get_panel_list_root()
	local result = { { FileName=".."; FileAttributes="d"; } }
	
	local dirs = {}
	for key, coord_value in pairs(self.reader.values) do
		dirs[key[1]] = true
	end
	-- dirs = keys(dirs)	
	
	for n,v in pairs(dirs) do
		result[#result+1] = {
			FileAttributes="d",
			UserData = nil,
			FileName = n,
			FileSize = 0,
		}
	end
	
	for key, coord_value in pairs(self.reader.values) do
		local file_item = {}
		
		file_item.UserData = key
		file_item.FileName = key[1]
		file_item.FileSize = #coord_value
		file_item.CustomColumnData = {
			sprintf('%9d', key[2]), 
			sprintf('%9d', key[3]), }
		
		-- result[#result+1]= file_item
	end
	return result
end

function hws_panel:handle_keyboard(handle, key_event)
	local vcode  = key_event.VirtualKeyCode
	local cstate = key_event.ControlKeyState

	if vcode == VK.F3 or vcode == VK.F4 then
		self:view_data(vcode == VK.F4)
		return true
	end
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
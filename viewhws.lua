local ffi = require "ffi"

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor

local sprintf = function(s, ...) return string.format(s, ...) end

-- =============================================================

local function MakeCounter()
	mt = {
		__index = function(self, name) return 0 end,
		__call = function(self, name)  self[name] = self[name] + 1;	return self[name] end }
	return setmetatable({}, mt)
end

local function UniqueTableMaker()
	local table_cache = {}
	local mt = {
		__tostring = function(self)
			return  'UniqueTable(' .. table.concat(self, ',') .. ')'
		end,
	}
	return function (...)
		local t = {...}
		if not table_cache[#t] then 
			table_cache[#t] = {} 
		end
		
		local cache = table_cache[#t]
		for i = 1, #t-1 do
			local v = t[i]
			if not cache[v] then
				cache[v] = {}
			end
			cache = cache[v]
		end
		local li = t[#t]
		
		if not cache[li] then
			cache[li] = setmetatable(t, mt)
		end
		return cache[li]
	end
end

-- =========================== READER ============================

if not pcall(ffi.new, 'struct hws_compressed_xml_t') then
	ffi.cdef[[
		typedef unsigned char 	BYTE;
		typedef unsigned long 	DWORD;
		typedef long 			LONG;

		struct hws_compressed_xml_t
		{
			BYTE			nIdx;
			BYTE			nRail;
			BYTE			nChannel;
			BYTE			nType;
			DWORD			nCoord;
			LONG			nValue;
		};
	]]
end


local hws_reader = {}
local hws_reader_mt = {__index=hws_reader}

function hws_reader.new()
	return setmetatable({}, hws_reader_mt)
end

function hws_reader:open(file_name)
	local idx2names = {}
	self.KeyGen = UniqueTableMaker()
	self.file = assert(io.open(file_name, 'rb'))
	
	self.values = {} -- setmetatable({}, {__index=function() return {} end})
	
	if not self.check_header(self.file:read(4)) then 
		error('wrong file header') 
	end
	
	local hws_item = ffi.new('struct hws_compressed_xml_t')
	local hws_item_size = ffi.sizeof(hws_item)
	
	while true do
		local s = self.file:read(hws_item_size)
		if not s then break end
		
		ffi.copy(hws_item, s)
		--print(hws_item.nIdx, hws_item.nRail, hws_item.nChannel, hws_item.nType, hws_item.nCoord, hws_item.nValue)
		
		if hws_item.nType == 0 then -- HWS_CXML_INDEX_NAME
			local name = self.file:read(hws_item.nValue)
			assert(name)
			idx2names[hws_item.nIdx] = name
		elseif hws_item.nType == 2 then -- HWS_CXML_INDEXED_VALUE
			local key = self.KeyGen(idx2names[hws_item.nIdx], hws_item.nRail, hws_item.nChannel)
			if not self.values[key] then self.values[key] = {} end
			local vals = self.values[key]
			vals[#vals + 1] = {hws_item.nCoord, hws_item.nValue}
			-- far.Message(key)
		else
			error('unknown item type: '..tostring(hws_item.nType))
		end
	end
--	for key, coord_value in pairs(self.values) do
--		far.Message(tostring(key) .. tonumber(#coord_value))
--	end
	return self
end

function hws_reader:close()
	if self.file then
		self.file:close()
		self.file = nil
	end
	self.values = {}
end

function hws_reader.check_header(buffer)
	return buffer:sub(1, 4) == 'XMLc'
end

function hws_reader:Export(key, file_name)
	local values = self.values[key]
	if not values then return nil end
	
	if not file_name then file_name = far.MkTemp() end
	
	local title = string.format('%s  rail=%d channel=%d', key[1], key[2], key[3])
	
	local file = io.open(file_name, "w+")
	-- file:write("\239\187\191") -- UTF-8 BOM
	
	file:write(title .. '\n')
	file:write(title:gsub('.', '=') .. '\n')
	file:write('     N |      coord |      value\n')
	file:write('-------+------------+------------\n')
	for i, coord_value in ipairs(values) do
		local l = string.format('%6d | %10d | %10d', i, coord_value[1], coord_value[2])
		--far.Message(l)
		file:write(l .. '\n')
	end
	file:close()
	return file_name
end


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

function hws_panel:get_panel_list_root()
	local result = { { FileName=".."; FileAttributes="d"; } }
	
--	local names = MakeCounter()
--	local 
	for key, coord_value in pairs(self.reader.values) do
		local file_item = {}
		
		file_item.UserData = key
		file_item.FileName = key[1]
		file_item.FileSize = #coord_value
		file_item.CustomColumnData = {
			sprintf('%9d', key[2]), 
			sprintf('%9d', key[3]), }
		
		result[#result+1]= file_item
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

-- ========================== EXPORTS ============================== 

far.ReloadDefaultScript = true

function export.Analyse(info)
	local ext = info.FileName:lower():sub(-3)
	local ok = (ext == 'hws' or ext == 'gps') and hws_reader.check_header(info.Buffer)
	return ok
end

function export.Open(OpenFrom, Guid, Item)
	-- far.Message("hws_view export.Open")

	if OpenFrom == F.OPEN_ANALYSE then
		return hws_panel.open(Item.FileName)
	end
end

function export.GetOpenPanelInfo (object, handle)
	return object:get_panel_info()
end

function export.GetFindData(object, handle, OpMode)
  return object:get_panel_list()
end

function export.ProcessPanelInput(object, handle, rec)
	return rec.EventType == F.KEY_EVENT and object:handle_keyboard(handle, rec)
end

--function export.Configure (guid)
--  far.Message("hws_view export.Configure")
--end
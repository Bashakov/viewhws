--far.Message("load hws_reader.lua")

local ffi = require "ffi"

require 'common'

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
	self.file = assert(io.open(file_name, 'rb'))
	
	self.values = {}
	
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
			local rec_item = {
				name = idx2names[hws_item.nIdx],
				rail = hws_item.nRail,
				channel = hws_item.nChannel,
				coord = hws_item.nCoord, 
				value = hws_item.nValue,
			}
			self.values[#self.values + 1] = rec_item
		else
			error('unknown item type: '..tostring(hws_item.nType))
		end
	end
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


return hws_reader
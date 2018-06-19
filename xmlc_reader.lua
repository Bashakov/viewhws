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


local xmlc_reader = {}
local xmlc_reader_mt = {__index=xmlc_reader}

function xmlc_reader.new()
	return setmetatable({}, xmlc_reader_mt)
end

function xmlc_reader:open(file_name)
	local idx2names = {}
	self.file = assert(io.open(file_name, 'rb'))
	
	self.values = {}
	
	if not self.check_header(self.file:read(4)) then 
		error('wrong file header') 
	end
	
	local xmlc_item = ffi.new('struct hws_compressed_xml_t')
	local xmlc_item_size = ffi.sizeof(xmlc_item)
	
	while true do
		local s = self.file:read(xmlc_item_size)
		if not s then break end
		
		ffi.copy(xmlc_item, s)
		--print(xmlc_item.nIdx, xmlc_item.nRail, xmlc_item.nChannel, xmlc_item.nType, xmlc_item.nCoord, xmlc_item.nValue)
		
		if xmlc_item.nType == 0 then 			-- HWS_CXML_INDEX_NAME
			local name = self.file:read(xmlc_item.nValue)
			assert(name)
			if idx2names[xmlc_item.nIdx] then
				--far.Message(string.format('%s %s', idx2names[xmlc_item.nIdx], name))
			end
			assert(not idx2names[xmlc_item.nIdx] or idx2names[xmlc_item.nIdx] == name)
			idx2names[xmlc_item.nIdx] = name
		elseif xmlc_item.nType == 2 then 		-- HWS_CXML_INDEXED_VALUE
			local rec_item = {
				name = idx2names[xmlc_item.nIdx],
				rail = xmlc_item.nRail,
				channel = xmlc_item.nChannel,
				coord = xmlc_item.nCoord, 
				value = xmlc_item.nValue,
			}
			self.values[#self.values + 1] = rec_item
		else
			error('unknown item type: '..tostring(xmlc_item.nType))
		end
	end
	return self
end

function xmlc_reader:close()
	if self.file then
		self.file:close()
		self.file = nil
	end
	self.values = {}
end

function xmlc_reader.check_header(buffer)
	return buffer:sub(1, 4) == 'XMLc'
end


--function xmlc_reader:Export(key, file_name)
--	local values = self.values[key]
--	if not values then return nil end
	
--	if not file_name then file_name = far.MkTemp() end
	
--	local title = string.format('%s  rail=%d channel=%d', key[1], key[2], key[3])
	
--	local file = io.open(file_name, "w+")
--	-- file:write("\239\187\191") -- UTF-8 BOM
	
--	file:write(title .. '\n')
--	file:write(title:gsub('.', '=') .. '\n')
--	file:write('     N |      coord |      value\n')
--	file:write('-------+------------+------------\n')
--	for i, coord_value in ipairs(values) do
--		local l = string.format('%6d | %10d | %10d', i, coord_value[1], coord_value[2])
--		--far.Message(l)
--		file:write(l .. '\n')
--	end
--	file:close()
--	return file_name
--end


return xmlc_reader
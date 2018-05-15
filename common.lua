
function MakeCounter()
	mt = {
		__index = function(self, name) return 0 end,
		__call = function(self, name)  self[name] = self[name] + 1;	return self[name] end }
	return setmetatable({}, mt)
end


function UniqueTableMaker()
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



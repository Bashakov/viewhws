-- far.Message("load viewhws.lua")


-- insert current dir in module search paths
local plugin_import_path = far.PluginStartupInfo().ModuleDir .. "?.lua;"
if not package.path:find(plugin_import_path, 1, true) then
	-- far.Message("add path")
	package.path = plugin_import_path .. package.path
end

local function LoadScript(name, ...)
	local path = far.PluginStartupInfo().ModuleDir .. name .. ".lua"
	local f, errmsg = loadfile(path)
	if f then return f(...) end
	error(errmsg)
end


local F = far.Flags

local hws_reader = LoadScript 'hws_reader'
local hws_panel = LoadScript 'hws_panel'


-- ========================== EXPORTS ============================== 

far.ReloadDefaultScript = true

function export.Analyse(info)
	--far.Message(far.PluginStartupInfo().ModuleDir)
	
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
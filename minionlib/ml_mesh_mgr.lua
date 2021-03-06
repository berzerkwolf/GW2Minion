-- Meshmanager , Handles the loading/saving/recording of meshes and wanted gamedata

-- TO USE/IMPLEMENT THIS MANAGER:
-- Set ml_mesh_mgr.parentWindow.Name 
-- Call ml_mesh_mgr.OnUpdate( tickcount ) from the main pulse
-- Add a button with ToggleMeshManager as event to open/close the window
-- Add a "GetMapID() callback, like : ml_mesh_mgr.GetMapID = function () return Player:GetMapID() end
-- Add a "GetMapName() callback, like : ml_mesh_mgr.GetMapName = function () return Player:GetMapName() end
-- Add a "GetPlayerPos() callback, like : ml_mesh_mgr.GetPlayerPos = function () return Player:GetPlayerPos() end
-- Set "ml_mesh_mgr.averagegameunitsize" to a avg radius of how fat the player is, this val is used for determining the radius around the player to search for markers
-- Set "ml_mesh_mgr.navData" to a table with world connection nodes
-- Auto-recording Markers:
-- 
 
-- Usefull functions:
-- ml_mesh_mgr.LoadNavMesh( meshname ) -> loads the wanted mesh by its filename
-- ml_mesh_mgr.SetDefaultMesh(mapid,mapname)  -> sets this mapname as default for the mapid
-- ml_mesh_mgr.RemoveDefaultMesh(mapid) -> removes the default for the mapid
 
 
 -- Default mesh "class" that holds all relevant mesh data
ml_mesh = inheritsFrom(nil)
function ml_mesh.Create()
	local newinst = inheritsFrom( ml_mesh )
	newinst.MapID = 0					-- holds the current MapID
	newinst.AllowedMapIDs = {}			-- holds a list of MapIDs where this mesh is allowed to be used
	newinst.Name = ""					-- meshname / filename
	newinst.MarkerList = {}				-- not used yet, in future for holding the mesh marker data
	newinst.Obstacles = {}				-- not used yet, in future for holding the mesh obstacles
	newinst.AvoidanceAreas = {}			-- not used yet, in future for holding the mesh avoidanceareas
	newinst.LastPlayerPosition = { x=0, y=0, z=0, h=0, hx=0, hy=0, hz=0}	-- for autorecording markers n such
	return newinst
end

ml_mesh_mgr = { }
ml_mesh_mgr.navmeshfilepath = GetStartupPath() .. [[\Navigation\]];
ml_mesh_mgr.mainwindow = { name = GetString("meshManager"), x = 350, y = 100, w = 275, h = 400}
ml_mesh_mgr.parentWindow = { Name = "MinionBot" } -- Needs to get re-set
ml_mesh_mgr.navData = {} -- Holds the data for world navigation
ml_mesh_mgr.GetMapID = function () return 0 end -- Needs to get re-set
ml_mesh_mgr.GetMapName = function () return "NoName" end -- Needs to get re-set
ml_mesh_mgr.GetPlayerPos = function () return { x=0, y=0, z=0, h=0 } end -- Needs to get re-set
ml_mesh_mgr.SetEvacPoint = function () return end -- Needs to get set
ml_mesh_mgr.nextNavMesh = nil -- Holds the navmeshfilename that should get loaded
ml_mesh_mgr.currentMesh = ml_mesh.Create()
ml_mesh_mgr.loadingMesh = false
ml_mesh_mgr.loadObjectFile = false
ml_mesh_mgr.averagegameunitsize = 50
ml_mesh_mgr.OMC = 0
ml_mesh_mgr.transitionthreshold = 10 -- distance when to autoset an OMC, like when we we'r walking though a portal or door but are still in the same map


-- GUI Init
function ml_mesh_mgr.ModuleInit()
	
	if (Settings.minionlib.DefaultMaps == nil) then
		Settings.minionlib.DefaultMaps = { }
	end
	Settings.minionlib.gNoMeshLoad = Settings.minionlib.gNoMeshLoad or "0"
	
	GUI_NewWindow(ml_mesh_mgr.mainwindow.name,ml_mesh_mgr.mainwindow.x,ml_mesh_mgr.mainwindow.y,ml_mesh_mgr.mainwindow.w,ml_mesh_mgr.mainwindow.h,"",true)
	GUI_NewComboBox(ml_mesh_mgr.mainwindow.name,GetString("navmesh"),"gmeshname",GetString("generalSettings"),"")
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("noMeshLoad"),"gNoMeshLoad",GetString("generalSettings"))
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("showrealMesh"),"gShowRealMesh",GetString("generalSettings"))
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("showMesh"),"gShowMesh",GetString("generalSettings"))
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("showPath"),"gShowPath",GetString("generalSettings"))
	GUI_UnFoldGroup(ml_mesh_mgr.mainwindow.name,GetString("generalSettings"))	
	
	GUI_NewButton(ml_mesh_mgr.mainwindow.name, GetString("setEvacPoint"), "setEvacPointEvent",GetString("recoder"))
    RegisterEventHandler("setEvacPointEvent",ml_mesh_mgr.SetEvacPoint)
	
	GUI_NewField(ml_mesh_mgr.mainwindow.name,GetString("newMeshName"),"gnewmeshname",GetString("recoder"))
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,GetString("newMesh"),"newMeshEvent",GetString("recoder"))
	RegisterEventHandler("newMeshEvent",ml_mesh_mgr.ClearNavMesh)
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("recmesh"),"gMeshrec",GetString("recoder"))
	GUI_NewComboBox(ml_mesh_mgr.mainwindow.name,GetString("recAreaType"),"gRecAreaType",GetString("recoder"),"Road,Lowdanger,Highdanger")-- enum 1,2,3
	GUI_NewNumeric(ml_mesh_mgr.mainwindow.name,GetString("recAreaSize"),"gRecAreaSize",GetString("recoder"),"1","25")
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("changeMesh"),"gMeshChange",GetString("editor"))
	GUI_NewComboBox(ml_mesh_mgr.mainwindow.name,GetString("changeAreaType"),"gChangeAreaType",GetString("editor"),"Delete,Road,Lowdanger,Highdanger")
	GUI_NewNumeric(ml_mesh_mgr.mainwindow.name,GetString("changeAreaSize"),"gChangeAreaSize",GetString("editor"),"1","10")
	GUI_NewCheckbox(ml_mesh_mgr.mainwindow.name,GetString("biDirOffMesh"),"gBiDirOffMesh",GetString("connections"))
	--GUI_NewComboBox(ml_mesh_mgr.mainwindow.name,GetString("typeOffMeshSpot"),"gOMCType",GetString("connections"),"Jump,Walk,Teleport,Interact,Portal")	
	GUI_NewComboBox(ml_mesh_mgr.mainwindow.name,GetString("typeOffMeshSpot"),"gOMCType",GetString("connections"),"Jump,Walk,Lift,Teleport,Interact,Portal")	
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,GetString("addOffMeshSpot"),"offMeshSpotEvent",GetString("connections"))
	RegisterEventHandler("offMeshSpotEvent", ml_mesh_mgr.AddOMC)
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,GetString("delOffMeshSpot"),"deleteoffMeshEvent",GetString("connections"))
	RegisterEventHandler("deleteoffMeshEvent", ml_mesh_mgr.DeleteOMC)
	
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,"CreateSingleCell","createSingleCell",GetString("recoder"))
	RegisterEventHandler("createSingleCell", ml_mesh_mgr.CreateSingleCell)
	
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,GetString("saveMesh"),"saveMeshEvent") --GetString("editor"))
	RegisterEventHandler("saveMeshEvent",ml_mesh_mgr.SaveMesh)   
	
	GUI_NewButton(ml_mesh_mgr.mainwindow.name,"CTRL+M:ChangeMeshRenderDepth","ChangeMeshDepth")
	RegisterEventHandler("ChangeMeshDepth", function() RenderManager:ChangeMeshDepth() end)  
	
	GUI_SizeWindow(ml_mesh_mgr.mainwindow.name,ml_mesh_mgr.mainwindow.w,ml_mesh_mgr.mainwindow.h)
	GUI_WindowVisible(ml_mesh_mgr.mainwindow.name,false)
	
	gNoMeshLoad = Settings.minionlib.gNoMeshLoad
	gShowRealMesh = "0"
	gShowPath = "0"
	gShowMesh = "0"
	gnewmeshname = ""
	gMeshrec = "0"
	gRecAreaType = "Lowdanger"
	gRecAreaSize = "20"
	gMeshChange = "0"
	gChangeAreaType = "Road"
	gChangeAreaSize = "5"
	gBiDirOffMesh = "0"
	gOMCType = "Jump"
	
	if ( MeshManager ) then
		MeshManager:SetRecordingArea(2)
		MeshManager:RecSize(gRecAreaSize)
		MeshManager:SetChangeToArea(1)
		MeshManager:SetChangeToRadius(gChangeAreaSize)
		MeshManager:SetChangeAreaMode(false)
		MeshManager:Record(false)
		MeshManager:ShowTriMesh(false)
		NavigationManager:ShowNavMesh(false)
	end
	
	ml_mesh_mgr.loadingMesh = false
	ml_mesh_mgr.UpdateMeshfiles() --update the mesh-selection-dropdownfield
	
	
	ml_mesh_mgr.SetupNavNodes()
		
end

-- initializes the marker group, this needs to be called from the main.lua's HandleInit, after all possible marker templates were created or when templatelist was updated
ml_mesh_mgr.registeredevents = {} -- to prevent re-registering of the same events
function ml_mesh_mgr.InitMarkers()
	
	if ( ml_marker_mgr ) then		
		GUI_DeleteGroup(ml_mesh_mgr.mainwindow.name, GetString("markers"))
				
		-- create an ADD button for each type
		if ( ValidString(gMarkerMgrType_listitems) ) then 
			for mtype in StringSplit(gMarkerMgrType_listitems,",") do
										
				GUI_NewButton(ml_mesh_mgr.mainwindow.name,"New "..mtype,"ml_mesh_mgr.NewMarker_"..mtype,GetString("markers"))
				if ( not ml_mesh_mgr.registeredevents["ml_mesh_mgr.NewMarker_"..mtype] ) then
					RegisterEventHandler("ml_mesh_mgr.NewMarker_"..mtype,ml_mesh_mgr.HandleMarkerButtons)
					ml_mesh_mgr.registeredevents["ml_mesh_mgr.NewMarker_"..mtype] = 1
				end
			
			end
		end
		-- Select closest marker
		GUI_NewButton(ml_mesh_mgr.mainwindow.name,GetString("selectClosestMarker"),"ml_mesh_mgr.SelectClosestMarker",GetString("markers"))
		if ( not ml_mesh_mgr.registeredevents["ml_mesh_mgr.SelectClosestMarker"] ) then
			RegisterEventHandler("ml_mesh_mgr.SelectClosestMarker",ml_mesh_mgr.HandleMarkerButtons)
			ml_mesh_mgr.registeredevents["ml_mesh_mgr.SelectClosestMarker"] = 1
		end
	end
end
function ml_mesh_mgr.HandleMarkerButtons( event )
	
	if ( event == "ml_mesh_mgr.SelectClosestMarker") then
		-- Select Closest Marker
		local pPos = ml_mesh_mgr.GetPlayerPos()
		local closestMarker = ml_marker_mgr.GetClosestMarker( pPos.x, pPos.y, pPos.z, ml_mesh_mgr.averagegameunitsize*50)
		if ( closestMarker ) then
			gMarkerMgrType = closestMarker:GetType()
			ml_marker_mgr.CreateEditWindow(closestMarker)
		end
	else
		-- Create a new marker by type
		for mtype in StringSplit(event,"ml_mesh_mgr.NewMarker_") do
			
			if ( ValidString(gMarkerMgrType_listitems) ) then 
				for markertype in StringSplit(gMarkerMgrType_listitems,",") do
					if ( markertype == mtype ) then
						gMarkerMgrType = mtype
						ml_marker_mgr.currentEditMarker = nil
						ml_marker_mgr.NewMarker()
						break
					end
				end
			end
			
		end
	end
end


--Grab all meshfiles in our Navigation directory and update the mesh-selection-dropdownfield
function ml_mesh_mgr.UpdateMeshfiles()
	
	local meshlist = "none"	
	local meshfilelist = dirlist(ml_mesh_mgr.navmeshfilepath,".*obj")
	if ( TableSize(meshfilelist) > 0) then
		local i,meshname = next ( meshfilelist)
		while i and meshname do
			meshname = string.gsub(meshname, ".obj", "")
			meshlist = meshlist..","..meshname
			--d("Adding mesh to list : "..meshname)
			i,meshname = next ( meshfilelist,i)
		end
	end	
	gmeshname_listitems = meshlist
end

--Sets this mapname as default for the mapid if there is nothing set yet
--Automatically adds the mapid to the AllowedMapIDs[] in the .data file, so multiple maps/zones can use the same meshfile
function ml_mesh_mgr.SetDefaultMesh(mapid,mapname)
	if (tonumber(mapid) ~= nil and tonumber(mapid) ~= 0 and mapname ~= "" and mapname ~= "none" and mapname ~= "None" ) then
		if ( Settings.minionlib.DefaultMaps[mapid] == nil or Settings.minionlib.DefaultMaps[mapid] == "" or Settings.minionlib.DefaultMaps[mapid] == "none" or Settings.minionlib.DefaultMaps[mapid] == "None") then
			Settings.minionlib.DefaultMaps[mapid] = mapname
			Settings.minionlib.DefaultMaps = Settings.minionlib.DefaultMaps -- trigger saving of settings
			d( "New DEFAULT mesh "..mapname.." set for mapID "..tostring(mapid))
		end
		
		-- Updating the .data file
		if ( ml_mesh_mgr.navmeshfilepath ~= nil and ml_mesh_mgr.navmeshfilepath ~= "" ) then
			
			if (FileExists(ml_mesh_mgr.navmeshfilepath..mapname..".data")) then					
				local tmpMesh = ml_mesh.Create()
				tmpMesh = persistence.load(ml_mesh_mgr.navmeshfilepath..mapname..".data")
				if (not ValidTable(tmpMesh)) then
					d("Error setting default mesh, no valid ml_mesh table in loaded .data file!")					
				
				else
					-- have to add the new table to existing "old" ml_mesh table
					if ( not tmpMesh.AllowedMapIDs ) then
						tmpMesh.AllowedMapIDs = {}
					end
					-- adding the mapid to the allowedmapid table and saving it
					if ( tmpMesh.AllowedMapIDs[mapid] == nil ) then						
						tmpMesh.AllowedMapIDs[mapid] = mapid
						persistence.store(ml_mesh_mgr.navmeshfilepath..mapname..".data", tmpMesh)
						d(" Added MapID "..tostring(mapid).." to the AllowedMapIDs table of "..mapname)
						
						-- if the mapid is our current mapid then the current mesh table needs to be updated 
						-- otherwise it will double load the mesh
						if (tmpMesh.Name == ml_mesh_mgr.currentMesh.Name) then
							ml_mesh_mgr.currentMesh = tmpMesh
						end
					end
				end
			else
				-- creating a new .data file since it doesnt exist
				d( "WARNING: no .data file found for setting the default mesh: "..mapname.." with mapID: "..tostring(mapid))				
				local tmpMesh = ml_mesh.Create()
				tmpMesh.AllowedMapIDs[mapid] = mapid
				tmpMesh.MapID = mapid
				tmpMesh.Name = mapname				
				persistence.store(ml_mesh_mgr.navmeshfilepath..mapname..".data", tmpMesh)
				d( "Info: Created new default .data file for setting the default mesh: "..mapname.." with mapID: "..tostring(mapid))
			end
		else
		
			d( "Error setting default mesh: navmeshfilepath is nil or empty!")
		end
		
	else
		d( "Error setting default mesh, mapID or name invalid! : "..tostring(mapid).." / "..mapname)
	end	
end
--Updates the mapname as default for the mapid
function ml_mesh_mgr.UpdateDefaultMesh(mapid,mapname)
	if (tonumber(mapid) ~= nil and tonumber(mapid) ~= 0 and mapname ~= "" and mapname ~= "none" and mapname ~= "None" ) then
		if ( Settings.minionlib.DefaultMaps[mapid] ~= mapname ) then
			Settings.minionlib.DefaultMaps[mapid] = mapname
			Settings.minionlib.DefaultMaps = Settings.minionlib.DefaultMaps -- trigger saving of settings
			d( "Updating DEFAULT mesh "..mapname.." set for mapID "..tostring(mapid))
		end
	else
		d( "Error setting default mesh, mapID or name invalid! : "..tostring(mapid).." / "..mapname)
	end	
end
--Removes this mapname as default for the mapid
function ml_mesh_mgr.RemoveDefaultMesh(mapid)
	if (tonumber(mapid) ~= nil and tonumber(mapid) ~= 0 ) then		
		Settings.minionlib.DefaultMaps[mapid] = nil
		Settings.minionlib.DefaultMaps = Settings.minionlib.DefaultMaps -- trigger saving of settings		
	end	
end

-- Use this to load a new / wanted navmesh
function ml_mesh_mgr.LoadNavMesh( meshname )
	if ( meshname ~= nil and meshname ~= 0 and type(meshname) == "string") then
		if ( ml_mesh_mgr.loadingMesh == false ) then
			ml_mesh_mgr.nextNavMesh = meshname
			return true
		else
			d("Meshloading still in progress, cannot switch to new navmesh yet..")
		end		
	end
	return false
end

-- Handles the loading of navmeshes and markerdata when switching maps/meshes, gets called on each OnUpdate()
function ml_mesh_mgr.SwitchNavmesh()

	if (gNoMeshLoad == "1") then
		return false
	end
	
	if ( ml_mesh_mgr.nextNavMesh ~= nil and ml_mesh_mgr.nextNavMesh ~= "" ) then
		
		if ( ml_mesh_mgr.navmeshfilepath ~= nil and ml_mesh_mgr.navmeshfilepath ~= "" ) then
			-- Check if the file exist
			d("Loading Navmesh : " ..ml_mesh_mgr.nextNavMesh)
			-- To prevent (re-)loading or saving of mesh data while the mesh is beeing build/loaded
			ml_mesh_mgr.loadingMesh = true
			if (not NavigationManager:LoadNavMesh(ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh,ml_mesh_mgr.loadObjectFile)) then
				ml_error("Error while trying to load Navmesh: "..ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh)
				ml_marker_mgr.ClearMarkerList()
				ml_marker_mgr.RefreshMarkerNames()
				gmeshname = ""
				gnewmeshname = ""
				ml_mesh_mgr.loadingMesh = false
				
			else
			
				-- Dont reload the obj file again
				ml_mesh_mgr.loadObjectFile = false
								
				-- Update MarkerData from .info file
				ml_marker_mgr.ClearMarkerList()
				
				if (FileExists(ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".info")) then					
					-- REMOVE THIS OLD COMPATIBILITY SHIT AFTER SOME MONTHS WHEN EVERYTHING IS CONVERTED:
					ml_marker_mgr.ReadMarkerFile(ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".info")					
					ml_marker_mgr.DrawMarkerList()
					ml_marker_mgr.RefreshMarkerNames()					
				else
					ml_marker_mgr.markerPath = ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".info" -- this needs to be set, else the markermanager doesnt work when there is no .info file..should probably be fixed on markermanager side and not here
					d("WARNING: ml_mesh_mgr.SwitchNavmesh: No Marker-file exist  : "..ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".info")
					-- create a new file for now, until we decide to move markerdata into mesh data
					ml_marker_mgr.WriteMarkerFile(ml_marker_mgr.markerPath)
				end				
				
				-- Update MeshData from .data file
				if (FileExists(ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".data")) then					
					ml_mesh_mgr.currentMesh = persistence.load(ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".data")
					if (not ValidTable(ml_mesh_mgr.currentMesh)) then
						ml_mesh_mgr.currentMesh = ml_mesh.Create()						
						d("WARNING: while loading meshdata-file from "..ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".data")					
						ml_mesh_mgr.currentMesh.MapID = ml_mesh_mgr.GetMapID()
						ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.currentMesh.MapID] = ml_mesh_mgr.currentMesh.MapID						
						ml_mesh_mgr.currentMesh.Name = ml_mesh_mgr.GetMapName()
						
					else
						-- check if the loaded currentMesh.mapID is good 
						if ( ml_mesh_mgr.currentMesh.MapID == 0 ) then
							ml_error("WARNING: Loaded Navmesh has no MapID:"..tostring(ml_mesh_mgr.currentMesh.MapID))
							d(" Removing the default mesh for this zone from our Defaultmap-list")
							ml_mesh_mgr.RemoveDefaultMesh(ml_mesh_mgr.GetMapID())
						end
						
						-- check if ml_mesh_mgr.currentMesh.MapID is our mapID
						if ( ml_mesh_mgr.currentMesh.MapID ~= ml_mesh_mgr.GetMapID() ) then
							d("WARNING: Loaded Navmesh MapID ~= current MapID() -> wrong NavMesh for this zone loaded ?")
						end
						
						-- adding the AllowedMapIDs table to "old" .info files
						if ( not ml_mesh_mgr.currentMesh.AllowedMapIDs ) then
							ml_mesh_mgr.currentMesh.AllowedMapIDs = {}
							if ( ml_mesh_mgr.currentMesh.MapID ~= 0 ) then
								ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.currentMesh.MapID] = ml_mesh_mgr.currentMesh.MapID
							end
						end
												
						-- check if the loaded ml_mesh_mgr.currentMesh.AllowedMapIDs contains our current mapID which we are in
						if ( ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.GetMapID()] == nil ) then
							d("WARNING: Loaded Navmesh AllowedMapIDs dont contain current MapID -> wrong NavMesh for this zone loaded ?")
							
							-- This can cause a "allowed" for each wrong selected meshfile in the mesh-dropdown field.
							ml_mesh_mgr.SetDefaultMesh(ml_mesh_mgr.GetMapID(), ml_mesh_mgr.nextNavMesh)
						end
						
					end
				else
					d("WARNING: ml_mesh_mgr.SwitchNavmesh: No Data-file exist : "..ml_mesh_mgr.navmeshfilepath..ml_mesh_mgr.nextNavMesh..".data")
					ml_mesh_mgr.currentMesh = ml_mesh.Create()					
					ml_mesh_mgr.currentMesh.MapID = ml_mesh_mgr.GetMapID()
					ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.currentMesh.MapID] = ml_mesh_mgr.currentMesh.MapID
					ml_mesh_mgr.currentMesh.Name = ml_mesh_mgr.GetMapName()
				end				
				
				
				gmeshname = ml_mesh_mgr.nextNavMesh
				ml_mesh_mgr.nextNavMesh = nil			
				return true
			end			
		else
			ml_error("ml_mesh_mgr.SwitchNavmesh: navmeshfilepath is empty!")
		end
		ml_mesh_mgr.nextNavMesh = nil
	end
	
	return false
end

-- Loads the last used navmesh for the current map
function ml_mesh_mgr.LoadNavMeshForCurrentMap()
	-- Load Last/Default Navmesh for this MapID
	ml_mesh_mgr.nextNavMesh = Settings.minionlib.DefaultMaps[tonumber(ml_mesh_mgr.GetMapID())]	
				
	if ( ml_mesh_mgr.SwitchNavmesh() == false ) then		
	-- Init New Navmesh for this MapID		
		d("No default Navmesh found for this map, Initializing a new NavMesh")
		ml_mesh_mgr.ClearNavMesh()
	end
end

-- Main loop
function ml_mesh_mgr.OnUpdate( tickcount )
	local navstate = NavigationManager:GetNavMeshState()
	
	if ( ml_mesh_mgr.loadingMesh or 
		navstate == GLOBAL.MESHSTATE.MESHBUILDING or 
		ml_mesh_mgr.GetMapID() == nil or 
		ml_mesh_mgr.GetMapID() == 0 or 
		ml_mesh_mgr.SwitchNavmesh() == true ) 
	then 
		return 
	end
	
	-- Log Info  (THIS IS FOR GW2 ONLY, IF YOU DONT EMPTY THE ml_log variable this will crash after a while...)
	if ( navstate == GLOBAL.MESHSTATE.MESHEMPTY and gNoMeshLoad == "0" ) then
		ml_log("WARNING: NO NAVMESH LOADED! -> SELECT A NAVMESH IN THE MESHMANAGER FOR THIS ZONE")
	elseif ( navstate == GLOBAL.MESHSTATE.MESHREADY and gNoMeshLoad == "0" ) then
		if ( not ml_global_information.Player_OnMesh ) then			
			ml_log("WARNING: PLAYER IS NOT STANDING ON THE NAVMESH! ")
		end
	end
	
	-- Init default mesh	
	if ( ml_mesh_mgr.currentMesh.MapID == 0 ) then
		ml_mesh_mgr.LoadNavMeshForCurrentMap()		
	else
	-- Check for changed MapID
		if ( ml_mesh_mgr.currentMesh.MapID ~= ml_mesh_mgr.GetMapID() and ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.GetMapID()] == nil and gNoMeshLoad == "0") then
										
			d("MAP/ZONE CHANGED")
			
			-- save old meshdata if meshrecorder is active			
			if ( gMeshrec == "1" ) then
			
				-- Save MapMarker on "old" map/mesh
				--if ( ml_mesh_mgr.currentMesh.LastPlayerPosition.x ~= 0 and ml_marker_mgr.GetClosestMarker( ml_mesh_mgr.currentMesh.LastPlayerPosition.x, ml_mesh_mgr.currentMesh.LastPlayerPosition.y, ml_mesh_mgr.currentMesh.LastPlayerPosition.z, 5, GetString("mapMarker")) == nil and NavigationManager:IsOnMesh(ml_mesh_mgr.currentMesh.LastPlayerPosition) ) then
				if ( ml_mesh_mgr.currentMesh.LastPlayerPosition.x ~= 0 and ml_marker_mgr.GetClosestMarker( ml_mesh_mgr.currentMesh.LastPlayerPosition.x, ml_mesh_mgr.currentMesh.LastPlayerPosition.y, ml_mesh_mgr.currentMesh.LastPlayerPosition.z, 5) == nil ) then
					
					if ( not NavigationManager:IsOnMesh(ml_mesh_mgr.currentMesh.LastPlayerPosition) ) then
						ml_error(" Last position of Player in the last map was NOT on the mesh!")
					end
					
					-- Add MapMarker in mesh
					local newMarker = ml_marker:Create("MapMarker")
					newMarker:SetType(GetString("mapMarker"))
					newMarker:AddField("int", "Target MapID", ml_mesh_mgr.GetMapID())
					newMarker:SetName(tostring(ml_mesh_mgr.currentMesh.Name).." to "..tostring(ml_mesh_mgr.GetMapName()))
					if ( ml_marker_mgr.GetMarker(newMarker:GetName()) ~= nil ) then
						--add a random number onto the name until the string is unique
						local name = ""
						local tries = 0
						repeat
							name = newMarker:GetName()..tostring(tries)
							-- just a little check here to ensure we never get stuck in an infinite loop
							-- if somehow some idiot has the same marker name with 1-99 already
							tries = tries + 1
						until ml_marker_mgr.GetMarker(name) == nil or tries > 99
						newMarker:SetName(name)
					end
					newMarker:SetPosition(ml_mesh_mgr.currentMesh.LastPlayerPosition)
					ml_marker_mgr.AddMarker(newMarker)
					ml_marker_mgr.RefreshMarkerNames()	
					
				end
				-- Save the mesh from the last map				
				ml_mesh_mgr.SaveMesh()				
				return
			end
						
			-- load new mesh
			
			ml_mesh_mgr.LoadNavMeshForCurrentMap()			
			
		else			
			-- update currentmeshdata position
			local myPos = ml_mesh_mgr.GetPlayerPos()
			if (ValidTable(myPos)) then
				ml_mesh_mgr.currentMesh.LastPlayerPosition = {				
					x = myPos.x, 
					y = myPos.y, 
					z = myPos.z, 
					h = myPos.h,
					hx = myPos.hx,
					hy = myPos.hy,
					hz = myPos.hz,
				}
			end
			
			--Left Alt + Right Mouse
			if ( MeshManager:IsKeyPressed(164) and MeshManager:IsKeyPressed(2)) then
				local mousepos = MeshManager:GetMousePos()
				if ( TableSize(mousepos) > 0 ) then	
					if (MeshManager:DeleteRasterTriangle(mousepos)) then
						d("Deletion was successful.")
					end
				end
			end	
			
			-- Record Mesh & Gamedata
			if ( gMeshrec == "1" or gMeshChange == "1") then
				-- Key-Input-Handler
				-- 162 = Left CTRL + Left Mouse
				if ( MeshManager:IsKeyPressed(162) and MeshManager:IsKeyPressed(1)) then --162 is the integervalue of the virtualkeycode (hex)
					MeshManager:RecForce(true)
				else
					MeshManager:RecForce(false)
				end			
				
				-- 162 = Left CTRL 
				if ( MeshManager:IsKeyPressed(162) ) then --162 is the integervalue of the virtualkeycode (hex)
					-- show the mesh if it issnt shown
					if ( gShowMesh == "0" ) then
						MeshManager:ShowTriMesh(true)
					end
					MeshManager:RecSteeper(true)
				else
					if ( gShowMesh == "0" ) then
						MeshManager:ShowTriMesh(false)
					end
					MeshManager:RecSteeper(false)
				end
				
				-- 160 = Left Shift
				if ( MeshManager:IsKeyPressed(160) ) then
					MeshManager:RecSize(2*tonumber(gRecAreaSize))
				else
					MeshManager:RecSize(tonumber(gRecAreaSize))
				end		 
			end
			
		end
	end	
end

function ml_mesh_mgr.SaveMesh()
	if ( ml_mesh_mgr.loadingMesh == false ) then
		
		d("Preparing to save NavMesh...")	
		local rec = gMeshrec
		gMeshrec = "0"
		gMeshChange = "0"		
		MeshManager:Record(false)
		MeshManager:SetChangeAreaMode(false)
		MeshManager:ShowTriMesh(false)
		NavigationManager:ShowNavMesh(false)
		
		if (NavigationManager:IsObjectFileLoaded() == false and gmeshname ~= "none") then
			d("Current mesh has to be loaded before you can save it, please press 'Show Triangles' and let it load before you save again.")
			return
		end
		
		local filename = ""
		-- If a new Meshname is given, create a new file and save it in there
		if ( gnewmeshname ~= nil and gnewmeshname ~= "" ) then
			-- Make sure file doesnt exist
			local found = false
			local meshfilelist = dirlist(ml_mesh_mgr.navmeshfilepath,".*obj")
			if ( TableSize(meshfilelist) > 0) then
				local i,meshname = next ( meshfilelist)
				while i and meshname do
					meshname = string.gsub(meshname, ".obj", "")
					if (meshname == gnewmeshname) then
						d("Mesh with that Name exists already...")
						found = true
						break
					end
					i,meshname = next ( meshfilelist,i)
				end
			end
			if ( not found) then
				-- add new file to list
				gmeshname_listitems = gmeshname_listitems..","..gnewmeshname
			end
			filename = gnewmeshname
			
		-- Else we save it under the selected name
		elseif (gmeshname ~= nil and gmeshname ~= "" and gmeshname ~= "none") then
			filename = gmeshname
		end	
		
		if ( filename ~= "" and filename ~= "none" ) then
			
			d("Saving NavMesh : "..filename)		
			if (NavigationManager:SaveNavMesh(filename)) then
								
				-- Saving of Default Mesh				
				ml_mesh_mgr.UpdateDefaultMesh(ml_mesh_mgr.currentMesh.MapID,filename)
				
				-- Updating mapIDs (this has to be seperated, else the allowedmapids will get the map of the new zone when zoning while recording is on nad the "old" mesh is autosaved
				if ( rec == "1" ) then
					ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.currentMesh.MapID] = ml_mesh_mgr.currentMesh.MapID
				else
					ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.GetMapID()] = ml_mesh_mgr.GetMapID()
				end
				
				-- Save MeshData				
				d("Saving MeshData..")				
				ml_mesh_mgr.SaveMeshData(filename)
				
				-- Update UI
				gmeshname = ml_mesh_mgr.nextNavMesh				
				ml_mesh_mgr.currentMesh.MapID = 0 -- triggers the reloading of the default mesh
				
			else
				ml_error("While saving the current Navmesh: "..filename)
			end
			gnewmeshname = ""
			gmeshname = filename
		else
			ml_error("Enter a new Navmesh name!")
		end
	end
end
-- Saves the additional mesh data into to the data file
function ml_mesh_mgr.SaveMeshData(filename)
	persistence.store(ml_mesh_mgr.navmeshfilepath..filename..".data", ml_mesh_mgr.currentMesh)
end

-- Deletes the current meshdata and resets the meshmanagerdata
function ml_mesh_mgr.ClearNavMesh()
	-- Unload old Mesh
	NavigationManager:UnloadNavMesh()
		    
	-- Delete Markers
	ml_marker_mgr.ClearMarkerList()		
	ml_marker_mgr.RefreshMarkerNames()
						
	-- Create Default Meshdata
	ml_mesh_mgr.currentMesh = ml_mesh.Create()
	ml_mesh_mgr.currentMesh.MapID = ml_mesh_mgr.GetMapID()
	ml_mesh_mgr.currentMesh.AllowedMapIDs[ml_mesh_mgr.currentMesh.MapID] = ml_mesh_mgr.currentMesh.MapID
	ml_mesh_mgr.currentMesh.Name = ml_mesh_mgr.GetMapName()
	gnewmeshname = ml_mesh_mgr.currentMesh.Name or ""
	gmeshname = "none"
	d("Empty NavMesh created...")
end

-- GUI handler
function ml_mesh_mgr.GUIVarUpdate(Event, NewVals, OldVals)
	for k,v in pairs(NewVals) do
		if ( k == "gmeshname" and v ~= "") then
			if ( v ~= "none" ) then
				ml_mesh_mgr.UpdateDefaultMesh(ml_mesh_mgr.GetMapID(),v) -- 
				ml_mesh_mgr.currentMesh.MapID = 0 -- trigger reload of mesh
			else
				ml_mesh_mgr.ClearNavMesh()
			end
		elseif( k == "gShowRealMesh") then
			if (v == "1") then
				NavigationManager:ShowNavMesh(true)
			else
				NavigationManager:ShowNavMesh(false)
			end
		elseif( k == "gShowPath") then
			if (v == "1") then
				NavigationManager:ShowNavPath(true)
			else
				NavigationManager:ShowNavPath(false)
			end			
		elseif( k == "gShowMesh") then
			if (v == "1") then
				ml_mesh_mgr.LoadObjectFile()
				MeshManager:ShowTriMesh(true)
			else
				MeshManager:ShowTriMesh(false)
			end				
		elseif( k == "gMeshrec") then
			if (v == "1") then
				ml_mesh_mgr.LoadObjectFile()
				MeshManager:Record(true)
			else
				MeshManager:Record(false)
			end
		elseif( k == "gRecAreaType") then
			if (v == "Road") then
				MeshManager:SetRecordingArea(1)
			elseif (v == "Lowdanger") then
				MeshManager:SetRecordingArea(2)
			elseif (v == "Highdanger") then
				MeshManager:SetRecordingArea(3)
			end
		elseif( k == "gRecAreaSize") then
			MeshManager:RecSize(tonumber(gRecAreaSize))
		elseif( k == "gMeshChange") then
			if (v == "1") then
				ml_mesh_mgr.LoadObjectFile()
				MeshManager:SetChangeAreaMode(true)
			else
				MeshManager:SetChangeAreaMode(false)
			end
		elseif( k == "gChangeAreaType") then
			if (v == "Road") then
				MeshManager:SetChangeToArea(1)
			elseif (v == "Lowdanger") then
				MeshManager:SetChangeToArea(2)
			elseif (v == "Highdanger") then
				MeshManager:SetChangeToArea(3)
			elseif (v == "Delete") then	
				MeshManager:SetChangeToArea(255)
			end
		elseif( k == "gChangeAreaSize") then
			MeshManager:SetChangeToRadius(tonumber(gChangeAreaSize))
		elseif( k == "gnewmeshname" ) then
			ml_mesh_mgr.currentMesh.Name = v
		elseif( k == "gNoMeshLoad" ) then
			Settings.GW2Minion[tostring(k)] = v
		end
	end
end

-- Gets called when a navmesh is done loading/building
function ml_mesh_mgr.NavMeshUpdate()
	d("Mesh was loaded successfully!")
	gnewmeshname = ""
	ml_mesh_mgr.loadingMesh = false
	if ( gShowMesh == "1" ) then
		ml_mesh_mgr.LoadObjectFile()
		MeshManager:ShowTriMesh(true)
	end
	if ( gShowPath == "1" ) then
		NavigationManager:ShowNavPath(true)
	end
	if ( gShowRealMesh == "1" ) then
		NavigationManager:ShowNavMesh(true)
	end	
	if ( gMeshrec == "1" ) then
		MeshManager:Record(true)
	end
end

-- add offmesh connection
function ml_mesh_mgr.AddOMC()
	
	ml_mesh_mgr.OMC = ml_mesh_mgr.OMC+1
	if (ml_mesh_mgr.OMC == 1 ) then
		ml_mesh_mgr.OMCP1 = ml_global_information.Player_Position
		
	elseif (ml_mesh_mgr.OMC == 2 ) then
		ml_mesh_mgr.OMCP2 = ml_global_information.Player_Position
		
		local omctype
		if ( gOMCType == "Jump" ) then
			omctype = 8
		elseif ( gOMCType == "Walk" ) then
			omctype = 9
			--ml_mesh_mgr.AddOMCBridge(1)
			--return
		elseif ( gOMCType == "Lift" ) then
			omctype = 13
		elseif ( gOMCType == "Teleport" ) then
			omctype = 10
			--ml_mesh_mgr.AddOMCBridge(2)
			--return
		elseif ( gOMCType == "Interact" ) then
			omctype = 11
			--ml_mesh_mgr.AddOMCBridge(3)
			--return
		elseif ( gOMCType == "Portal" ) then			
			omctype = 12
			--ml_mesh_mgr.AddOMCBridge(4)
			--return
		end
		
		-- Default Short Range Jump		
		if ( gBiDirOffMesh == "0" ) then
			MeshManager:AddOffMeshConnection(ml_mesh_mgr.OMCP1,ml_mesh_mgr.OMCP2,false,omctype, {x=ml_mesh_mgr.OMCP1.hx,y=ml_mesh_mgr.OMCP1.hy,z=ml_mesh_mgr.OMCP1.hz},{x=ml_mesh_mgr.OMCP2.hx,y=ml_mesh_mgr.OMCP2.hy,z=ml_mesh_mgr.OMCP2.hz})
		else
			MeshManager:AddOffMeshConnection(ml_mesh_mgr.OMCP1,ml_mesh_mgr.OMCP2,true,omctype, {x=ml_mesh_mgr.OMCP1.hx,y=ml_mesh_mgr.OMCP1.hy,z=ml_mesh_mgr.OMCP1.hz},{x=ml_mesh_mgr.OMCP2.hx,y=ml_mesh_mgr.OMCP2.hy,z=ml_mesh_mgr.OMCP2.hz})
		end
		ml_mesh_mgr.OMC = 0
	end	
end
--d(tostring(vector.x).." / "..tostring(vector.y).." / "..tostring(vector.z))
--d(Player:MoveTo(ml_mesh_mgr.OMCP1.x+vector.x,ml_mesh_mgr.OMCP1.y+vector.y,ml_mesh_mgr.OMCP1.z+vector.z,30,false,true,true)	)

-- will bridge larger distances with singlecells and multiple short range OMCs
function ml_mesh_mgr.AddOMCBridge(omctype)	
	
	-- Get Distance and cut it in "shorter" intervals which we have to bridge with omcs and single cells
	local length = Distance3D(ml_mesh_mgr.OMCP1.x,ml_mesh_mgr.OMCP1.y,ml_mesh_mgr.OMCP1.z,ml_mesh_mgr.OMCP2.x,ml_mesh_mgr.OMCP2.y,ml_mesh_mgr.OMCP2.z)
	
	local intervals = math.ceil(length / 350)
	
	local vector = { x = (ml_mesh_mgr.OMCP2.x-ml_mesh_mgr.OMCP1.x)/length, y = (ml_mesh_mgr.OMCP2.y-ml_mesh_mgr.OMCP1.y)/length, z = (ml_mesh_mgr.OMCP2.z-ml_mesh_mgr.OMCP1.z)/length }
	
	-- Distance is small enough for just 1 OMC
	if ( intervals <= 1 ) then
		d(MeshManager:AddOffMeshConnection(ml_mesh_mgr.OMCP1,ml_mesh_mgr.OMCP2,true,omctype, {x=ml_mesh_mgr.OMCP1.hx,y=ml_mesh_mgr.OMCP1.hy,z=ml_mesh_mgr.OMCP1.hz},{x=ml_mesh_mgr.OMCP2.hx,y=ml_mesh_mgr.OMCP2.hy,z=ml_mesh_mgr.OMCP2.hz}))
	
	else
		local TOposition = {}
		local FROMposition = { x = ml_mesh_mgr.OMCP1.x, y = ml_mesh_mgr.OMCP1.y, z = ml_mesh_mgr.OMCP1.z}
		for i=1,intervals,1 do
			d("Invetval:" ..tostring(i))
			-- Last point 
			if ( i == intervals ) then
				d(MeshManager:AddOffMeshConnection(FROMposition,ml_mesh_mgr.OMCP2,true,omctype, {x=ml_mesh_mgr.OMCP1.hx,y=ml_mesh_mgr.OMCP1.hy,z=ml_mesh_mgr.OMCP1.hz},{x=ml_mesh_mgr.OMCP2.hx,y=ml_mesh_mgr.OMCP2.hy,z=ml_mesh_mgr.OMCP2.hz}))
			
			else
				-- make OMCs with singlecells to bridge the whole distance between original start and end
				
				-- get next interval point
				TOposition.x = FROMposition.x + vector.x*350
				TOposition.y = FROMposition.y + vector.y*350
				TOposition.z = FROMposition.z + vector.z*350
				
				-- Add "To"-point
				d(MeshManager:AddOffMeshConnection(FROMposition,TOposition,true,omctype, {x=ml_mesh_mgr.OMCP1.hx,y=ml_mesh_mgr.OMCP1.hy,z=ml_mesh_mgr.OMCP1.hz},{x=ml_mesh_mgr.OMCP2.hx,y=ml_mesh_mgr.OMCP2.hy,z=ml_mesh_mgr.OMCP2.hz}))
				
				-- Add singleCell
				local newVertexCenter = { x=TOposition.x, y=TOposition.y, z=TOposition.z }
				if ( not NavigationManager:IsOnMeshExact(TOposition) ) then
					d(MeshManager:CreateSingleCell( newVertexCenter))
				end
				
				-- Update "From"-point
				FROMposition.x = TOposition.x
				FROMposition.y = TOposition.y
				FROMposition.z = TOposition.z
				
			end
		end
	end
	ml_mesh_mgr.OMC = 0
end

-- delete offmesh connection
function ml_mesh_mgr.DeleteOMC()
	local pos = ml_global_information.Player_Position
	MeshManager:DeleteOffMeshConnection(pos)
	ml_mesh_mgr.OMC = 0
end

-- Handler for different OMC types
function ml_mesh_mgr.HandleOMC( ... )
	local args = {...}
	local OMCType = args[2]	
	local OMCStartPosition,OMCEndposition,OMCFacingDirection = ml_mesh_mgr.UnpackArgsForOMC( args )
	d("OMC REACHED : "..tostring(OMCType))
	
	if ( ValidTable(OMCStartPosition) and ValidTable(OMCEndposition) and ValidTable(OMCFacingDirection) ) then
		ml_mesh_mgr.OMCStartPosition = OMCStartPosition
		ml_mesh_mgr.OMCEndposition = OMCEndposition
		ml_mesh_mgr.OMCFacingDirection = OMCFacingDirection
		ml_mesh_mgr.OMCType = OMCType
		ml_mesh_mgr.OMCIsHandled = true -- Turn on omc handler
	end
end

ml_mesh_mgr.OMCStartPosition = nil
ml_mesh_mgr.OMCEndposition = nil
ml_mesh_mgr.OMCFacingDirection = nil
ml_mesh_mgr.OMCType = nil
ml_mesh_mgr.OMCIsHandled = false
ml_mesh_mgr.OMCStartPositionReached = false
ml_mesh_mgr.OMCJumpStartedTimer = 0
ml_mesh_mgr.OMCThrottle = 0
function ml_mesh_mgr.OMC_Handler_OnUpdate( tickcount ) 
	if ( ml_mesh_mgr.OMCIsHandled ) then
		ml_global_information.Lasttick = ml_global_information.Now -- Pauses the main bot-loop, no unstuck or continues path creation.
		
		if ( ml_mesh_mgr.OMCThrottle > tickcount ) then -- Throttles OMC actions
			return
		end
		
		-- Update IsMoving with exact data
		ml_global_information.Player_IsMoving = Player:IsMoving() or false
		ml_global_information.Player_Position = Player.pos
		-- Set all position data, pPos = Player pos, sPos = start omc pos and heading, ePos = end omc pos
		local pPos = ml_global_information.Player_Position
		local sPos = {
						x = tonumber(ml_mesh_mgr.OMCStartPosition[1]), y = tonumber(ml_mesh_mgr.OMCStartPosition[2]), z = tonumber(ml_mesh_mgr.OMCStartPosition[3]),
						hx = tonumber(ml_mesh_mgr.OMCFacingDirection[1]), hy = tonumber(ml_mesh_mgr.OMCFacingDirection[2]), hz = tonumber(ml_mesh_mgr.OMCFacingDirection[3]),
					}
		local ePos = {
						x = tonumber(ml_mesh_mgr.OMCEndposition[1]), y = tonumber(ml_mesh_mgr.OMCEndposition[2]), z = tonumber(ml_mesh_mgr.OMCEndposition[3]),
					}
		
		if ( ml_mesh_mgr.OMCStartPositionReached == false ) then
			if ( ValidTable(sPos) ) then
				local dist = Distance3D(sPos.x,sPos.y,sPos.z,pPos.x,pPos.y,pPos.z)
				if ( dist < 35 ) then -- Close enough to start
					d("OMC StartPosition reached..Facing Target Direction..")
					
					Player:SetFacingH(sPos.hx,sPos.hy,sPos.hz) -- Set heading
					ml_mesh_mgr.OMCThrottle = tickcount + 450 -- Pause omc update loop to allow camera to turn (timing untested)
					Player:StopMovement()
					ml_mesh_mgr.OMCStartPositionReached = true
					return
				end
				
				if ( not ml_global_information.Player_IsMoving ) then Player:SetMovement(GW2.MOVEMENTTYPE.Forward) end -- Move towards start location
				Player:SetFacingExact(sPos.x,sPos.y,sPos.z,true) -- Face start location (4th arg: true, turns camera)
				return
			end
			
		else
			
			if ( ml_mesh_mgr.OMCType == "OMC_JUMP" ) then
				if ( ValidTable(ml_mesh_mgr.OMCEndposition) ) then
					-- We are at our start OMC point and are facing the correct direction, now start moving forward and jump
					if ( not ml_global_information.Player_IsMoving ) then
						Player:SetMovement(GW2.MOVEMENTTYPE.Forward)
						
						-- give the bot some time to gain speed before we jump for longer jumps
						local dist = Distance2D(ePos.x,ePos.y,sPos.x,sPos.y)
						local heightdiff = math.abs(ePos.z - pPos.z)
						--d(heightdiff)
						if ( dist > 125) then
							ml_mesh_mgr.OMCThrottle = tickcount + 100
							return
						end
						
					end
					
					Player:SetFacingExact(ePos.x,ePos.y,ePos.z,true)
					
					if (ml_mesh_mgr.OMCJumpStartedTimer == 0 ) then
						Player:Jump()
						ml_mesh_mgr.OMCJumpStartedTimer = ml_global_information.Now
					end
					
					local dist = Distance3D(ePos.x,ePos.y,ePos.z,pPos.x,pPos.y,pPos.z)
					ml_global_information.Player_MovementState = Player:GetMovementState() or 1
					
					local dist2d = Distance2D(ePos.x,ePos.y,pPos.x,pPos.y)
					
					--d("DISTCHECK: "..tostring(dist).."  2d: "..tostring(dist2d))
					
					if ( dist < 25 or (dist < 35 and dist2d < 10)) then
						d("OMC Endposition reached..")
						ml_mesh_mgr.ResetOMC() -- turn off omc handler
						ml_global_information.Lasttick = ml_global_information.Lasttick + 100 -- delay bot after doing omc
					
					elseif(ml_global_information.Player_MovementState ~= GW2.MOVEMENTSTATE.Jumping and ml_global_information.Player_MovementState ~= GW2.MOVEMENTSTATE.Falling and ml_mesh_mgr.OMCJumpStartedTimer ~= 0 and TimeSince(ml_mesh_mgr.OMCJumpStartedTimer) > 350) then
						d("We landed already")
						ml_mesh_mgr.ResetOMC()
						ml_global_information.Lasttick = ml_global_information.Lasttick + 100
					
					elseif( dist > 500 and  ml_mesh_mgr.OMCJumpStartedTimer ~= 0 and TimeSince(ml_mesh_mgr.OMCJumpStartedTimer) > 1500)then
						d("We failed to land on the enposition..use teleport maybe?")
						ml_mesh_mgr.ResetOMC()
					
					elseif(ePos.z < sPos.z and ePos.z < pPos.z and math.abs(ePos.z - pPos.z) > 30 and ml_mesh_mgr.OMCJumpStartedTimer ~= 0 and TimeSince(ml_mesh_mgr.OMCJumpStartedTimer) > 500 ) then
						d("We felt below the OMCEndpoint height..means we missed the landingpoint..")
						ml_mesh_mgr.ResetOMC()
						ml_global_information.Lasttick = ml_global_information.Lasttick + 500
					
					else
						return
					end
				end
			
			elseif ( ml_mesh_mgr.OMCType == "OMC_WALK" ) then
				if ( ValidTable(ml_mesh_mgr.OMCEndposition) ) then
					if ( not ml_global_information.Player_IsMoving ) then Player:SetMovement(GW2.MOVEMENTTYPE.Forward) end
					Player:SetFacingExact(ePos.x,ePos.y,ePos.z,true)
					local dist = Distance3D(ePos.x,ePos.y,ePos.z,pPos.x,pPos.y,pPos.z)
					if ( dist < 50 ) then
						d("OMC Endposition reached..")
						--ml_global_information.Lasttick = ml_global_information.Lasttick + 2000
						ml_mesh_mgr.ResetOMC()
					else
						return
					end
				end
			
			elseif ( ml_mesh_mgr.OMCType == "OMC_LIFT" ) then
				if ( ValidTable(ml_mesh_mgr.OMCStartPosition) ) then
					if ( not ml_global_information.Player_IsMoving ) then Player:SetMovement(GW2.MOVEMENTTYPE.Forward) end
					local dist = Distance3D(sPos.x,sPos.y,sPos.z,pPos.x,pPos.y,pPos.z)
					if ( dist > 250 ) then
						d("OMC Endposition reached..")
						--ml_global_information.Lasttick = ml_global_information.Lasttick + 200
						ml_mesh_mgr.ResetOMC()
					else
						return
					end
				end
			
			elseif ( ml_mesh_mgr.OMCType == "OMC_TELEPORT" ) then
				if ( ValidTable(ml_mesh_mgr.OMCEndposition) ) then
					if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
					-- Add playerdetection when distance to OMCEndposition is > xxx
					local enddist = Distance3D(ePos.x,ePos.y,ePos.z,pPos.x,pPos.y,pPos.z)
					if ( enddist > 220 ) then
						if ( TableSize(CharacterList("nearest,player,maxdistance=1500"))>0 ) then
							ml_log("Need to teleport but players are nearby..waiting..")
							ml_mesh_mgr.OMCThrottle = tickcount + 2000
							ml_global_information.Lasttick = ml_global_information.Lasttick + 1500
							Player:StopMovement()
							return
						end
					end
					Player:Teleport(ePos.x, ePos.y, ePos.z)
					d("OMC Endposition reached..")
					ml_mesh_mgr.ResetOMC()
					
				end
			
			elseif ( ml_mesh_mgr.OMCType == "OMC_INTERACT" ) then
				d("OMC Endposition reached..")
				Player:Interact()
				ml_mesh_mgr.ResetOMC()
			
			elseif ( ml_mesh_mgr.OMCType == "OMC_PORTAL" ) then
				if ( ValidTable(ml_mesh_mgr.OMCEndposition) ) then
					if ( not ml_global_information.Player_IsMoving ) then Player:SetMovement(GW2.MOVEMENTTYPE.Forward) end
					local dist = Distance3D(ePos.x,ePos.y,ePos.z,pPos.x,pPos.y,pPos.z)
					if ( dist < 100 ) then
						d("OMC Endposition reached..")
						ml_global_information.Lasttick = ml_global_information.Lasttick + 2000
						ml_mesh_mgr.ResetOMC()
					else
						return
					end
				end
			
			end
		
		
		end
	end
end

function ml_mesh_mgr.ResetOMC()
	Player:UnSetMovement(GW2.MOVEMENTTYPE.Forward)
	Player:StopMovement()
	ml_mesh_mgr.OMCStartPosition = nil
	ml_mesh_mgr.OMCEndposition = nil
	ml_mesh_mgr.OMCFacingDirection = nil
	ml_mesh_mgr.OMCType = nil
	ml_mesh_mgr.OMCIsHandled = false
	ml_mesh_mgr.OMCStartPositionReached = false
	ml_mesh_mgr.OMCJumpStartedTimer = 0
	ml_mesh_mgr.OMCThrottle = 0
end

function ml_mesh_mgr.UnpackArgsForOMC( args )
	if ( tonumber(args[3]) ~= nil and tonumber(args[4]) ~= nil and tonumber(args[5]) ~= nil -- OMC Start point
	 and tonumber(args[6]) ~= nil and tonumber(args[7]) ~= nil and tonumber(args[8]) ~= nil -- OMC END point
	 and tonumber(args[9]) ~= nil and tonumber(args[10]) ~= nil and tonumber(args[11]) ~= nil -- OMC Start point-Facing direction
	 ) then
		d("ml_mesh_mgr.UnpackArgsForOMC( args )")
		d("facing dirs:")
		d("hx = "..args[9])
		d("hy = "..args[10])
		d("hz = "..args[11])
		return {tonumber(args[3]),tonumber(args[4]),tonumber(args[5]) },{ tonumber(args[6]),tonumber(args[7]),tonumber(args[8])},{tonumber(args[9]),tonumber(args[10]),tonumber(args[11])}
	 else
		d("No valid positions for OMC reveived! ")
	 end
end

function ml_mesh_mgr.CreateSingleCell()
	d("Creating a single cell outside the raster!")
	local pPos = ml_global_information.Player_Position
	local newVertexCenter = { x=pPos.x, y=pPos.y, z=pPos.z }
	d(MeshManager:CreateSingleCell( newVertexCenter))
end

-- Toggle meshmanager Window
function ml_mesh_mgr.ToggleMenu()
	if (ml_mesh_mgr.visible) then
        GUI_WindowVisible(ml_mesh_mgr.mainwindow.name,false)
        ml_mesh_mgr.visible = false
    else
        local wnd = GUI_GetWindowInfo(ml_mesh_mgr.parentWindow.Name)
        if (wnd) then
            GUI_MoveWindow( ml_mesh_mgr.mainwindow.name, wnd.x+wnd.width,wnd.y) 
            GUI_WindowVisible(ml_mesh_mgr.mainwindow.name,true)
			GUI_SizeWindow(ml_mesh_mgr.mainwindow.name,ml_mesh_mgr.mainwindow.w,ml_mesh_mgr.mainwindow.h)
        end        
        ml_mesh_mgr.visible = true
    end
end

-- load the obj file of the mesh for editing functions
function ml_mesh_mgr.LoadObjectFile()
	if ( gmeshname ~= "none" and not NavigationManager:IsObjectFileLoaded()) then
		d("Loading .OBJ file for mesh...")
		ml_mesh_mgr.loadObjectFile = true
		ml_mesh_mgr.LoadNavMesh(gmeshname)
	end
end

function ml_mesh_mgr.SetEvacPoint()
    if (gmeshname ~= "" and ml_global_information.Player_OnMesh ) then
        ml_marker_mgr.markerList["evacPoint"] = ml_global_information.Player_Position
        ml_marker_mgr.WriteMarkerFile(ml_marker_mgr.markerPath)
    end
end

function ml_mesh_mgr.SetupNavNodes()
    for id, neighbors in pairs(ml_mesh_mgr.navData) do
		local node = ml_node:Create()
		if (ValidTable(node)) then
			node.id = id
			for nid, posTable in pairs(neighbors) do
				node:AddNeighbor(nid, posTable)
			end
			ml_nav_manager.AddNode(node)
		end
	end
end


RegisterEventHandler("ToggleMeshManager", ml_mesh_mgr.ToggleMenu)
RegisterEventHandler("GUI.Update",ml_mesh_mgr.GUIVarUpdate)
RegisterEventHandler("Module.Initalize",ml_mesh_mgr.ModuleInit)
RegisterEventHandler("Gameloop.MeshReady",ml_mesh_mgr.NavMeshUpdate)
RegisterEventHandler("Gameloop.OffMeshConnectionReached",ml_mesh_mgr.HandleOMC)

-- Moveto task & Follow task
-- For navigating to further away targets or points, do not use this for short range combat navigation, it will be slow, very slow
-- This task should handle movement, antistuck and do basic things to handle stucks, we'll see how it develops 
gw2_task_moveto = inheritsFrom(ml_task)
gw2_task_moveto.name = "MoveTo"

function gw2_task_moveto.Create()
	local newinst = inheritsFrom(gw2_task_moveto)
    
    --ml_task members
    newinst.valid = true
    newinst.completed = false
    newinst.subtask = nil
    newinst.process_elements = {}
    newinst.overwatch_elements = {}
	
	newinst.targetPos = nil
	newinst.targetID = nil
	newinst.targetRadius = 25
	newinst.stoppingDistance = 25
	newinst.use3d = true
	
	newinst.followNavSystem = false
	newinst.randomMovement = false
	newinst.alwaysRandomMovement = false
	newinst.smoothTurns = true	

    return newinst
end

function gw2_task_moveto:Process()
	ml_log("MoveTo")
	if ( ValidTable(ml_task_hub:CurrentTask().targetPos) ) then
	
		local dist = Distance3D(ml_task_hub:CurrentTask().targetPos.x,ml_task_hub:CurrentTask().targetPos.y,ml_task_hub:CurrentTask().targetPos.z,ml_global_information.Player_Position.x,ml_global_information.Player_Position.y,ml_global_information.Player_Position.z)
		if ( not ml_task_hub:CurrentTask().use3d ) then
			dist = Distance3D(ml_task_hub:CurrentTask().targetPos.x,ml_task_hub:CurrentTask().targetPos.y,ml_global_information.Player_Position.x,ml_global_information.Player_Position.y)
		end
		
		-- Check for valid targetID only when in <2500 range, because gamedata tends to fade at distances. Update data in case it finds the target.
		if ( dist < 2500 ) then
			-- Charlist
			-- Gadgetlist
			-- check for closest point on mesh to compensate for 3D vs mesh differences
			
		end
		
		
		if ( dist <= ml_task_hub:CurrentTask().stoppingDistance + ml_task_hub:CurrentTask().targetRadius ) then
			ml_task_hub:CurrentTask().completed = true
		else

			-- HandleStuck
			if ( not gw2_unstuck.HandleStuck() ) then
				
				-- randomize the randomized movement (lol)
				local randommovement = ml_task_hub:CurrentTask().randomMovement
				if ( not ml_task_hub:CurrentTask().alwaysRandomMovement and math.random(1,2) == 1) then
					randommovement = true
				end
				
				local newnodecount = Player:MoveTo(ml_task_hub:CurrentTask().targetPos.x,ml_task_hub:CurrentTask().targetPos.y,ml_task_hub:CurrentTask().targetPos.z,ml_task_hub:CurrentTask().stoppingDistance+ml_task_hub:CurrentTask().targetRadius,ml_task_hub:CurrentTask().followNavSystem,randommovement,ml_task_hub:CurrentTask().smoothTurns)
							
				if ( ml_global_information.ShowDebug and newnodecount ~= dbPNodes ) then
					dbPNodesLast = dbPNodes
					dbPNodes = newnodecount
				end			
				-- Check for increased node count when the targetpos is the same to prevent back n forth twisting and stuck 
				
				
				-- Errorhandling
				if ( newnodecount < 0 ) then			
				--[[
				-1 : Startpoint not on navmesh
				-2 : Endpoint not on navmesh
				-3 : No path between start and endpoint found
				-4 : Path between start and endpoint has a lenght of 0
				-5 : No path between start and endpoint found
				-6 : Couldn't find a path
				-7 : Distance Playerpos-Targetpos < stoppingthreshold
				-8 : NavMesh is not ready/loaded
				-9 : Player object not valid
				-10 : Moveto coordinates are crap
				]]
					
					if ( newnodecount == -1 ) then
						ml_error(" -1: Player not on navmesh")
						-- try to get to the closest point on the navmesh first
						-- NavigationManager:GetPointToMeshDistance(x,y,z)
						-- NavigationManager:GetClosestPointOnMesh(x,y,z)
					elseif ( newnodecount == -2 ) then
						ml_error(" -2: Endpoint not on navmesh")
						-- try to get instead to the closest point near the endpoint on the navmesh
						-- NavigationManager:GetPointToMeshDistance(x,y,z)
						-- NavigationManager:GetClosestPointOnMesh(x,y,z)
					elseif ( newnodecount == -7 ) then
						ml_error(" -7: Distance Playerpos-Targetpos < stoppingthreshold")
						-- try to lower the targetRadius & stoppingDistance
						if ( ml_task_hub:CurrentTask().targetRadius > 0 ) then
							ml_task_hub:CurrentTask().targetRadius = 0 
						
						elseif ( ml_task_hub:CurrentTask().targetRadius == 0 and ml_task_hub:CurrentTask().stoppingDistance > 0 ) then
							ml_task_hub:CurrentTask().stoppingDistance = 10 
							
						elseif ( ml_task_hub:CurrentTask().targetRadius == 0 and ml_task_hub:CurrentTask().stoppingDistance <= 10 ) then
							ml_log("gw2_task_moveto: Distance Playerpos-Targetpos < stoppingthreshold : "..tostring(newnodecount))
							ml_task_hub:CurrentTask().completed = true
						end
					else
						ml_error("gw2_task_moveto result: "..tostring(newnodecount))
						ml_log("gw2_task_moveto: No Valid Path : "..tostring(newnodecount))
						--ml_task_hub:CurrentTask().completed = true
					
					end			
				end
			end
		end
		
		if ( ml_global_information.ShowDebug ) then 
			dbTPos = (math.floor(ml_task_hub:CurrentTask().targetPos.x * 10) / 10).." / "..(math.floor(ml_task_hub:CurrentTask().targetPos.y * 10) / 10).." / "..(math.floor(ml_task_hub:CurrentTask().targetPos.z * 10) / 10)
			dbTDist = dist
			dbPStopDist = ml_task_hub:CurrentTask().stoppingDistance
			dbTID = tostring(ml_task_hub:CurrentTask().targetID)
			dbStuckCount = gw2_unstuck.stuckCount
			dbStuckTmr = TimeSince(gw2_unstuck.stuckTimer)
			dbJumpCount = gw2_unstuck.jumpCount
			dbLastOnMesh = TimeSince(gw2_unstuck.lastOnMeshTime)
			if ( ValidTable(gw2_unstuck.stuckRandomPos) ) then
				dbStuckRPos = (math.floor(gw2_unstuck.stuckRandomPos.x * 10) / 10).." / "..(math.floor(gw2_unstuck.stuckRandomPos.y * 10) / 10).." / "..(math.floor(gw2_unstuck.stuckRandomPos.z * 10) / 10)
			else
				dbStuckRPos = "0/0/0"
			end
		end
	
	
	else
		ml_log("gw2_task_moveto: No Valid targetPos!")
		ml_task_hub:CurrentTask().completed = true
	end
	
	-- Blocked by gadget check
	-- Water check
	-- Stuck check
	-- Cast Speedbuff check
	-- AoELoot check ? -> common OnUpdate probably	
	
end

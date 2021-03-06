gw2_repair_manager = {}
gw2_repair_manager.damagedLimit = 4
gw2_repair_manager.brokenLimit = 1

function gw2_repair_manager.getClosestRepairMarker(nearby)
	local closestLocation = nil
	local listArg = (nearby == true and ",maxdistance=4000" or "")
	local markers = MapMarkerList("onmesh,nearest,contentID="..GW2.MAPMARKER.Repair..listArg..",exclude_characterid="..ml_blacklist.GetExcludeString(GetString("vendorsrepair")))
	for _,repair in pairs(markers) do
		if (closestLocation == nil or closestLocation.distance > repair.distance) then
			if (nearby == true and repair.pathdistance < 4000) then
				closestLocation = repair
			elseif (nearby ~= true) then
				closestLocation = repair
			end
		end
	end
	return closestLocation
end

function gw2_repair_manager.NeedToRepair(nearby)
	local damaged = 0
	local broken = 0
	for i=0,7 do 
		local equipedItem = Inventory:GetEquippedItemBySlot(i)
		if (equipedItem) then
			local durability = equipedItem.durability 
			if (durability == GW2.ITEMDURABILITY.Broken) then broken = broken + 1 damaged = damaged + 1 end
			if (durability == GW2.ITEMDURABILITY.Damaged) then damaged = damaged + 1 end
		end
	end
	
	if (nearby) then
		return broken > 0 or damaged > 0
	end
	
	return broken >= gw2_repair_manager.brokenLimit or damaged >= gw2_repair_manager.damagedLimit
end

function gw2_repair_manager.RepairAtVendor(marker)
	if (marker) then
		local repair = CharacterList:Get(marker.characterID)
		if (repair == nil) then
			repair = GadgetList:Get(marker.characterID)
		end
		if (repair and repair.isInInteractRange and repair.distance < 100) then
			Player:StopMovement()
			local target = Player:GetTarget()
			if (not target or target.id ~= repair.id) then
				Player:SetTarget(repair.id)
			else
				if (Player:IsConversationOpen() == false) then
					ml_log(" Opening Repair.. ")
					Player:Interact(repair.id)
					ml_global_information.Wait(1500)
					return true
				else
					local result = gw2_common_functions.handleConversation("repair")
					if (result == false) then
						d("Repair blacklisted, cant handle opening conversation.")
						ml_blacklist.AddBlacklistEntry(GetString("vendorsrepair"), repair.id, repair.name, true)
						return false
					elseif (result == nil) then
						ml_global_information.Wait(math.random(520,1200))
						return true
					end
				end
				
			end
		else
			local pos = marker.pos
			if ( pos ) then
				local newTask = gw2_task_moveto.Create()
				newTask.targetPos = pos
				newTask.targetID = marker.characterID
				newTask.targetType = "characterID"
				newTask.name = "MoveTo Vendor(Repair)"
				newTask.useWaypoint = true
				ml_task_hub:CurrentTask():AddSubTask(newTask)
				return true
			end
		end
	end
	return false
end
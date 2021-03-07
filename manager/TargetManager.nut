/*
 *	Copyright © 2008 George Weller
 *	
 *	This file is part of PathZilla.
 *	
 *	PathZilla is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 2 of the License, or
 *	(at your option) any later version.
 *	
 *	PathZilla is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *	
 *	You should have received a copy of the GNU General Public License
 *	along with PathZilla.  If not, see <http://www.gnu.org/licenses/>.
 *
 * TargetManager.nut
 * 
 * Handles all target related functions and object factories. This class should 
 * be used as a singleton.
 * 
 * Author:  George Weller (Zutty)
 * Created: 21/02/2010
 * Version: 1.0
 */
 
class TargetManager {
	// Serialisation constants
	SRLZ_TARGETS = 0;
	
	// Constant functions
	static API = function (type) { return (type == Target.TYPE_TOWN) ? AITown : AIIndustry; }
	
	// Member variables
	targets = null;
	
	constructor() {
		this.targets = {};
	}
}

/*
 * Get the target located at the specified tile.
 */
function TargetManager::GetTarget(tile) {
	return targets[tile];
}

/*
 * Initialise the target with the specified type and id. The id must be from 
 * the NoAI API, either an TownID or an IndustryID.
 */
function TargetManager::InitTarget(type, id) {
	local tile = API(type).GetLocation(id);
	if(!(tile in targets)) targets[tile] <- Target(type, id);
}

/*
 * Create an array of targets from all towns (up to a maximum of MAX_TARGETS)  
 * on the map.
 */
function TargetManager::GetTownTargets() {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, ::pz.homeTown);
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	
	return PickTargets(Target.TYPE_TOWN, allTowns);
}

/*
 * Create an array of targets from all towns (up to a maximum of MAX_TARGETS)  
 * on the map.
 */
function TargetManager::GetTramTargets() {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, ::pz.homeTown);
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	
	// If using trams, only consider large towns
	allTowns.Valuate(AITown.GetPopulation);
	allTowns.RemoveBelowValue(1000);
	
	return PickTargets(Target.TYPE_TOWN, allTowns);
}

/*
 * Create an array of targets from industries on the map that accept or produce 
 * the predefined cargo for this schema. 
 */
function TargetManager::GetIndustryTargets(cargos) {
	local indList = AIList();
	
	// Get a list of all industries that handle the appropriate cargo
	foreach(cargo, _ in cargos) {
		indList.AddList(AIIndustryList_CargoAccepting(cargo));
		indList.AddList(AIIndustryList_CargoProducing(cargo));
	}
	
	return PickTargets(Target.TYPE_INDUSTRY, indList);
}

/*
 * Select a list of targets from the global list that correspond to the ids in
 * the specified list. The ids must be from the NoAI API, either an TownID or 
 * an IndustryID.
 */
function TargetManager::PickTargets(type, apiList) {
	local sublist = {};
	
	// Pick a sub-list of targets from the master list
	foreach(id, _ in apiList) {
		local tile = API(type).GetLocation(id);
		InitTarget(type, id);
		sublist[tile] <- GetTarget(tile);
	}

	return sublist;
}

/*
 * Saves the data to a table.
 */
function TargetManager::Serialize() {
	local data = {};
	
	data[SRLZ_TARGETS] <- {};
	foreach(idx, target in this.targets) {
		data[SRLZ_TARGETS][idx] <- target.Serialize();
	}
	
	return data;
}

/*
 * Loads data from a table.
 */
function TargetManager::Unserialize(data) {
	foreach(idx, targetData in data[SRLZ_TARGETS]) {
		this.targets[idx] <- Target.instance();
		this.targets[idx].Unserialize(targetData);
	}
}
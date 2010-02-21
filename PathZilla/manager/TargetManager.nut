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
}

/*
 * Create an array of targets from all towns (up to a maximum of MAX_TARGETS)  
 * on the map.
 */
function TargetManager::GetTownTargets(schema) {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(schema.GetSourceNode()));
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	
	// HACK: If using trams, only consider large towns
	if(schema.GetSubType() == AIRoad.ROADTYPE_TRAM) {
		allTowns.Valuate(AITown.GetPopulation);
		allTowns.RemoveBelowValue(1000);
	}
	
	// Build a list of targets
	local targets = Map();
	foreach(town, _ in allTowns) {
		targets.Insert(Target(Target.TYPE_TOWN, town));
	}
	
	return targets;
}

/*
 * Create an array of targets from industries on the map that accept or produce 
 * the predefined cargo for this schema. 
 */
function TargetManager::GetIndustryTargets(cargos) {
	// Get a list of all industries that handle the appropriate cargo
	local indList = AIList();
	
	foreach(cargo, _ in cargos) {
		indList.AddList(AIIndustryList_CargoAccepting(cargo));
		indList.AddList(AIIndustryList_CargoProducing(cargo));
	}
		
	// Build a list of targets
	local targets = Map();
	foreach(industry, _ in indList) {
		targets.Insert(Target(Target.TYPE_INDUSTRY, industry));
	}

	return targets;
}
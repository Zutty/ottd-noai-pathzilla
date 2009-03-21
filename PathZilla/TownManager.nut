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
 * TownManager.nut
 * 
 * Handles all transport agnostic town-based functions.
 * 
 * Author:  George Weller (Zutty)
 * Created: 21/03/2009
 * Version: 1.0
 */

class TownManager {
	constructor() {
	}
}

/*
 * Find the nearest town to the specified tile.
 */
function TownManager::FindNearestTown(tile) {
	local townList = AITownList();
	townList.Valuate(AITown.GetDistanceManhattanToTile, tile);
	townList.Sort(AIAbstractList.SORT_BY_VALUE, true);
	return townList.Begin()
}

/*
 * Check if the company is allowed to build anything in the specified town.
 */
function TownManager::CanBuildInTown(town) {
	local rating = AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	return (rating == AITown.TOWN_RATING_NONE || rating > AITown.TOWN_RATING_VERY_POOR);
}

/*
 * Try to improve the local authority rating by bribing and/or building trees.
 */
function TownManager::HandleRating(town) {
	local rating = AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	local townLocation = AITown.GetLocation(town);

	// If the rating is low, take steps to improve it
	if(rating < AITown.TOWN_RATING_GOOD) {
		// See if we can bribe the town
		local canBribe = (AIGameSettings.GetValue("economy.bribe") == 1);
		if(canBribe && rating < AITown.TOWN_RATING_POOR && FinanceManager.CanAfford(PathZilla.BRIBE_THRESHOLD)) {
			AITown.PerformTownAction(town, AITown.TOWN_ACTION_BRIBE);
		}
	}
	
	// Update the rating	
	rating = AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));

	// If the rating is still low, take steps to improve it
	if(rating < AITown.TOWN_RATING_GOOD) {
		// Get a list of tiles to search in
		local searchRadius = min(AIMap.DistanceFromEdge(townLocation) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);

		// After that, find places we can build trees
		local tileList = AITileList();
		tileList.AddRectangle(townLocation - offset, townLocation + offset);
		tileList.Valuate(function (tile, town) {
			return (!AITile.IsWithinTownInfluence(tile, town) && AITile.IsBuildable(tile) && !AITile.HasTreeOnTile(tile)) ? 1 : 0;
		}, town);
		tileList.RemoveValue(0);
		tileList.Valuate(function (tile, townLocation) {
			return AITile.GetDistanceManhattanToTile(tile, townLocation) + AIBase.RandRange(6) - 3;
		}, townLocation);
		tileList.Sort(AIAbstractList.SORT_BY_VALUE, true);
		
		// For the places that are available, build a "green belt" around the town
		if(!tileList.IsEmpty()) {
			local expenditure = 0;
			local tile = tileList.Begin();
			
			while(AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) < AITown.TOWN_RATING_GOOD
					 && expenditure < PathZilla.MAX_TREE_SPEND && tileList.HasNext()) {
				local acc = AIAccounting();
				for(local i = 0; i < 4; i++) {
					AITile.PlantTree(tile);
				}
				expenditure += acc.GetCosts();
				tile = tileList.Next();
			}
		}
	}
}
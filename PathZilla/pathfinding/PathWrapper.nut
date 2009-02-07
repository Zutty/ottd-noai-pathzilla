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
 * PathWrapper.nut
 * 
 * Wrapper for the (modified) library road pathfinder. This class handles
 * general path finding a road construction with robust construction and a
 * path reassesment mechanism sensetive to changes in the map. This class also
 * implements a number of cost decorator functions, which are explained in the 
 * FindPath method below.
 * 
 * Author:  George Weller (Zutty)
 * Created: 15/01/2009
 * Version: 1.1
 */

class PathWrapper {
	// Feature constants
	FEAT_ROAD_LOOP = 1;
	FEAT_SEPARATE_ROAD_TYPES = 2;
	FEAT_GRID_LAYOUT = 3;
	FEAT_DEPOT_ALIGN = 4;
	FEAT_SHORT_SCOPE = 5;
	FEAT_NO_WORMHOLES = 6;
	
	// Costs
	COST_ROAD_LOOP = 3000;
	COST_SEPARATE_ROAD_TYPES = 200;
	COST_PARALLEL_BONUS = 100;
	COST_GRID_LAYOUT = 1000;
	COST_DEPOT_ALIGN = 3000;
	
	constructor() {
	}
}

/*
 * Find a path between the two specified tiles and then attempts to build it up
 * to PathZilla.MAX_REPATH_TRIES times. All parameters are passed up to the 
 * FindPath method.
 */
function PathWrapper::BuildRoad(fromTile, toTile, roadType, ignoreTiles = [], demolish = false, features = []) {
	// First, try to find a path
	local path = PathWrapper.FindPath(fromTile, toTile, roadType, ignoreTiles, demolish, features);

	// If the path could not be found then there is nothing left to try
	if(path == null) {
		AILog.Error("Could not find a path!");
		return false;
	}
	
	AILog.Info("      Done finding path.");
	
	local tries = 0;
	local success = -1;
	
	// Try to build the road
	do {
		success = PathWrapper.BuildPath(path, roadType);
		
		// If we failed, try to find the path from the point it went wrong
		if(success != 0) {
			path = PathWrapper.FindPath(fromTile, success, roadType, ignoreTiles, demolish, features);
		}
	} while(success > 0 && tries++ < PathZilla.MAX_REPATH_TRIES);
	
	// If we still failed after a number of attempts, show an error message
	if(success != 0) {
		AILog.Error("Road cannot be built.")
		return false;
	}
	
	return true;
}

/*
 * Find a path between the specified tiles and return it. The path will be of 
 * type roadType, will go around any tiles specified in the ignoreTiles array.
 * If demolish is true then the path may go through town houses. Additionally
 * a number of features may be specified to control the layout of the eventual
 * path. Any of the following can be specified...
 *
 * FEAT_ROAD_LOOP - Build a loop around the first tile in ignoreTiles
 * FEAT_SEPARATE_ROAD_TYPES - Split road types apart to run in parallel
 * FEAT_GRID_LAYOUT - Snap roads to 2x2/3x3 town layouts
 * FEAT_DEPOT_ALIGN - Join a road to the entrace of a depot not its side
 * FEAT_SHORT_SCOPE - Avoid wasting time on paths that are known to be short
 */
function PathWrapper::FindPath(fromTile, toTile, roadType, ignoreTiles = [], demolish = false, features = []) {
	// Initialise the pathfinder
	local pathfinder = Road();
	pathfinder.cost.allow_demolition = demolish;
	pathfinder.cost.no_existing_road = 150;
	pathfinder.cost.max_bridge_length  = PathZilla.MAX_BRIDGE_LENGTH;
	pathfinder.cost.bridge_per_tile = 350;
	pathfinder.InitializePath([fromTile], [toTile], ignoreTiles);

	// Add on any additional features
	foreach(feat in features) {
		switch(feat) {
			case PathWrapper.FEAT_ROAD_LOOP:
				local sideRoadList = LandManager.GetAdjacentTileList(ignoreTiles[0]);
				sideRoadList.RemoveTile(toTile);
				sideRoadList.RemoveTile(LandManager.GetApproachTile(ignoreTiles[0], toTile));
				local sideRoads = ListToArray(sideRoadList);

				pathfinder.RegisterCostCallback(function (tile, prevTile, sideRoads) {
					return (tile == sideRoads[0] || tile == sideRoads[1]) ? PathWrapper.COST_ROAD_LOOP : 0;
				}, sideRoads);
			break;
			case PathWrapper.FEAT_SEPARATE_ROAD_TYPES:
				pathfinder.RegisterCostCallback(function (tile, prevTile, roadType) {
					local diff = AIMap.GetMapSizeY() / (tile - prevTile);
					local parrl = (AIRoad.IsRoadTile(tile + diff) && !AIRoad.HasRoadType(tile + diff, roadType))
								|| (AIRoad.IsRoadTile(tile - diff) && !AIRoad.HasRoadType(tile - diff, roadType));
					return ((AIRoad.IsRoadTile(tile) && !AIRoad.HasRoadType(tile, roadType)) ? PathWrapper.COST_SEPARATE_ROAD_TYPES : 0) + ((parrl) ? 0 : PathWrapper.COST_PARALLEL_BONUS);
				}, roadType);
			break;
			case PathWrapper.FEAT_GRID_LAYOUT:
				local n = AIGameSettings.GetValue("economy.town_layout").tointeger();
				if((n == 3 || n == 4) && roadType == AIRoad.ROADTYPE_ROAD) {
					pathfinder.RegisterCostCallback(function (tile, prevTile, n) {
						local dx = abs(tile % AIMap.GetMapSizeY());
						local dy = abs(tile / AIMap.GetMapSizeY());
						return (dx % n == 0 || dy % n == 0) ? 0 : PathWrapper.COST_GRID_LAYOUT;
					}, n);
				}
			break;
			case PathWrapper.FEAT_DEPOT_ALIGN:
				local sideTileList = LandManager.GetAdjacentTileList(toTile);
				sideTileList.Valuate(function (tile, roadType) {
					return AIRoad.IsRoadTile(tile) && AIRoad.HasRoadType(tile, roadType);
				}, roadType);
				sideTileList.KeepValue(0);
				local sideTiles = ListToArray(sideTileList);
				if(sideTiles.len() < 4) {
					pathfinder.RegisterCostCallback(function (tile, prevTile, sideTiles) {
						local misaligned = false;
						if(sideTiles.len() >= 3) misaligned = misaligned || (tile == sideTiles[2]);
						if(sideTiles.len() >= 2) misaligned = misaligned || (tile == sideTiles[1]);
						if(sideTiles.len() >= 1) misaligned = misaligned || (tile == sideTiles[0]);
						return (misaligned) ? PathWrapper.COST_DEPOT_ALIGN : 0;
					}, sideTiles);
				}
			break;
			case PathWrapper.FEAT_SHORT_SCOPE:
				pathfinder.cost.max_cost = 60000;
			break;
			case PathWrapper.FEAT_NO_WORMHOLES:
				pathfinder.cost.max_tunnel_length = 1;
				pathfinder.cost.max_bridge_length = 1;
			break;
		}
	}

	AILog.Info("    Trying find a path between [" + AIMap.GetTileX(fromTile) + ", " + AIMap.GetTileY(fromTile) + "] and [" + AIMap.GetTileX(toTile) + ", " + AIMap.GetTileY(toTile) + "]...");

	// Make the necessary preparations
	FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	AIRoad.SetCurrentRoadType(roadType);
	
	// If we are very poor, do not attempt to build tunnels
	if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
		pathfinder.cost.max_tunnel_length = 1;
	}

	// Run the pathfinder
	local path = false;
	local steps = 0;
	while (path == false) {
		path = pathfinder.FindPath(PathZilla.PROCESSING_PRIORITY);
		PathZilla.Sleep(1);
	}

	// Return the finished path
	return path;
}

/*
 * Build the path specified by path as a road of type roadType. If there any
 * construction errors the method will re-try to a limited extent. If this also
 * fails the method will return non-zero. If the returned value is greater than
 * zero it indicates the tile just before which construction failed. If it is 
 * less than zero it indicates that construction strictly cannot be completed.
 */
function PathWrapper::BuildPath(path, roadType) {	
	AIRoad.SetCurrentRoadType(roadType);
	local prevTile = null;

	AILog.Info("      Building a road...")

	while (path != null) {
		local par = path.GetParent();
		local tile = path.GetTile();

		if (par != null) {
			local ptile = par.GetTile();
			local distance = AIMap.DistanceManhattan(tile, ptile);

			FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);

			// Check if we need to demolish the tile (e.g. is a town house is in the way)
			if(!AITile.IsBuildable(ptile) && !(AIRoad.IsRoadTile(ptile) || AIBridge.IsBridgeTile(ptile) || AITunnel.IsTunnelTile(ptile))) {
				AITile.DemolishTile(ptile);
				FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
			}
			
			local success = false;
			local attempts = 0;
			local ignore = false;
			local noError = false;

			// Try to build the next path segment
			while(!success && attempts++ < PathZilla.MAX_CONSTR_ATTEMPTS) {
				if(distance == 1) {
					success = AIRoad.BuildRoad(tile, ptile);
				} else {
					// Build a bridge or tunnel.
					if(!AIBridge.IsBridgeTile(tile) && !AITunnel.IsTunnelTile(tile)) {
						// If it was a road tile, demolish it first. Do this to work around expended roadbits.
						if(AIRoad.IsRoadTile(tile)) AITile.DemolishTile(tile);
						
						if(AITunnel.GetOtherTunnelEnd(tile) == ptile) {
							success = AITunnel.BuildTunnel(AIVehicle.VT_ROAD, tile);
						} else {
							local bridgeType = LandManager.ChooseBridgeType(tile, ptile);
							success = AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridgeType, tile, ptile);
						}
					}
				}
				
				// If something went wrong, try to fix it
				if(!success) {
					switch(AIError.GetLastError()) {
						case AIError.ERR_AREA_NOT_CLEAR:
							// Something must have been built since we check the tile. Clear it.
							if(AITile.DemolishTile(tile)) {
								noError = true;
							}
						break;
						case AIError.ERR_NOT_ENOUGH_CASH:
							if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
								// We cant afford to borrow any more money, so give up!
								AILog.Error("      Cannot afford path segment!");
								attempts = PathZilla.MAX_CONSTR_ATTEMPTS + 1;
							} else {
								// Otherwise, borrow some more money
								FinanceManager.Borrow();
							}
						break;
						case AIError.ERR_VEHICLE_IN_THE_WAY:
							// Theres a vehicle in the way... just wait a bit.
							PathZilla.Sleep(50);
						break;
						// Just don't worry about the rest of these cases!
						case AIError.ERR_ALREADY_BUILT:
							ignore = true;
						break;
						case AIError.ERR_UNKNOWN:
							ignore = true;
						break;
					}
				}
				
				// Check that we DID succeed
				if(!success && !ignore && !noError) {
					AILog.Error("    Could not complete road!")
					return (prevTile != null) ? prevTile : tile;
				}

				// If its an error we can ignore then just break.
				if(ignore) break;
			}
		}
		
		prevTile = tile;
		path = par;
	}
	
	AILog.Info("    Done building road.")

	return 0;
}
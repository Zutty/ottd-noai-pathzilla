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
 * Version: 1.2
 */

class PathWrapper {
	// Feature constants
	FEAT_ROAD_LOOP = 1;
	FEAT_SEPARATE_ROAD_TYPES = 2;
	FEAT_GRID_LAYOUT = 3;
	FEAT_DEPOT_ALIGN = 4;
	FEAT_SHORT_SCOPE = 5;
	FEAT_NO_WORMHOLES = 6;
	FEAT_COUNTRY_LANE = 7;
	
	// Costs
	COST_ROAD_LOOP = 3000;
	COST_SEPARATE_ROAD_TYPES = 200;
	COST_PARALLEL_BONUS = 100;
	COST_GRID_LAYOUT = 1000;
	COST_DEPOT_ALIGN = 3000;
	COST_COUNTRY_LANE = 1250;
	
	constructor() {
	}
}

/*
 * Find a path between the two specified tiles and then attempt to build it. All
 * parameters are passed up to the FindPath and TryBuldPath methods. 
 */
function PathWrapper::BuildRoad(fromTile, toTile, roadType, ignoreTiles = [], demolish = false, features = []) {
	// First, try to find a path
	local path = PathWrapper.FindPath(fromTile, toTile, roadType, ignoreTiles, demolish, features);

	// If the path could not be found then there is nothing left to try
	if(path == null) {
		AILog.Error("Could not find a path!");
		return false;
	}
	
	return PathWrapper.TryBuildPath(path, fromTile, toTile, roadType, ignoreTiles , demolish, features);
}
	
/*
 * Try to build ithe speciofied path with the specified road type up to
 * PathZilla.MAX_REPATH_TRIES timesm using the BuildPath method.
 */
function PathWrapper::TryBuildPath(path, fromTile, toTile, roadType, ignoreTiles = [], demolish = false, features = []) {
	local tries = 0;
	local success = -1;
	
	// Try to build the path
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
 * FEAT_NO_WORMHOLES - Disallow bridges and tunnels
 */
function PathWrapper::FindPath(fromTile, toTile, roadType, ignoreTiles = [], demolish = false, features = []) {
	// Ignore traffic black spots
	ignoreTiles.extend(ListToArray(::trafficBlackSpots));

	// Initialise the pathfinder
	local pathfinder = Road();
	pathfinder.cost.allow_demolition = demolish;
	pathfinder.cost.demolition = 1000;
	pathfinder.cost.no_existing_road = 150;
	pathfinder.cost.max_bridge_length = PathZilla.MAX_BRIDGE_LENGTH;
	pathfinder.cost.bridge_per_tile = 350;
	pathfinder.cost.tunnel_per_tile = 240;
	pathfinder.InitializePath([fromTile], [toTile], 2, 20, ignoreTiles);
	
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
				if((n >= 2 && n <= 4) && roadType == AIRoad.ROADTYPE_ROAD) {
					local towns = AITownList();
					
					// Find the nearest town to the "from" tile
					towns.Valuate(AITown.GetDistanceManhattanToTile, fromTile);
					towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
					local fTown = towns.Begin();
					local fTile = AITown.GetLocation(fTown);
					
					// Get some details about this town
					local fType = AITown.GetRoadLayout(fTown);
					local fSize = AITown.GetPopulation(fTown).tofloat(); 
					local fn = (fType == AITown.ROAD_LAYOUT_2x2) ? 3 : ((fType == AITown.ROAD_LAYOUT_3x3) ? 4 : 0);
					local fx = fTile % AIMap.GetMapSizeY();
					local fy = fTile / AIMap.GetMapSizeY();

					// Find the nearest town to the "to" tile
					towns.Valuate(AITown.GetDistanceManhattanToTile, toTile);
					towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
					local tTown = towns.Begin();
					local tTile = AITown.GetLocation(tTown);
					
					// If both towns are the same then we only need to check one grid
					if(fTown == tTown && fn > 0) {
						pathfinder.RegisterCostCallback(function (tile, prevTile, n, fx, fy) {
							local x = tile % AIMap.GetMapSizeY();
							local y = tile / AIMap.GetMapSizeY();
							local dx = abs(x - fx) % n;
							local dy = abs(y - fy) % n;
							local len = AIMap.DistanceManhattan(tile, prevTile);
							
							if(len > 1) {
								local px = prevTile % AIMap.GetMapSizeY();
								local py = prevTile / AIMap.GetMapSizeY();
								//local pdx = abs(px - fx) % n;
								local pdy = abs(py - fy) % n;
								
								if((x == px && dx == 0) || (y == py && dy == 0)) return 0;

								local m = 0;
								if(dy == pdy) {
									m = ((dx == 0) ? 1 : 0) + (len / n);
								} else {
									m = ((dy == 0) ? 1 : 0) + (len / n);
								}
								
								return PathWrapper.COST_GRID_LAYOUT * (len - m);
							} else {
								return (dx == 0 || dy == 0) ? 0 : PathWrapper.COST_GRID_LAYOUT;
							}
						}, fn, fx, fy);
					} else if(fTown != tTown) {
						// Otherwise get details about the other town
						local tType = AITown.GetRoadLayout(tTown);
						local tSize = AITown.GetPopulation(tTown).tofloat(); 
						local tn = (tType == AITown.ROAD_LAYOUT_2x2) ? 3 : ((tType == AITown.ROAD_LAYOUT_3x3) ? 4 : 0);
						local tx = tTile % AIMap.GetMapSizeY();
						local ty = tTile / AIMap.GetMapSizeY();
						
						// Calculate grid weights for each town based on population
						local fWeight = min(0.8, max(0.2, fSize / (fSize + tSize))); 
						local tWeight = min(0.8, max(0.2, tSize / (fSize + tSize))); 

						// Calculate the distance between towns and initialise
						local totalDist = AITile.GetDistanceManhattanToTile(fTile, tTile).tofloat();
						local stx = (tx - fx).tofloat() / totalDist;
						local sty = (ty - fy).tofloat() / totalDist;
						local fRad = null;
						local tRad = null;
						
						// Find the "radii" of the two towns, by plotting a line between them
						for(local i = 0; i < totalDist; i++) {
							local tile = (fx + (stx * i.tofloat()) +  ((fy + (sty * i.tofloat())).tointeger() * AIMap.GetMapSizeY())).tointeger();
				
							if(!AITown.IsWithinTownInfluence(fTown, tile) && fRad == null) {
								fRad = i - 1;
								if(tRad != null) break;
							}
							if(AITown.IsWithinTownInfluence(tTown, tile) && tRad == null) {
								tRad = totalDist - i;
								if(fRad != null) break;
							}
						}
						if(fRad == null) fRad = totalDist;

						// If either town has a grid road layout then interpolate between the two
						if(fn > 0 || tn > 0) {
							pathfinder.RegisterCostCallback(function (tile, prevTile, fTile, fWeight, fRad, fn, fx, fy, tTile, tWeight, tRad, tn, tx, ty) {
								local x = tile % AIMap.GetMapSizeY();
								local y = tile / AIMap.GetMapSizeY();
								local fdx, fdy, tdx, tdy;
								if(fn > 0) {
									fdx = abs(x - fx) % fn;
									fdy = abs(y - fy) % fn;
								}
								if(tn > 0) {
									tdx = abs(x - tx) % tn;
									tdy = abs(y - ty) % tn;
								}

								local len = AIMap.DistanceManhattan(tile, prevTile);
								local fCost = 0;
								local tCost = 0;
		
								// Account for bridges and tunnels
								if(len > 1) {
									local px = prevTile % AIMap.GetMapSizeY();
									local py = prevTile / AIMap.GetMapSizeY();
									local fpdy = (fn > 0) ? abs(py - fy) % fn : 0;
									local tpdy = (tn > 0) ? abs(py - ty) % tn : 0;
									
									local fm = 0;
									if(fn > 0) {
										if(fdy == fpdy) {
											fm = ((fdx == 0) ? 1 : 0) + (len / fn);
										} else {
											fm = ((fdy == 0) ? 1 : 0) + (len / fn);
										}
									}

									local tm = 0;
									if(tn > 0) {
										if(tdy == fpdy) {
											tm = ((tdx == 0) ? 1 : 0) + (len / tn);
										} else {
											tm = ((tdy == 0) ? 1 : 0) + (len / tn);
										}
									}
									
									fCost = (fn == 0 || (x == px && fdx == 0) || (y == py && fdy == 0)) ? 0.0 : PathWrapper.COST_GRID_LAYOUT * (len - fm - 0.0);
									tCost = (tn == 0 || (x == px && tdx == 0) || (y == py && tdy == 0)) ? 0.0 : PathWrapper.COST_GRID_LAYOUT * (len - tm - 0.0);
								} else {
									fCost = (fn == 0 || fdx == 0 || fdy == 0) ? 0.0 : PathWrapper.COST_GRID_LAYOUT.tofloat();
									tCost = (tn == 0 || tdx == 0 || tdy == 0) ? 0.0 : PathWrapper.COST_GRID_LAYOUT.tofloat();
								}
		
								local fDist = AITile.GetDistanceManhattanToTile(tile, fTile).tofloat();
								local tDist = AITile.GetDistanceManhattanToTile(tile, tTile).tofloat();
								local total = (fDist + tDist) - (fRad + tRad);
								local GRID_MIX_DEAD_SPOT = 0.05;

								// Calculate the balancing weights based on our location within either town
								local fBal, tBal;
								if(fDist < fRad) {
									// If inside the "from" town, only apply the "from" grid
									fBal = 1.0;
									tBal = 0.0;
								} else if(tDist < tRad){
									// If inside the "to" town, only apply the "to" grid
									fBal = 0.0;
									tBal = 1.0;
								} else {
									// Otherwise mix the two grids based on a weighted distance
									fBal = max(0.0, ((tDist - tRad) / (total * (fWeight + GRID_MIX_DEAD_SPOT))) - ((1 / (fWeight + GRID_MIX_DEAD_SPOT)) - 1));
									tBal = max(0.0, ((fDist - fRad) / (total * (tWeight + GRID_MIX_DEAD_SPOT))) - ((1 / (tWeight + GRID_MIX_DEAD_SPOT)) - 1));
								}

								return ((fBal * fCost) + (tBal * tCost)).tointeger();
							}, fTile, fWeight, fRad, fn, fx, fy, tTile, tWeight, tRad, tn, tx, ty);
						}
					}
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
			case PathWrapper.FEAT_COUNTRY_LANE:
				if(Settings.EnableCountryLanes() && roadType == AIRoad.ROADTYPE_ROAD) {
					local towns = AITownList();
					
					// Find the nearest town to the "from" tile
					towns.Valuate(AITown.GetDistanceManhattanToTile, fromTile);
					towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
					local fSize = AITown.GetPopulation(towns.Begin());
					local fType = AITown.GetRoadLayout(towns.Begin());
					local fGrid = (fType == AITown.ROAD_LAYOUT_2x2 || fType == AITown.ROAD_LAYOUT_3x3);
					
					// Find the nearest town to the "to" tile
					towns.Valuate(AITown.GetDistanceManhattanToTile, toTile);
					towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
					local tSize = AITown.GetPopulation(towns.Begin());
					local tType = AITown.GetRoadLayout(towns.Begin());
					local tGrid = (tType == AITown.ROAD_LAYOUT_2x2 || tType == AITown.ROAD_LAYOUT_3x3);
					
					// Get the year
					local year = AIDate.GetYear(AIDate.GetCurrentDate());
					local LATE_YEAR = 1990;
					local EARLY_YEAR = 1950;
					
					// If the towns are small and simple eough, add cost for trees and rough terrain, to make the road "windy"
					if(year < LATE_YEAR && ((year >= EARLY_YEAR && !fGrid && !tGrid) || year < EARLY_YEAR) && fSize < 1000 && tSize < 1000) {
						pathfinder.RegisterCostCallback(function (tile, prevTile) {
							local len = AIMap.DistanceManhattan(tile, prevTile);
							if(len > 1) return PathWrapper.COST_COUNTRY_LANE * len;
							local slope = AITile.GetSlope(tile);
							local unevenTerrain = !(slope == AITile.SLOPE_FLAT || slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW || slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SE);
							return (unevenTerrain || AITile.HasTreeOnTile(tile) || AITile.IsFarmTile(tile) || AITile.IsRockTile(tile) || AITile.IsRoughTile(tile)) ? PathWrapper.COST_COUNTRY_LANE : 0;
						});
					}
				}
			break;
		}
	}

	AILog.Info("    Trying to find a path between [" + AIMap.GetTileX(fromTile) + ", " + AIMap.GetTileY(fromTile) + "] and [" + AIMap.GetTileX(toTile) + ", " + AIMap.GetTileY(toTile) + "]...");

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

	AILog.Info("      Done finding path.");

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
	local stopList = AIList();

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

			// Try to build the next path segment
			while(!success && attempts++ < PathZilla.MAX_CONSTR_ATTEMPTS) {
				if(distance == 1) {
					if(!(AIRoad.IsRoadTile(ptile) && AIRoad.AreRoadTilesConnected(tile, ptile))) {
						success = AIRoad.BuildRoad(tile, ptile);
					} else {
						success = true;
					}
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
					} else {
						success = true;
					}
				}
				
				// If something went wrong, try to fix it
				if(!success) {
					switch(AIError.GetLastError()) {
						case AIError.ERR_AREA_NOT_CLEAR:
							// Something must have been built since we check the tile. Clear it.
							if(!AITile.DemolishTile(tile)) {
								if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
									// Try to influence the local authority 
									TownManager.HandleRating(TownManager.FindNearestTown(tile));
								} else {
									// Otherwise just give up
									attempts = PathZilla.MAX_CONSTR_ATTEMPTS + 1;
								}
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
							// Theres a vehicle in the way...
							if(attempts == 2) {
								// If we've already tried once, try to clear 
								// any of our own vehicles out of the way

								// First, find those vehicles that are blocking
								// the tile to be built on
								local blockers = AIVehicleList();
								blockers.Valuate(AIVehicle.GetVehicleType)
								blockers.KeepValue(AIVehicle.VT_ROAD);
								blockers.Valuate(AIVehicle.GetLocation);
								blockers.KeepValue(ptile);

								// Then find those vehicles that lie just outside
								// the tile to be built on
								local outliers = AIVehicleList();
								outliers.Valuate(AIVehicle.GetVehicleType)
								outliers.KeepValue(AIVehicle.VT_ROAD);
								outliers.Valuate(function (v, ptile) {
									return AITile.GetDistanceManhattanToTile(ptile, AIVehicle.GetLocation(v));
								}, ptile);
								outliers.KeepValue(1);
								
								// Stop the outliers from moving into the tile
								foreach(v, _ in outliers) {
									if(AIVehicle.GetState(v) != AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
									stopList.AddItem(v, 0);
								}

								// Move the blockers out of the way
								foreach(v, _ in blockers) AIVehicle.ReverseVehicle(v);
							} else if(attempts == PathZilla.MAX_CONSTR_ATTEMPTS) {
								// If we STILL can't build due to traffic, remember the spot
								::trafficBlackSpots.AddItem(ptile, 0);
							}

							// Just try waiting a bit
							PathZilla.Sleep(30);
						break;
						// Just don't worry about the rest of these cases!
						case AIError.ERR_ALREADY_BUILT:
							success = true;
						break;
						case AIError.ERR_UNKNOWN:
							success = true;
						break;
					}
				}
			}

			// Check that we DID succeed
			if(!success) {
				// Restart any stopped vehicles
				foreach(v, _ in stopList) {
					if(AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
				}

				AILog.Error("    Could not complete road!")
				return (prevTile != null) ? prevTile : tile;
			}
		}
		
		prevTile = tile;
		path = par;
	}

	// Restart any stopped vehicles
	foreach(v, _ in stopList) { 
		if(AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
	}

	AILog.Info("    Done building road.")

	return 0;
}

function PathWrapper::GetFirstTile(path) {
	local cpath = clone path;
	local tile = null;
	while (cpath != null) {
		if(cpath.GetParent() != null) tile = cpath.GetTile(); 
		cpath = cpath.GetParent();
	}
	return tile;
}
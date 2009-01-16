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
 * Wrapper for the (modified) library road pathfinder.
 * 
 * Author:  George Weller (Zutty)
 * Created: 15/01/2009
 * Version: 1.0
 */

class PathWrapper {
	constructor() {
	}
}

function PathWrapper::BuildRoad(fromTile, toTile, roadType, ignoreTiles = [], buildDepot = true, demolish = false) {
	local pathfinder = Road();
	pathfinder.cost.allow_demolition = demolish;
	pathfinder.cost.no_existing_road = 150;
	pathfinder.InitializePath([fromTile], [toTile], ignoreTiles);
	if(demolish) {
		pathfinder.RegisterCostCallback(function (new_tile, prev_tile) {
			return (new_tile == 39138) ? 2000 : 0;
		});
	}
	
	FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
	AILog.Info("  Searching for a path between [" + AIMap.GetTileX(fromTile) + ", " + AIMap.GetTileY(fromTile) + "] and [" + AIMap.GetTileX(toTile) + ", " + AIMap.GetTileY(toTile) + "]...");

	local path = false;
	local steps = 0;
	while (path == false) {
		path = pathfinder.FindPath(100);
		if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
	}
	
	AILog.Info("    Done.");

	AIRoad.SetCurrentRoadType(roadType);

	local builtDepot = !buildDepot;
	local halfWayPoint = AIMap.DistanceManhattan(fromTile, toTile) / 2; // Manhattan distance is only lower bound, but best we can do
	local distance = 0;
	local counter = 0;

	while (path != null) {
		local par = path.GetParent();
		local tile = path.GetTile();

		if (par != null) {
			local ptile = par.GetTile();
			distance = AIMap.DistanceManhattan(tile, ptile);

			FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);

			if(!AITile.IsBuildable(ptile) && !(AIRoad.IsRoadTile(ptile) || AIBridge.IsBridgeTile(ptile) || AITunnel.IsTunnelTile(ptile))) {
				AITile.DemolishTile(ptile);
				AISign.BuildSign(ptile, "X");
				FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
			}
			
			local success = false;
			local attempts = 0;
			local MAXIMUM_ATTEMPTS = 100;
			local ignore = false;

			while(!success && attempts++ < MAXIMUM_ATTEMPTS) {
				if (distance == 1) {
					success = AIRoad.BuildRoad(tile, ptile);
				} else {
					// Build a bridge or tunnel.
					if (!AIBridge.IsBridgeTile(tile) && !AITunnel.IsTunnelTile(tile)) {
						// If it was a road tile, demolish it first. Do this to work around expended roadbits.
						if (AIRoad.IsRoadTile(tile)) AITile.DemolishTile(tile);
						
						if (AITunnel.GetOtherTunnelEnd(tile) == ptile) {
							success = AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, tile);
						}
					} else {
						local bridgeType = LandManager.ChooseBridgeType(tile, ptile);
						success = AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridgeType, tile, ptile);
					}
				}
				
				if(!success) {
					switch(AIError.GetLastError()) {
						case AIError.ERR_AREA_NOT_CLEAR:
							// Something must have been built since we check the tile. Clear it.
							AITile.DemolishTile(tile);
						break;
						case AIError.ERR_NOT_ENOUGH_CASH:
							if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
								// We cant afford to borrow any more money, so give up!
								AILog.Error("          CAN'T AFFORD IT - ABORTING!");
								return false;
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
				
				// If its an error we can ignore then just break.
				if(ignore) break;
			}
		}

		// Check if this is a suitable spot for a depot		
		local isSuitable = !AITunnel.IsTunnelTile(path.GetTile()) && LandManager.IsLevel(path.GetTile());

  		// If were more than half way, try to build a depot
		if(counter >= halfWayPoint && !builtDepot && isSuitable) {
			// First check if there is already a depot nearby
			/*
			local depots = AIDepotList(AITile.TRANSPORT_ROAD);
			depots.Valuate(AITile.GetDistanceManhattanToTile, path.GetTile());
			depots.KeepBelowValue(10);
			
			// For nearby depots, check that they are connected
			if(depots.Count() > 0) {
				foreach(depot, _ in depots) {
					local frontTile = AIRoad.GetRoadDepotFrontTile(depot); 
					if(PathFinder.AreRoadsConnected(frontTile, path.GetTile())) {
						builtDepot = true;
						break;
					}
				}
			}
			*/
			
			// If we couldn't find an existing one, then build away!
			if(!builtDepot) {
				local candidates = LandManager.GetAdjacentTileList(path.GetTile());
				candidates.Valuate(function (tile) {
					local sl = AITile.GetSlope(tile);
					local level = (sl == AITile.SLOPE_FLAT || sl == AITile.SLOPE_NWS || sl == AITile.SLOPE_WSE || sl == AITile.SLOPE_SEN || sl == AITile.SLOPE_ENW);
					local condition = AITile.IsBuildable(tile) && !AIRoad.IsRoadTile(tile) && !AITunnel.IsTunnelTile(tile) && level;
					return (condition) ? 1 : 0;
				});
				candidates.RemoveValue(0);
	
				// If there any good spots, build it
				if(candidates.Count() > 0) {
					AILog.Info("  Building depot...");
					local depotTile = candidates.Begin();
					RoadManager.SafelyBuildRoad(path.GetTile(), depotTile);
					AITile.DemolishTile(depotTile);
					AIRoad.BuildRoadDepot(depotTile, path.GetTile());
					builtDepot = true;
				}
			}
		}

		counter += distance;
		path = par;
	}
}
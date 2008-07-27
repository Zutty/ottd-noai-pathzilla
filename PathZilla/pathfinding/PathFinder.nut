/*
 *	Copyright © 2008 George Weller
 *	
 *	This file is part of PathZilla.
 *	
 *	PathZilla is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
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
 * PathFinder.nut
 * 
 * The main path finder, based on the A* algorithm.
 * 
 * Author:  George Weller (Zutty)
 * Created: 15/06/2008
 * Version: 1.1
 */
 
class PathFinder {
 	constructor() {
 	}
}

/*
 * Find a path between two tiles by road. If the computed path is not complete
 * a road will be built to connect them. Finally, a depot will be added if 
 * there are none nearby. 
 */ 
function PathFinder::FindPath(fromTile, toTile) {
	AILog.Info("  Searching for a path between [" + fromTile + "] and [" + toTile + "]...");

	// Initialise	
	local factory = PathNodeFactory(fromTile, toTile);
	local open = BinaryHeap();
	local closed = AIList();
	local finalPath = null;
	local node = null;
	local tile = null;
	local steps = 0;

	// Add the root node
	open.Insert(factory.GetStartNode());

	// Start the main loop
	while(open.Len() > 0) {
		// Dont hog all the CPU
		if(steps % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
		
		// Get the next node		
		node = open.Pop();
		tile = node.GetTile();

		// Check that weve not already tried this
		if(closed.HasItem(tile)) {
			continue;
		}

		//AISign.BuildSign(tile, ""+node.GetCost().GetTotalCost());

		// Ensure we dont try it again
		closed.AddItem(tile, 0);
		
		// Check if we have reached our goal
		if(tile == toTile) {
			finalPath = node;
			break;
		}
		
		// Add potential neighbours to the open list
		foreach(n in factory.GetNeighbours(node)) {
			open.Insert(n);
		}

		// Prevent the pathfinder hanging for a long time for paths that are intractable
		if(steps++ >= PathZilla.PATHFINDER_MAX_STEPS) {
			AILog.Error("      Path is taking too long to find.");
			break;
		}
	}
	
	// If we failed, don't try anything further
	if(finalPath == null) {
		AILog.Error("    Could not find a path!");
		return 0; 
	}
	
	AILog.Info("    Done.");
	AILog.Info("      Estimated length is " + finalPath.GetCost().GetStepsTaken());
	AILog.Info("      Estimated expenditure is " + finalPath.GetCost().GetFinancialCost());
	
	// Ensure we have enough money to pay for the venture
	local canAffordIt = FinanceManager.EnsureFundsAvailable(finalPath.GetCost().GetFinancialCost());
	if(!canAffordIt) {
		AILog.Error("    Computed path is too expensive! - Aborting.");
		return 0;
	}

	// We want a depot near the half way point
	local halfWayPoint = finalPath.GetCost().GetStepsTaken() / 2;
	local builtDepot = false;

	// Walk the final path to build the road
	local counter = 0;
	local MAXIMUM_ATTEMPTS = 100;

	for(local walk = finalPath; walk.GetParent() != null; walk = walk.GetParent()) {
		local tileA = walk.GetTile();
		local tileB = walk.GetParent().GetTile();
		local distanceAdded = 1;
		local built = false;
		local attempts = 0;
		local ignore = false;
		
		while(!built && attempts++ < MAXIMUM_ATTEMPTS) {
			// Build the next part of the path
			switch(walk.GetType()) {
				case PathNode.TYPE_TUNNEL:
					local otherEnd = AITunnel.GetOtherTunnelEnd(tileB);
					distanceAdded = AIMap.DistanceMax(tileB, otherEnd);
					
					AITile.DemolishTile(tileB);
					AITile.DemolishTile(otherEnd);
					built = AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, tileB);
				break;
				case PathNode.TYPE_BRIDGE:
					local otherEnd = LandManager.InferOtherEndTile(tileB, tileA);
					local bridgeType = LandManager.ChooseBridgeType(tileB, otherEnd);
					distanceAdded = AIMap.DistanceMax(tileB, otherEnd);
		
					local built = AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridgeType, tileB, otherEnd);
				break;
				case PathNode.TYPE_ROAD:
					built = AIRoad.BuildRoad(tileA, tileB);
				break;
				case PathNode.TYPE_FOLLOW_WORMHOLE:
					tileA = LandManager.InferOtherEndTile(tileA, tileB);
					built = AIRoad.BuildRoad(tileA, tileB);
				break;
				case PathNode.TYPE_FOLLOW:
					built = true; // It has already been built!
				break;
			}
			
			if(!built) {
						//AISign.BuildSign(tileA, "!");
				switch(AIError.GetLastError()) {
					case AIError.ERR_ALREADY_BUILT:
						// Just don't worry about this!
						ignore = true;
						//AISign.BuildSign(tileA, "!A");
						//AISign.BuildSign(tileB, "!B");
					break;
					case AIError.ERR_UNKNOWN:
						// Just don't worry about this!
						ignore = true;
					break;
					case AIError.ERR_AREA_NOT_CLEAR:
						// Something must have been built since we check the tile. Clear it.
						AITile.DemolishTile(tileB);
					break;
					case AIError.ERR_NOT_ENOUGH_CASH:
						if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
							// We cant afford to borrow any more money, so give up!
							AILog.Error("          CAN'T AFFORD IT - ABORTING!");
							return false;
						} else {
							// Otherwise, borrow some more money
							FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
						}
					break;
					case AIError.ERR_VEHICLE_IN_THE_WAY:
						// Theres a vehicle in the way... just wait a bit.
						PathZilla.Sleep(100);
					break;
				}
			}
			
			if(ignore) {
				break;
			}
		}

		// Check if this is a suitable spot for a depot		
		local isSuitable = !AITunnel.IsTunnelTile(tileA) && LandManager.IsLevel(tileA);

		// If were more than half way, try to build a depot
		if(counter >= halfWayPoint && !builtDepot && isSuitable) {
			// First check if there is already a depot nearby
			local depots = AIDepotList(AITile.TRANSPORT_ROAD);
			depots.Valuate(AITile.GetDistanceManhattanToTile, tileA);
			depots.KeepBelowValue(10);
			
			// For nearby depots, check that they are connected
			if(depots.Count() > 0) {
				foreach(depot, _ in depots) {
					local frontTile = AIRoad.GetRoadDepotFrontTile(depot); 
					if(PathFinder.AreRoadsConnected(frontTile, tileA)) {
						builtDepot = true;
						break;
					}
				}
			}
			
			// If we couldn't find an existing one, then build away!
			if(!builtDepot) {
				local candidates = LandManager.GetAdjacentTileList(tileA);
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
					AIRoad.BuildRoad(tileA, depotTile);
					AIRoad.BuildRoadDepot(depotTile, tileA);
					builtDepot = true;
				}
			}
		}
		
		counter += distanceAdded;
	}
	
	if(!builtDepot) {
		AILog.Info("  FAILED TO BUILD A DEPOT!!!");
		// TODO - Force-build a depot if we failed earlier 
	}
	
	return 1;
}

/*
 * Determine if two road tiles are connected distantly.
 */
function PathFinder::AreRoadsConnected(tileA, tileB) {
	// Initialise	
	local open = BinaryHeap();
	local closed = AIList();
	local node = null;
	local tile = null;
	local found = false;
	local steps = 0;
	local MAX_STEPS = 100;
	local offset = AIMap.GetTileIndex(1, 1);

	// Add the root node
	open.Insert(PathNode(tileA, null, BasicCost(AITile.GetDistanceManhattanToTile(tileA, tileB)), 0));

	// Start the main loop
	while(open.Len() > 0) {
		// Dont hog all the CPU
		if(steps % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
		
		// Get the next node		
		node = open.Pop();
		tile = node.GetTile();

		// Check that weve not already tried this
		if(closed.HasItem(tile)) {
			continue;
		}

		//AISign.BuildSign(tile, ""+node.GetCost().GetTotalCost());

		// Ensure we dont try it again
		closed.AddItem(tile, 0);
		
		// Check if we have reached our goal
		if(tile == tileB) {
			found = true;
			break;
		}

		// Find a list of neighbouring road tiles		
		local neighbours = AITileList();
		neighbours.AddRectangle(tile - offset, tile + offset);
		neighbours.RemoveTile(tile);
		neighbours.Valuate(AIRoad.IsRoadTile);
		neighbours.KeepValue(1);
		neighbours.Valuate(AIRoad.AreRoadTilesConnected, tile);
		neighbours.KeepValue(1);
		
		// Add the neighbours to the open list
		foreach(n, _ in neighbours) {
			open.Insert(PathNode(n, null, BasicCost(AITile.GetDistanceManhattanToTile(n, tileB)), 0));
		} 

		// Prevent the pathfinder hanging for a long time for paths that are intractable
		if(steps++ >= MAX_STEPS) {
			AILog.Error("    Path is taking too long to find.");
			break;
		}
	}
	
	return found;
}
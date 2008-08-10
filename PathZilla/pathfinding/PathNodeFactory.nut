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
 * PathNodeFactory.nut
 * 
 * A generator class for path nodes
 * 
 * Author:  George Weller (Zutty)
 * Created: 24/05/2008
 * Version: 1.0
 */

class PathNodeFactory {
	startTile = null;
	goalTile = null;
	
	constructor(startTile, goalTile) {
		this.startTile = startTile;
		this.goalTile = goalTile;
	}
}

/*
 * Get the start ing node for the current search
 */
function PathNodeFactory::GetStartNode() {
	return PathNode(this.startTile, null, this.ComputeCost(this.startTile, null, PathNode.TYPE_ROAD), PathNode.TYPE_ROAD);
}

/*
 * Get the goal tile for the current search 
 */
function PathNodeFactory::GetGoalTile() {
	return this.goalTile;
}

/*
 * Get the pathfinding cost object of the current node. The cost object has 
 * four basic terms: The distance travelled so far (g), the distance remaining
 * to the goal node (h), the assorted costs incurred so far (i), and the costs
 * incurrent by the current node (j).
 *
 * The h term uses manhattan distance. The j term includes construction cost,
 * and penaties for corners and hills.
 */
function PathNodeFactory::ComputeCost(tile, parentNode, type) {
	// Estimated the distance from this node to the goal
	//local h = sqrt(AITile.GetDistanceSquareToTile(tile, this.goalTile));
	local h = AITile.GetDistanceManhattanToTile(tile, this.goalTile);
	
	// Distance were travelling in this step 
	local len = 1;
	if(parentNode != null && (type == PathNode.TYPE_TUNNEL || type == PathNode.TYPE_BRIDGE)) {
		len = AIMap.DistanceMax(parentNode.GetTile(), tile);
		//AILog.Info("    Tunnel length is " + len);
	}

	// Construction cost
	local constructionCost = 0;
	if(parentNode != null) {
		constructionCost = this.EstimateConstructionCosts(parentNode.GetTile(), tile, type);
	}

	// Normalised construction cost for pathfinding heuristic
	local relaxedCost = constructionCost;
	if(type == PathNode.TYPE_BRIDGE) {
		relaxedCost /= 3; // Be lenient to encourage use of bridges.
	} else if(type == PathNode.TYPE_TUNNEL) {
		relaxedCost /= 5; // Be VERY lenient for tunnels, or they'll never get built!
	}
	local normConstCost = max(((relaxedCost - 7) / 75), 0);

	// Cost for corners - prefer straight paths
	local cornerCost = 0;
	if(parentNode != null && parentNode.GetParent() != null) {
		local alignX = (AIMap.GetTileX(tile) == AIMap.GetTileX(parentNode.GetTile())) && (AIMap.GetTileX(tile) == AIMap.GetTileX(parentNode.GetParent().GetTile()));
		local alignY = (AIMap.GetTileY(tile) == AIMap.GetTileY(parentNode.GetTile())) && (AIMap.GetTileY(tile) == AIMap.GetTileY(parentNode.GetParent().GetTile()));
		if(!(alignX || alignY)) cornerCost = 1;
	}

	// The cost of climbing or descending a hill	
	local hillCost = (LandManager.IsLevel(tile) && type == PathNode.TYPE_ROAD) ? 0 : 1;

	// j term is sum of all the non-distance based metrics - more to come here!!
	local j = cornerCost + normConstCost + hillCost;
	
	// Return a cost object
	return PathCost((parentNode != null) ? parentNode.GetCost() : null, h, len, constructionCost, j);
}

/*
 * Get the neighbouring nodes for the specified node. This function has one 
 * pass for each node type. The first checks existing roads and only allows
 * construction for adjacent road tiles that are not connected. The second 
 * pass checks for roads that CAN be built. The thrid and fourth passes check
 * for tunnels and bridges.
 *
 * At present bridges will only be built across water.
 */
function PathNodeFactory::GetNeighbours(node) {
	local neighbours = [];
	local aTile = node.GetTile();
	local aType = node.GetType();
	local zTile = (node.GetParent() != null) ? node.GetParent().GetTile() : null;
	local zType = (node.GetParent() != null) ? node.GetParent().GetType() : PathNode.TYPE_ROAD;
	
	// Try following existing roads first
	local bType = PathNode.TYPE_FOLLOW;
	
	foreach(i, bTile in LandManager.GetAdjacentTiles(aTile)) {
		local dir = i + 1;
	
		// Check if the tile has a road on it
		if(AITile.HasTransportType(bTile, AITile.TRANSPORT_ROAD) && !AIRoad.IsRoadDepotTile(bTile) && (!AIRoad.IsRoadStationTile(bTile) || AIRoad.IsDriveThroughRoadStationTile(bTile))) {
			local alreadyConnected = AIRoad.AreRoadTilesConnected(aTile, bTile);
			local type = (alreadyConnected) ? bType : PathNode.TYPE_ROAD;
			local cTile = bTile; // The next tile in the path *might* not be this tile...
			local validApproach = true;
			local dtrsApproach = true;
			
			if(AIRoad.IsDriveThroughRoadStationTile(aTile)) {
				dtrsApproach = (bTile == AIRoad.GetRoadStationFrontTile(aTile) || bTile == AIRoad.GetDriveThroughBackTile(aTile));
			}
			if(AIRoad.IsDriveThroughRoadStationTile(bTile)) {
				dtrsApproach = dtrsApproach && (aTile == AIRoad.GetRoadStationFrontTile(bTile) || aTile == AIRoad.GetDriveThroughBackTile(bTile));
			}
			
			if(alreadyConnected || (RoadManager.CanRoadTilesBeConnected(zTile, aTile, bTile) && dtrsApproach)) { 
				if(AITunnel.IsTunnelTile(bTile)) {
					cTile = AITunnel.GetOtherTunnelEnd(bTile);
					validApproach = (LandManager.GetTunnelApproachTile(bTile) == aTile);
					type = PathNode.TYPE_FOLLOW_WORMHOLE;
				} else if(AIBridge.IsBridgeTile(bTile)) {
					cTile = AIBridge.GetOtherBridgeEnd(bTile);
					validApproach = (LandManager.GetBridgeApproachTile(bTile) == aTile);
					type = PathNode.TYPE_FOLLOW_WORMHOLE;
				}
				
				if(!alreadyConnected && aTile == 28284) {
					//AISign.BuildSign(zTile, "Z");
					//AISign.BuildSign(aTile, "A");
					//AISign.BuildSign(bTile, "B");
					AISign.BuildSign(aTile + AIMap.GetTileIndex(1,1), ""+AIRoad.CanBuildConnectedRoadPartsHere(aTile, zTile, bTile));
				}
				
				if(validApproach) {
					neighbours.append(PathNode(cTile, node, this.ComputeCost(cTile, node, type), type));
				}
			}
		}
	}
	
	// Next basic road links first
	bType = PathNode.TYPE_ROAD;
	
	// Check all the adjacent tiles
	foreach(i, bTile in LandManager.GetAdjacentTiles(aTile)) {
		local dir = i + 1;
	
		// Ensure the tile is traversable
		if(this.IsTileTraversable(bTile) && (bTile != zTile) && !AITile.IsSteepSlope(AITile.GetSlope(bTile))) {
			local addNeighbour = RoadManager.CanRoadTilesBeConnected(zTile, aTile, bTile, dir);

			if(addNeighbour) {
				neighbours.append(PathNode(bTile, node, this.ComputeCost(bTile, node, bType), bType));
			}
		}
	}
	
	// Next try tunnels
	bType = PathNode.TYPE_TUNNEL;
	
	if(zTile != null) {
		local addNeighbour = false;
		local aSmooth = LandManager.IsSmooth(aTile);
		local tunnelTile = -1;
		local exitTile = -1;

		// If A isn't smooth then don't even bother checking anything		
		if(aSmooth) {
			// Get the other end of the tunnel
			tunnelTile = AITunnel.GetOtherTunnelEnd(aTile);
			exitTile = LandManager.GetTunnelExitTile(aTile);
			//AISign.BuildSign(aTile, "A_"+aTile);

			local validApproach = LandManager.GetTrueHeight(aTile) > LandManager.GetTrueHeight(zTile);
			local validExit = AIMap.IsValidTile(tunnelTile) && LandManager.IsSmooth(tunnelTile) && AITile.IsBuildable(tunnelTile) && AITile.IsBuildable(exitTile);
			
			// Can only build tunnel if we approach it correctly and its exit is valid
			if(validApproach && validExit) {
				local zSl = AITile.GetSlope(zTile);
				local aSl = AITile.GetSlope(aTile);
				
				local zLevel = LandManager.IsLevel(zTile)
				local zIncline = LandManager.IsIncline(zTile);
	
				local dir = LandManager.GetDirection(zTile, aTile);
				local goingNS = (dir == PathZilla.DIR_NORTH || dir == PathZilla.DIR_SOUTH); 
				local goingEW = (dir == PathZilla.DIR_EAST || dir == PathZilla.DIR_WEST);
		
				//local zSlopingAny = (zSl == AITile.SLOPE_W || zSl == AITile.SLOPE_S || zSl == AITile.SLOPE_E || zSl == AITile.SLOPE_N);
				local zSlopingNS = (zSl == AITile.SLOPE_NE || zSl == AITile.SLOPE_SW);// || bSlopingAny);
				local zSlopingEW = (zSl == AITile.SLOPE_NW || zSl == AITile.SLOPE_SE);// || bSlopingAny);
		
				//local aSlopingAny = (aSl == AITile.SLOPE_W || aSl == AITile.SLOPE_S || aSl == AITile.SLOPE_E || aSl == AITile.SLOPE_N);
				local aSlopingNS = (aSl == AITile.SLOPE_NE || aSl == AITile.SLOPE_SW);// || aSlopingAny);
				local aSlopingEW = (aSl == AITile.SLOPE_NW || aSl == AITile.SLOPE_SE);// || aSlopingAny);

				// Ensure we can actually build the tunnel
				local tunnelCost = this.EstimateConstructionCosts(aTile, exitTile, bType);
				local canAffordId = FinanceManager.CanAfford(tunnelCost + node.GetCost().GetFinancialCost());
				local tunnelable = (tunnelCost > 0) && canAffordId;
				
				// Only consider the tunnel if it can be built and we can afford it
				if(tunnelable) {
					// Can only go from slope to flat or to a slope in the direction of the slope
					addNeighbour = (goingNS && (zLevel || zSlopingNS) && aSlopingNS) || (goingEW && (zLevel || zSlopingEW) && aSlopingEW);					
				}
			}
		}		
		
		if(addNeighbour) {
			//AILog.Info("  Adding a tunnel...");
			//AISign.BuildSign(aTile, "A");
			//AISign.BuildSign(tunnelTile, "B");
			neighbours.append(PathNode(exitTile, node, this.ComputeCost(exitTile, node, bType), bType));
		}
	}
	
	// Next try bridges
	bType = PathNode.TYPE_BRIDGE;
	
	if(AITile.IsCoastTile(aTile) && LandManager.IsSmooth(aTile)) {
		//AISign.BuildSign(aTile, "BRIDGEABLE");
		local addNeighbour = false;
		
		foreach(otherEnd in LandManager.FindBridgeOtherEnds(aTile)) {
			local exitTile = LandManager.GetExitTile(aTile, otherEnd);
			local bridgeable = (otherEnd != aTile) && LandManager.CanBeBridged(aTile, otherEnd) && (LandManager.GetApproachTile(aTile, otherEnd) == zTile); 
	
			if(bridgeable && AITile.IsCoastTile(otherEnd) && AITile.IsBuildable(exitTile)) {// && LandManager.IsSmooth(otherEnd)) {
				local bridgeCost = this.EstimateConstructionCosts(aTile, exitTile, bType);
				local canAffordId = FinanceManager.CanAfford(bridgeCost + node.GetCost().GetFinancialCost())
	
				addNeighbour = (bridgeCost > 0) && canAffordId;
			}
		
			if(addNeighbour) {
				//AILog.Info("  Adding a brige...");
				//AISign.BuildSign(aTile, "A");
				//AISign.BuildSign(otherEnd, "B");
				neighbours.append(PathNode(exitTile, node, this.ComputeCost(exitTile, node, bType), bType));
			}
		}
	}

	//AILog.Info("Returning "+neighbours.len()+" neighbors");
	return neighbours;
}

/*
 * Checks if a tile can be considered for path finding.
 */
function PathNodeFactory::IsTileTraversable(tile) {
	if(!AIMap.IsValidTile(tile)) {
		return false;
	}

	return (AITile.IsBuildable(tile) || AITile.IsCoastTile(tile)) && !AIRoad.IsRoadStationTile(tile) && !AIRoad.IsRoadDepotTile(tile);
}

/*
 * Estimates the cost (money) of any proposed construction.
 */
function PathNodeFactory::EstimateConstructionCosts(aTile, bTile, type) {
	// Switch to test mode and reset costs
	FinanceManager.EnsureFundsAvailable(100000);
	local costs = 0;
	
	if(!AITile.IsBuildable(aTile)) {
		{
			local testMode = AITestMode();
			local accounts = AIAccounting();
			AITile.DemolishTile(aTile);
			costs = accounts.GetCosts();
		}
	}
	
	// Simulate proposed construction
	local built = true;
	local tryAgain = true;
	local waited = 0;
	local MAX_WAIT = 100;
	
	while(tryAgain && waited++ < MAX_WAIT) {
		{
			local testMode = AITestMode();
			local accounts = AIAccounting();
			
			if(type == PathNode.TYPE_FOLLOW) {
				built = true;
			} else if(type == PathNode.TYPE_ROAD) {
				built = AIRoad.BuildRoadFull(aTile, bTile);
				costs += (accounts.GetCosts() * 5) / 8;
			} else if(type == PathNode.TYPE_TUNNEL) {
				built = AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, aTile);
				costs += accounts.GetCosts();
			} else if(type == PathNode.TYPE_BRIDGE) {
				local otherEnd = LandManager.InferOtherEndTile(aTile, bTile);
				local bridgeType = LandManager.ChooseBridgeType(aTile, otherEnd);
				built = AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridgeType, aTile, otherEnd);
				costs += accounts.GetCosts();
			}
		}
		
		tryAgain = false;
		
		// If the construction could not be carried out, check for errors
		if(!built) {
			switch(AIError.GetLastError()) {
				case AIError.ERR_AREA_NOT_CLEAR:
					// If the area is not clear there is nothing we can do in test mode.
					tryAgain = false;
					break;
				case AIError.ERR_NOT_ENOUGH_CASH:
					// This is a bit of a hack. Due to a bug in NoAI, it is impossible to find out
					// how much something costs if you cant already afford it. To find out we will
					// have to keep upping our loan and testing again until we succeed.
				    tryAgain = FinanceManager.Borrow(10000);
					break;
				case AIError.ERR_VEHICLE_IN_THE_WAY:
					// Wait a bit and then try again
					PathZilla.Sleep(100);
					tryAgain = true;
					break;
			  }
	  	}
	}

	// Return the real cost
	return costs;
}
	
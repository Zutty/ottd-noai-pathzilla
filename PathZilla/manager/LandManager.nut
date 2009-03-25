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
 * LandManager.nut
 * 
 * A helper class for land and tile based functions
 * 
 * Author:  George Weller (Zutty)
 * Created: 29/05/2008
 * Version: 1.0
 */

class LandManager {
}

/*
 * Checks if the tile can be cleared.
 */
function LandManager::IsClearable(tile) {
	local _ = AITestMode();
	return AITile.DemolishTile(tile);
}

/*
 * Returns the cost of demolishing the tile.
 */
function LandManager::GetLandValue(tile) {
	local _ = AITestMode();
	local acc = AIAccounting();
	AITile.DemolishTile(tile);
	return acc.GetCosts();
}

/*
 * Get the adjacent tiles as an array
 */
function LandManager::GetAdjacentTiles(tile) {
	return [
		tile - AIMap.GetTileIndex(1,0),
		tile + AIMap.GetTileIndex(1,0),
		tile + AIMap.GetTileIndex(0,1),
		tile - AIMap.GetTileIndex(0,1)
	];
}

/*
 * Get the adjacent tiles as an AIList
 */
function LandManager::GetAdjacentTileList(tile) {
	local adj = AITileList();
	adj.AddTile(tile - AIMap.GetTileIndex(1,0));
	adj.AddTile(tile + AIMap.GetTileIndex(1,0));
	adj.AddTile(tile + AIMap.GetTileIndex(0,1));
	adj.AddTile(tile - AIMap.GetTileIndex(0,1));
	return adj;
}

/*
 * Get the true height of the specified tile, as the highest of the tile's 
 * four corners
 */
function LandManager::GetTrueHeight(tile) {
	local heights = [
			AITile.GetHeight(tile),
			AITile.GetHeight(tile + AIMap.GetTileIndex(1,1)),
			AITile.GetHeight(tile + AIMap.GetTileIndex(1,0)),
			AITile.GetHeight(tile + AIMap.GetTileIndex(0,1))
		];
	heights.sort();

	return heights[3];
}

/*
 * Get the tile that must be started from to approach a sloped tile from below.
 */
function LandManager::GetSlopeApproachTile(tile) {
	local approaches = AITileList();
	local slope = AITile.GetSlope(tile);

	if(slope == AITile.SLOPE_NE) {
		approaches.AddTile(tile - AIMap.GetTileIndex(1, 0));
	} else if(slope == AITile.SLOPE_SW) {
		approaches.AddTile(tile + AIMap.GetTileIndex(1, 0));
	} else if(slope == AITile.SLOPE_NW) {
		approaches.AddTile(tile + AIMap.GetTileIndex(0, 1));
	} else if(slope == AITile.SLOPE_SE) {
		approaches.AddTile(tile - AIMap.GetTileIndex(0, 1));
	}
	
	return approaches;
}

/*
 * Get the tile that must be ended with to exit a sloped tile from above.
 */
function LandManager::GetSlopeExitTile(tile) {
	local approaches = AITileList();
	local slope = AITile.GetSlope(tile);

	if(slope == AITile.SLOPE_NE) {
		approaches.AddTile(tile + AIMap.GetTileIndex(1, 0));
	} else if(slope == AITile.SLOPE_SW) {
		approaches.AddTile(tile - AIMap.GetTileIndex(1, 0));
	} else if(slope == AITile.SLOPE_NW) {
		approaches.AddTile(tile - AIMap.GetTileIndex(0, 1));
	} else if(slope == AITile.SLOPE_SE) {
		approaches.AddTile(tile + AIMap.GetTileIndex(0, 1));
	}
	
	return approaches;
}

/*
 * Checks if anything can be built flat on the tile.
 */
function LandManager::IsLevel(tile) {
	local slope = AITile.GetSlope(tile);
	local cornerDown = (slope == AITile.SLOPE_NWS || slope == AITile.SLOPE_WSE || slope == AITile.SLOPE_SEN || slope == AITile.SLOPE_ENW);
	return (slope == AITile.SLOPE_FLAT || cornerDown);
}

/*
 * Checks if the tile is sloped in any diretion. 
 */
function LandManager::IsIncline(tile) {
	local slope = AITile.GetSlope(tile);
	local smooth = (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW || slope == AITile.SLOPE_SE || slope == AITile.SLOPE_NE);
	local cornerUp = (slope == AITile.SLOPE_W || slope == AITile.SLOPE_S || slope == AITile.SLOPE_E || slope == AITile.SLOPE_N);
	return (smooth || cornerUp);
}

/*
 * Checks if the tile is sloped in only one direction
 */
function LandManager::IsSmooth(tile) {
	local slope = AITile.GetSlope(tile);
	local smooth = (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SW || slope == AITile.SLOPE_SE || slope == AITile.SLOPE_NE);
	return smooth;
}

/*
 * Gets the direction of movement between A and B
 */
function LandManager::GetDirection(a, b) {
	local dir = -1;
	local diff = b - a;

	if(diff == AIMap.GetTileIndex(-1,0)) {
		dir = PathZilla.DIR_NORTH;
	} else if(diff == AIMap.GetTileIndex(1,0)) {
		dir = PathZilla.DIR_SOUTH;
	} else if(diff == AIMap.GetTileIndex(0,1)) {
		dir = PathZilla.DIR_EAST;
	} else if(diff == AIMap.GetTileIndex(0,-1)) {
		dir = PathZilla.DIR_WEST;
	}  
	
	return dir;
}

/*
 * Checks if the specified tile is a road station tile of any road type.
 */
function LandManager::IsDriveThroughRoadStationAny(tile) {
	// First check if there is a staion of the current type
	local isDriveThroughRoadStation = AIRoad.IsDriveThroughRoadStationTile(tile);
	
	// If not, change road types and check again
	if(!isDriveThroughRoadStation) {
		// Buffer the current type
		local prevType = AIRoad.GetCurrentRoadType();

		// Change types (there are only two at the time of implementation)
		if(prevType == AIRoad.ROADTYPE_ROAD) {
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_TRAM);
		} else {
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		}
		
		// Check again
		isDriveThroughRoadStation = AIRoad.IsDriveThroughRoadStationTile(tile);
		
		// Reset the previous road type
		AIRoad.SetCurrentRoadType(prevType);
	}

	return isDriveThroughRoadStation;
}

/*
 * Checks if the specified tile is a road station tile of any road type.
 */
function LandManager::IsRoadStationAny(tile) {
	// First check if there is a staion of the current type
	local isRoadStation = AIRoad.IsRoadStationTile(tile);
	
	// If not, change road types and check again
	if(!isRoadStation) {
		// Buffer the current type
		local prevType = AIRoad.GetCurrentRoadType();

		// Change types (there are only two at the time of implementation)
		if(prevType == AIRoad.ROADTYPE_ROAD) {
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_TRAM);
		} else {
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		}
		
		// Check again
		isRoadStation = AIRoad.IsRoadStationTile(tile);
		
		// Reset the previous road type
		AIRoad.SetCurrentRoadType(prevType);
	}

	return isRoadStation;
}

/*
 * Checks if the tile can have road or road station built on it.
 */
function LandManager::IsRoadable(tile) {
	return AITile.IsBuildable(tile) || AIRoad.IsRoadTile(tile);
}

// --- Wormhole Management Functions ---

/*
 * Selects the fastest bridge type to connect the specified two tiles 
 */
function LandManager::ChooseBridgeType(aTile, bTile) {
	local bridgeType = -1;
	local length = AIMap.DistanceMax(aTile, bTile) + 1;
	
	// Get a list of all bridge types
	local list = AIBridgeList_Length(length);
	
	// Disregard those which we can't afford
	list.Valuate(AIBridge.GetPrice, length);
	list.RemoveAboveValue(FinanceManager.GetAvailableFunds());
	
	// Sort by their maximum speed
	list.Valuate(AIBridge.GetMaxSpeed);
	
	// Get the best bridge, if one exists
	if(list.Count() > 0) {
		bridgeType = list.Begin();
	}
	
	return bridgeType;
}

/*
 * Checks if its possible to build a bridge between the specified two tiles
 */
function LandManager::CanBeBridged(aTile, bTile) {
	local length = AIMap.DistanceMax(aTile, bTile) + 1;
	return (length <= PathZilla.MAX_BRIDGE_LENGTH) && (AIBridgeList_Length(length).Count() > 0);
}

/*
 * Finds where a proposed bridge built at the specified tile would end
 */
function LandManager::FindBridgeOtherEnds(tile) {
	local slope = AITile.GetSlope(tile);
	local otherEnd = tile;
	local offsets = {};
	local otherEnds = {};

	// First check smooth slopes
	if(slope == AITile.SLOPE_NE) {
		offsets[0] <- AIMap.GetTileIndex(1,0);
	} else if(slope == AITile.SLOPE_SW) {
		offsets[0] <- AIMap.GetTileIndex(-1,0);
	} else if(slope == AITile.SLOPE_NW) {
		offsets[0] <- AIMap.GetTileIndex(0,1);
	} else if(slope == AITile.SLOPE_SE) {
		offsets[0] <- AIMap.GetTileIndex(0,-1);
		
	// Then check the single corner slopes
	} else if(slope == AITile.SLOPE_N) {
		offsets[0] <- AIMap.GetTileIndex(1,0);
		offsets[1] <- AIMap.GetTileIndex(0,1);
	} else if(slope == AITile.SLOPE_S) {
		offsets[0] <- AIMap.GetTileIndex(-1,0);
		offsets[1] <- AIMap.GetTileIndex(0,-1);
	} else if(slope == AITile.SLOPE_W) {
		offsets[0] <- AIMap.GetTileIndex(0,1);
		offsets[1] <- AIMap.GetTileIndex(1,0);
	} else if(slope == AITile.SLOPE_E) {
		offsets[0] <- AIMap.GetTileIndex(0,-1);
		offsets[0] <- AIMap.GetTileIndex(-1,0);
	}

	foreach(idx, offset in offsets) {
		otherEnds[idx] <- tile;
			
		do {
			otherEnds[idx] += offset;
		} while(AIMap.IsValidTile(otherEnds[idx]) && AITile.IsWaterTile(otherEnds[idx]));
		
		if(!AIMap.IsValidTile(otherEnds[idx]) || AITile.IsWaterTile(otherEnds[idx])) {
			otherEnds[idx] = tile;
		}
	}
	
	return otherEnds;
}

/*
 * Get the tile from which to correctly approach a bridge or tunnel going from
 * aTile to bTile
 */
function LandManager::GetApproachTile(aTile, bTile) {
	local approachTile = aTile;
	local goingNS = (AIMap.GetTileY(aTile) == AIMap.GetTileY(bTile));
	local goingEW = (AIMap.GetTileX(aTile) == AIMap.GetTileX(bTile));
	
	if(goingNS && AIMap.GetTileX(aTile) > AIMap.GetTileX(bTile)) {
		approachTile += AIMap.GetTileIndex(1, 0);
	} else if(goingNS && AIMap.GetTileX(aTile) < AIMap.GetTileX(bTile)) {
		approachTile += AIMap.GetTileIndex(-1, 0);
	} else if(goingEW && AIMap.GetTileY(aTile) > AIMap.GetTileY(bTile)) {
		approachTile += AIMap.GetTileIndex(0, 1);
	} else if(goingEW && AIMap.GetTileY(aTile) < AIMap.GetTileY(bTile)) {
		approachTile += AIMap.GetTileIndex(0, -1);
	}
	
	return approachTile;
}

/*
 * Get the tile from which to correctly approach a bridge starting at the 
 * specified tile
 */
function LandManager::GetBridgeApproachTile(bridgeTile) {
	return LandManager.GetApproachTile(bridgeTile, AIBridge.GetOtherBridgeEnd(bridgeTile));
}

/*
 * Get the tile from which to correctly approach a tunnel starting at the 
 * specified tile
 */
function LandManager::GetTunnelApproachTile(tunnelTile) {
	return LandManager.GetApproachTile(tunnelTile, AITunnel.GetOtherTunnelEnd(tunnelTile));
}

/*
 * Get the tile from which to correctly exit a bridge or tunnel going from
 * aTile to bTile
 *
 * This is the reverse of GetApproachTile()
 */
function LandManager::GetExitTile(aTile, bTile) {
	return LandManager.GetApproachTile(bTile, aTile);
}

/*
 * Get the tile from which to correctly exit a bridge starting at the 
 * specified tile
 */
function LandManager::GetBridgeExitTile(bridgeTile) {
	return LandManager.GetExitTile(bridgeTile, AIBridge.GetOtherBridgeEnd(bridgeTile));
}

/*
 * Get the tile from which to correctly exit a tunnel starting at the 
 * specified tile
 */
function LandManager::GetTunnelExitTile(tunnelTile) {
	return LandManager.GetExitTile(tunnelTile, AITunnel.GetOtherTunnelEnd(tunnelTile));
}

/*
 * Given a starting tile for a bridge or tunnel and the correct exit tile, 
 * infer the tile at which the bridge or tunnel ends.
 */
function LandManager::InferOtherEndTile(aTile, exitTile) {
	local otherEnd = exitTile;
	local goingNS = (AIMap.GetTileY(aTile) == AIMap.GetTileY(exitTile));
	local goingEW = (AIMap.GetTileX(aTile) == AIMap.GetTileX(exitTile));
	
	if(goingNS && AIMap.GetTileX(aTile) > AIMap.GetTileX(exitTile)) {
		otherEnd += AIMap.GetTileIndex(1, 0);
	} else if(goingNS && AIMap.GetTileX(aTile) < AIMap.GetTileX(exitTile)) {
		otherEnd += AIMap.GetTileIndex(-1, 0);
	} else if(goingEW && AIMap.GetTileY(aTile) > AIMap.GetTileY(exitTile)) {
		otherEnd += AIMap.GetTileIndex(0, 1);
	} else if(goingEW && AIMap.GetTileY(aTile) < AIMap.GetTileY(exitTile)) {
		otherEnd += AIMap.GetTileIndex(0, -1);
	}
	
	return otherEnd;
}
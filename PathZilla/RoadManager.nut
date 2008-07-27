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
 * RoadManager.nut
 * 
 * Handles all road-based construction functions.
 * 
 * Author:  George Weller (Zutty)
 * Created: 27/07/2008
 * Version: 1.0
 */

class RoadManager {
	constructor() {
	}
}

/*
 * Get a list of all the road stations in a town for a specified cargo
 */
function RoadManager::GetStations(town, cargo) {
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	return stationList;
}

/*
 * Get the combined coverage area of all stations in a town for a specified
 * cargo, as a parcentage of all houses in that town.
 *
 * This helps determine how many stations can be placed in a town.
 */
function RoadManager::GetTownCoverage(town, cargo) {
	// Initialise a few details
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
	local offset = AIMap.GetTileIndex(radius, radius);
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;

	// Get a list of stations in the town	
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	local coveredTiles = AITileList();
	for(local station = stationList.Begin(); stationList.HasNext(); station = stationList.Next()) {
		local tile = AIStation.GetLocation(station);
		coveredTiles.AddRectangle(tile - offset, tile + offset);
	}

	coveredTiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, 0);
	coveredTiles.RemoveBelowValue(1);

	//AILog.Info(AITown.GetName(town) + " has " + AITown.GetHouseCount(town) + " houses");
	//AILog.Info(coveredTiles.Count() + " tiles covered");
	
	return (coveredTiles.Count() * 100) / AITown.GetHouseCount(town);
}

/*
 * Build enough stations in a town such that the combined coverage meets or
 * exceeds TARGET_TOWN_COVERAGE.
 * 
 * The function returns the number of stations that were added.
 */
function RoadManager::BuildStations(town, cargo) {
	local numStationsBuilt = 0;
	
	// Get the stations already built in the town
	local stationList = AIStationList(AIStation.STATION_BUS_STOP);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
		
	// Build new stations until the coverage exceeds the target percentage
	local station = 0;
	while(RoadManager.GetTownCoverage(town, cargo) <= PathZilla.TARGET_TOWN_COVERAGE && station >= 0) {
		PathZilla.Sleep(1);

		station = RoadManager.BuildStation(town, cargo);
		if(station >= 0) {
			numStationsBuilt++;
		}
	}
	
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
	local acceptance = 0;

	foreach(station in stationList) {
		local tile = AIStation.GetLocation(station);
		acceptance += AITile.GetCargoAcceptance(tile, PathZilla.GetCargo(), 1, 1, radius);
	}
	//AISign.BuildSign(AITown.GetLocation(town), "T "+acceptance);
	
	return numStationsBuilt;
}

/*
 * Build a single station in the specified town to accept the specified cargo.
 * The position of the station will be selected based on the maximum level
 * of acceptance.
 *
 * The function will attempt to build a DTRS if the selected position has road
 * either side of it.
 */
function RoadManager::BuildStation(town, cargo) {
	local townTile = AITown.GetLocation(town);
	
	// Get a list of tiles to search in
	local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, 20);
	local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
	
	local tileList = AITileList();
	tileList.AddRectangle(townTile - offset, townTile + offset);
	
	// Get the coverage radius of the station
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);

	// Get a list of existing stations	
	local stationList = AIStationList(AIStation.STATION_BUS_STOP);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	local stationSpacing = (radius * 3) / 2;
	offset = AIMap.GetTileIndex(stationSpacing, stationSpacing);
	
	foreach(station, _ in stationList) {
		local tile = AIStation.GetLocation(station);
		tileList.RemoveRectangle(tile - offset, tile + offset);
	}
	
	// Rank those tiles by their suitability for a station
	tileList.Valuate(function (tile, town, cargo, radius) {
		// Get the cargo acceptance around the tile
		local acceptance = AITile.GetCargoAcceptance(tile, cargo, 1, 1, radius);
		
		// Get the value of the land
		//local landValue = LandManager.GetLandValue(tile);
	
		// Find suitable roads adjacent to the tile
		local adjRoads = LandManager.GetAdjacentTileList(tile);
		adjRoads.Valuate(function (tile) {
			return (AIRoad.IsRoadTile(tile) && LandManager.IsLevel(tile)) ? 1 : 0;
		});
		adjRoads.KeepValue(1);
		
		// Check if this tile is acceptable
		local acceptable = !AIRoad.IsRoadTile(tile) 
						&& AITown.IsWithinTownInfluence(town, tile)  
						&& LandManager.IsLevel(tile) 
						&& LandManager.IsClearable(tile) 
						&& (adjRoads.Count() > 0);
		
		// If so, return a balanced heuristic
		//return (acceptable) ? ((acceptance * 500) / landValue) : 0;
		return (acceptable) ? acceptance : 0;
	}, town, cargo, radius);
			
	// Remove those tiles that don't produce enough
	tileList.RemoveBelowValue(8);
	
	// If we can't find any suitable tiles then just give up!			
	if(tileList.Count() == 0) {
		if(stationList.Count() == 0) {
			AILog.Error("  Bus stop could not be built in " + AITown.GetName(town) + "!");
		}
		
		return -1;
	}
	
	// Get the best location for the station and the road it joins to
	local stationTile = tileList.Begin(); 
	local neighbourList = LandManager.GetAdjacentTileList(stationTile);
	neighbourList.Valuate(function (tile, stationTile) {
		local otherSide = LandManager.GetApproachTile(stationTile, tile);
		return (AIRoad.IsRoadTile(tile) && LandManager.IsLevel(tile)) ? ((AIRoad.IsRoadTile(otherSide)) ? 2 : 1) : 0;
	}, stationTile);
	neighbourList.RemoveValue(0);
	local roadTile = neighbourList.Begin();
	
	// Check if the tile on the OTHER side is also road
	local otherSide = LandManager.GetApproachTile(stationTile, roadTile);
	local useDtrs = AIRoad.IsRoadTile(otherSide);
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	
	// Ensure we have a bit of cash available
	FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
	// Connect the site to the road(s)
	local built = RoadManager.SafelyBuildRoad(roadTile, stationTile);
	if(useDtrs) {
		built = built && RoadManager.SafelyBuildRoad(otherSide, stationTile);
	}

	if(!built) {
		// TODO - Handle this situation more gracefully
		AILog.Error("COULD NOT CONNECT ROAD TO BUS STOP!");
		return -1;
	}
	
	AILog.Info("  Building a " + ((useDtrs)? "drive through " : "") + "station...");

	// Build the station
	local success = AIRoad.BuildRoadStation(stationTile, roadTile, truckStation, useDtrs, true);
	
	if(!success) {
		AILog.Error("BUS STOP WAS NOT BUILT - " + AIError.GetLastErrorString());
	}
	
	return AIStation.GetStationID(stationTile);
}

/*
 * Build a road from tileA to tileB, handling any errors that may occur.
 */
function RoadManager::SafelyBuildRoad(tileA, tileB) {
	local built = false;
	local tries = 0;
	local MAX_TRIES = 100;
	
	while(!built && tries++ < MAX_TRIES) {
		built = AIRoad.BuildRoad(tileA, tileB);
		
		if(!built) {
			switch(AIError.GetLastError()) {
				case AIError.ERR_ALREADY_BUILT:
					// Just don't worry about this!
					built = true;
				break;
				case AIError.ERR_AREA_NOT_CLEAR:
					// Something must have been built since we check the tile. Clear it.
					local cleared = AITile.DemolishTile(tileB);
					
					if(!cleared) {
						AILog.Error("    Construction of bus stop was blocked");
						return cleared;
					}
				break;
				case AIError.ERR_NOT_ENOUGH_CASH:
					AILog.Error("        CAN'T AFFORD IT!");
					if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
						// We cant afford to borrow any more money, so give up!
						AILog.Error("          ABORT!!");
						return false;
					} else {
						// Otherwise, borrow some more money
						FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
					}
				break;
				case AIError.ERR_VEHICLE_IN_THE_WAY:
					AILog.Error("        Vehicle in the way");
					// Theres a vehicle in the way... just wait a bit.
					PathZilla.Sleep(100);
				break;
			}
		}
	}
	
	return built;
}

/*
 * Check if a road can be built at aTile that will connect to bTile from zTile
 */
function RoadManager::CanRoadTilesBeConnected(zTile, aTile, bTile, ...) {
	local origTile = zTile;
	if(origTile == null) {
		local tiles = AITileList();
		local offset = AIMap.GetTileIndex(1, 1);
		tiles.AddRectangle(aTile - offset, aTile + offset);
		tiles.RemoveTile(aTile);
		tiles.RemoveTile(bTile);
		tiles.Valuate(AIRoad.IsRoadTile);
		tiles.KeepValue(1);
		if(tiles.Count() > 0) {
			origTile = tiles.Begin();
		} else {
			// Just make something up!!
			origTile = aTile - (bTile - aTile);
		}
	} else if(AITile.GetDistanceManhattanToTile(aTile, zTile) > 1) {
		origTile = LandManager.InferOtherEndTile(zTile, aTile);
	}
	
	return AIRoad.CanBuildConnectedRoadPartsHere(aTile, origTile, bTile) > 0;
	/*
	local connectable = false;
	local dir = (vargc > 0) ? vargv[0] : LandManager.GetDirection(aTile, bTile);
				
	local aSl = AITile.GetSlope(aTile);
	local bSl = AITile.GetSlope(bTile);
				
	local aLevel = LandManager.IsLevel(aTile)
	local bLevel = LandManager.IsLevel(bTile)
				
	local aIncline = LandManager.IsIncline(aTile);
	local bIncline = LandManager.IsIncline(bTile);
	
	local goingNS = (dir == PathZilla.DIR_NORTH || dir == PathZilla.DIR_SOUTH); 
	local goingEW = (dir == PathZilla.DIR_EAST || dir == PathZilla.DIR_WEST);
				
	local alignNS = (zTile != null) ? (AIMap.GetTileY(zTile) == AIMap.GetTileY(bTile)) : false;
	local alignEW = (zTile != null) ? (AIMap.GetTileX(zTile) == AIMap.GetTileX(bTile)) : false;
	local align = (alignNS || alignEW);
	
	local aSlopingBoth = (aSl == AITile.SLOPE_W || aSl == AITile.SLOPE_S || aSl == AITile.SLOPE_E || aSl == AITile.SLOPE_N);
	local aSlopingNS = (aSl == AITile.SLOPE_NE || aSl == AITile.SLOPE_SW);
	local aSlopingEW = (aSl == AITile.SLOPE_NW || aSl == AITile.SLOPE_SE);
	
	local bSlopingBoth = (bSl == AITile.SLOPE_W || bSl == AITile.SLOPE_S || bSl == AITile.SLOPE_E || bSl == AITile.SLOPE_N);
	local bSlopingNS = (bSl == AITile.SLOPE_NE || bSl == AITile.SLOPE_SW);
	local bSlopingEW = (bSl == AITile.SLOPE_NW || bSl == AITile.SLOPE_SE);

	// Can go to or from a flat tile with no problems
	connectable = (aLevel && bLevel);

	if(aLevel && (bIncline || bSlopingBoth)) {
		// Can only go from slope to flat in the direction of the slope
		connectable = connectable || (bSlopingBoth && align) || ((goingNS && bSlopingNS) || (goingEW && bSlopingEW));
	} else if((aIncline || aSlopingBoth) && bLevel) {
		// Can only go from slope to flat in the direction of the slope
		connectable = connectable || (aSlopingBoth && align) || ((goingNS && aSlopingNS) || (goingEW && aSlopingEW));
	} else if(aIncline && bIncline) {
		// Can only go from slope to slope in the direction of both slopes
		if((goingNS && aSlopingNS && bSlopingNS) || (goingEW && aSlopingEW && bSlopingEW)) {
			//AILog.Info("    Building on a slope....")
			//AISign.BuildSign(aTile, "A ["+((goingNS)?"NS":"EW")+"]");
			//AISign.BuildSign(bTile, "B");

			connectable = true;					
		} 
	}
	
	return connectable;
	*/
}
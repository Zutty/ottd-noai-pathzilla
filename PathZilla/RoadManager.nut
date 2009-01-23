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
function RoadManager::GetStations(town, cargo, roadType) {
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	
	// Ensure we get the right type of station
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	// Ensure the stations have the correct road type
	stationList.Valuate(function (station, roadType) {
		return (AIRoad.HasRoadType(AIStation.GetLocation(station), roadType)) ? 1 : 0;
	}, roadType);
	stationList.RemoveValue(0);
	
	return stationList;
}

/*
 * Get the combined coverage area of all stations in a town for a specified
 * cargo, as a parcentage of all houses in that town. This helps determine how
 * many stations can be placed in a town. If the AI is set not to be agressive
 * it will count competitor's stations in the total coverage.
 */
function RoadManager::GetTownCoverage(town, cargo, roadType) {
	// Initialise a few details
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);
	local offset = AIMap.GetTileIndex(radius, radius);

	// Get a list of our stations in the town	
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	// Ensure the stations have the correct road type
	stationList.Valuate(function (station, roadType) {
		return (AIRoad.HasRoadType(AIStation.GetLocation(station), roadType)) ? 1 : 0;
	}, roadType);
	stationList.RemoveValue(0);
	
	
	// Get a list of tiles that fall within the coverage area of those stations
	local coveredTiles = AITileList();
	foreach(station, _ in stationList) {
		local tile = AIStation.GetLocation(station);
		coveredTiles.AddRectangle(tile - offset, tile + offset);
	}
	
	// Include competitors stations if we are not agressive
	if(!PathZilla.IsAggressive()) {
		// Get a large area around the town
		local townTile = AITown.GetLocation(town);
		local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local off = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(townTile - off, townTile + off);		

		// Find those tiles that are controlled by competitors
		foreach(tile, _ in tileList) {
			local owner = AITile.GetOwner(tile);
			local isCompetitors = (owner != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF) && owner != AICompany.ResolveCompanyID(AICompany.COMPANY_INVALID));
			
			// If its a station tile and not ours then look into it
			if(AITown.IsWithinTownInfluence(town, tile) && isCompetitors && AITile.IsStationTile(tile)) {
				// Identify the station type
				local stRadius = 0;
				if(LandManager.IsRoadStationAny(tile)) {
					stRadius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
				} else if(AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL)) {
					stRadius = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
				} else if(AIMarine.IsDockTile(tile)) {
					stRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
				} else if(AIAirport.IsAirportTile(tile)) {
					// TODO - This doesn't work - yet!
					stRadius = AIAirport.GetAirportCoverageRadius(AIAirport.GetAirportType(tile));
				}
				
				// Add the station's coverage radius to the list
				if(stRadius > 0) {
					local offs = AIMap.GetTileIndex(stRadius, stRadius);
					coveredTiles.AddRectangle(tile - offs, tile + offs);
				}
			}
		}
	}

	coveredTiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, 0);
	coveredTiles.RemoveBelowValue(1);

	//AILog.Info(AITown.GetName(town) + " has " + AITown.GetHouseCount(town) + " houses");
	//AILog.Info(coveredTiles.Count() + " tiles covered");
	
	return (coveredTiles.Count() * 100) / AITown.GetHouseCount(town);
}

/*
 * Build enough stations in a town such that the combined coverage meets or
 * exceeds the target coverage percentage.
 * 
 * The function returns the number of stations that were added.
 */
function RoadManager::BuildStations(town, cargo, roadType, target) {
	local strType = (roadType == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
	AILog.Info("  Building " + strType + " stations in " + AITown.GetName(town) + "...");

	local numStationsBuilt = 0;

	// Set the correct road type before starting
	AIRoad.SetCurrentRoadType(roadType);

	// Get the type of station that is needed	
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;

	// Get the stations already built in the town
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	// Build new stations if there are none or until the coverage exceeds the target
	local stationID = 0;
	while(((stationList.Count() + numStationsBuilt == 0) || RoadManager.GetTownCoverage(town, cargo, roadType) <= target) && stationID >= 0) {
		PathZilla.Sleep(1);

		stationID = RoadManager.BuildStation(town, cargo, roadType);
		if(stationID >= 0) {
			numStationsBuilt++;
		}
	}

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
function RoadManager::BuildStation(town, cargo, roadType) {
	local townTile = AITown.GetLocation(town);

	// Get a list of tiles to search in
	local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, PathZilla.MAX_TOWN_RADIUS);
	local offset = AIMap.GetTileIndex(searchRadius, searchRadius);

	// Before we do anything, check the local authority rating
	local rating = AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	
	// If the rating is low, take steps to improve it
	if(rating < AITown.TOWN_RATING_GOOD) {
		// See if we can bribe the town
		if(rating < AITown.TOWN_RATING_POOR && FinanceManager.CanAfford(PathZilla.BRIBE_THRESHOLD)) {
			AITown.PerformTownAction(town, AITown.TOWN_ACTION_BRIBE);
		}
		
		// After that, find places we can build trees
		local tileList = AITileList();
		tileList.AddRectangle(townTile - offset, townTile + offset);
		tileList.Valuate(function (tile, town) {
			return (!AITile.IsWithinTownInfluence(tile, town) && AITile.IsBuildable(tile) && !AITile.HasTreeOnTile(tile)) ? 1 : 0;
		}, town);
		tileList.RemoveValue(0);
		tileList.Valuate(function (tile, town, townTile) {
			return AITile.GetDistanceManhattanToTile(tile, townTile) + AIBase.RandRange(6) - 3;
		}, town, townTile);
		tileList.Sort(AIAbstractList.SORT_BY_VALUE, true);
		
		// For the places that are available, build a "green belt" around the town
		if(!tileList.IsEmpty()) {
			local expenditure = 0;
			local tile = tileList.Begin();
			
			while(AITown.GetRating(town, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) < AITown.TOWN_RATING_GOOD && expenditure < PathZilla.MAX_TREE_SPEND && tileList.HasNext()) {
				local acc = AIAccounting();
				for(local i = 0; i < 4; i++) {
					AITile.PlantTree(tile);
				}
				expenditure += acc.GetCosts();
				tile = tileList.Next();
			}
		}
	}
	
	// Get a list of tiles
	local tileList = AITileList();
	tileList.AddRectangle(townTile - offset, townTile + offset);

	// Check if we are now allowed to build in town
	local allowed = (rating == AITown.TOWN_RATING_NONE || rating > AITown.TOWN_RATING_VERY_POOR);
	if(!allowed) {
		AILog.Error(AITown.GetName(town) + " local authority refuses construction");
		return -1;
	}
	
	// Get the type of station we should build	
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	
	// Get a list of existing stations
	local stationList = AIStationList(stationType);
	stationList.Valuate(AIStation.IsWithinTownInfluence, town);
	stationList.RemoveValue(0);
	
	// Initialise some presets
	local radius = AIStation.GetCoverageRadius(stationType);
	local stationSpacing = (radius * 3) / 2;
	local comptSpacing = (PathZilla.IsAggressive() || stationList.Count() == 0) ? 1 : stationSpacing;
		
	// Find a list of tiles that are controlled by competitors
	foreach(tile, _ in tileList) {
		local owner = AITile.GetOwner(tile);
		local isCompetitors = (owner != AICompany.ResolveCompanyID(AICompany.COMPANY_SELF) && owner != AICompany.ResolveCompanyID(AICompany.COMPANY_INVALID));

		if(AITile.IsStationTile(tile) && isCompetitors) {
			local offs = AIMap.GetTileIndex(comptSpacing, comptSpacing);
			tileList.RemoveRectangle(tile - offs, tile + offs);
		} else if(AITile.IsStationTile(tile) || isCompetitors) {
			tileList.RemoveTile(tile);
		}
	}
	
	// Get the spacing offset for our stations
	offset = AIMap.GetTileIndex(stationSpacing, stationSpacing);
	
	// Iterate over the list of our stations, to ensure they aren't built too close
	foreach(station, _ in stationList) {
		local tile = AIStation.GetLocation(station);
		tileList.RemoveRectangle(tile - offset, tile + offset);
	}
	
	// Check if the game allows us to build DTRSes on town roads and get the road type
	local dtrsOnTownRoads = (AIGameSettings.GetValue("construction.road_stop_on_town_road") == 1);

	// Rank those tiles by their suitability for a station
	tileList.Valuate(function (tile, town, cargo, radius, dtrsOnTownRoads, roadType) {
		// Find roads that are connected to the tile
		local adjRoadListRd = LandManager.GetAdjacentTileList(tile);
		AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		adjRoadListRd.Valuate(AIRoad.AreRoadTilesConnected, tile);
		adjRoadListRd.KeepValue(1);
		
		// Find tram tracks that are connected to the tile
		local adjRoadListTrm = LandManager.GetAdjacentTileList(tile);
		AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_TRAM);
		adjRoadListTrm.Valuate(AIRoad.AreRoadTilesConnected, tile);
		adjRoadListTrm.KeepValue(1);
		
		// Combine to see all the adjacent road tiles of any type that are connected to
		adjRoadListTrm.AddList(adjRoadListRd);
		local adjRoads = ListToArray(adjRoadListTrm);
		local straightRoad = false;

		// Check if the road tile is a straight road  
		if(adjRoads.len() == 1) {
			straightRoad = true;
		} else if(adjRoads.len() == 2) {
			local dx = abs(adjRoads[1] % AIMap.GetMapSizeY()) - abs(adjRoads[0] % AIMap.GetMapSizeY());
			local dy = abs(adjRoads[1] / AIMap.GetMapSizeY()) - abs(adjRoads[0] / AIMap.GetMapSizeY());
			straightRoad = (dx == 0) || (dy == 0);
		}
		
		// Reset road type		
		AIRoad.SetCurrentRoadType(roadType);

		// Find the roads that would run parallel to a DTRS in this spot
		local parlRoadList = LandManager.GetAdjacentTileList(tile);
		parlRoadList.Valuate(function (_tile, tile) {
			return AIRoad.IsRoadTile(_tile) && !AIRoad.AreRoadTilesConnected(tile, _tile);
		}, tile);
		parlRoadList.KeepValue(1);
		local parlRoads = ListToArray(parlRoadList);
		local inCorner = false;

		if(parlRoads.len() >= 3) {
			inCorner = true;
		} else if(parlRoads.len() == 2) {
			local dx = abs(parlRoads[1] % AIMap.GetMapSizeY()) - abs(parlRoads[0] % AIMap.GetMapSizeY());
			local dy = abs(parlRoads[1] / AIMap.GetMapSizeY()) - abs(parlRoads[0] / AIMap.GetMapSizeY());
			inCorner = (dx != 0) || (dy == 0);
		}

		// Check if this tile is acceptable
		local canBuildOnRoad = (AITile.GetOwner(tile) == AICompany.COMPANY_INVALID) ? dtrsOnTownRoads : AICompany.IsMine(AITile.GetOwner(tile)); 
		local cl = (AIRoad.IsRoadTile(tile)) ? ((canBuildOnRoad) ? straightRoad : false) : LandManager.IsClearable(tile);
		local acceptable = AITown.IsWithinTownInfluence(town, tile) && LandManager.IsLevel(tile) && cl;
		
		// Get the cargo acceptance around the tile
		local score = AITile.GetCargoAcceptance(tile, cargo, 1, 1, radius);
		acceptable = acceptable && (score >= 8);
		
		// Penalise tiles in a corner (and if we had an alternative)
		score /= (dtrsOnTownRoads && inCorner) ? 2 : 1;
		
		// Promote tiles on road we can build on
		score += (AIRoad.IsRoadTile(tile) && canBuildOnRoad) ? 30 : 0;

		// If the spot is acceptable, return tile score
		return (acceptable) ? score : 0;
	}, town, cargo, radius, dtrsOnTownRoads, roadType);
	
	// Remove unacceptable tiles
	tileList.RemoveValue(0);
	
	// If we can't find any suitable tiles then just give up!			
	if(tileList.Count() == 0) {
		if(stationList.Count() == 0) {
			AILog.Error("  Station could not be built in " + AITown.GetName(town) + "!");
		}
		
		return -1;
	}
	
	// The tiles we need for reference
	local stationTile = null;
	local roadTile = null;
	local otherSide = null;
	
	// Check each tile for valid paths that will connect it to the town.
	foreach(stTile, _ in tileList) {
		// Find a path from the town to the station
 		local path = PathWrapper.FindPath(townTile, stTile, roadType, [], true, [PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_DEPOT_ALIGN, PathWrapper.FEAT_SHORT_SCOPE]);
 		
		if(path != null) {
			// Find a loop back to the town
			roadTile = (path.GetParent() != null) ? path.GetParent().GetTile() : townTile;
			otherSide = LandManager.GetApproachTile(stTile, roadTile);
			local loopTile = (stTile != townTile) ? townTile : roadTile;
			local loop = PathWrapper.FindPath(loopTile, otherSide, roadType, [stTile], true, [PathWrapper.FEAT_ROAD_LOOP, PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_SHORT_SCOPE]);
			
			// Check that the loop exists and that it can connect to the station
			if(loop != null && (AIRoad.CanBuildConnectedRoadPartsHere(otherSide, stTile, loop.GetParent().GetTile()) != 0)) {
				// Build everything
				PathWrapper.BuildPath(path, roadType);
				PathWrapper.BuildPath(loop, roadType);
				RoadManager.SafelyBuildRoad(otherSide, stTile);
				
				stationTile = stTile;
				break;
			} else {
				AILog.Warning("  Could not find loop to station!");
			}
		} else {
			AILog.Warning("  Could not find path to station!");
		}
	}
	
	// If we couldn;t find a path to any of the tiles then give up.
	if(stationTile == null) {
		AILog.Error("  Station could not be reached in " + AITown.GetName(town) + "!");
		return -1;
	}
	
	// Ensure we have a bit of cash available
	FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
	AILog.Info("  Building a station in " + AITown.GetName(town) + "...");
	
	// Clean up little road stubs, if any
	if(AIRoad.IsRoadTile(stationTile)) {
		local sideRoads = LandManager.GetAdjacentTileList(stationTile);
		sideRoads.RemoveTile(roadTile);
		sideRoads.RemoveTile(otherSide);
		foreach(side, _ in sideRoads) {
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
			AIRoad.RemoveRoad(stationTile, side);
			AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_TRAM);
			AIRoad.RemoveRoad(stationTile, side);
		}

		// Reset the original road type
		AIRoad.SetCurrentRoadType(roadType); 
	}

	local success = false;
	local attempts = 0;
	local fail = false;

	// Finally, try to build the station
	while(!success && attempts++ < PathZilla.MAX_CONSTR_ATTEMPTS) {
		success = AIRoad.BuildRoadStation(stationTile, roadTile, truckStation, true, false);
	
		if(!success) {
			switch(AIError.GetLastError()) {
				case AIRoad.ERR_ROAD_DRIVE_THROUGH_WRONG_DIRECTION:
					// This shouldn't happen. Try to clear the tile, and if 
					// that doesn't work then just give up. 
					if(attempts <= 1) {
						AITile.DemolishTile(stationTile);
					} else {
						break;
					}
				break;
				case AIError.ERR_AREA_NOT_CLEAR:
					// Something must have been built since we checked the tile. Clear it.
					AITile.DemolishTile(stationTile);
				break;
				case AIError.ERR_NOT_ENOUGH_CASH:
					if(!FinanceManager.CanAfford(PathZilla.FLOAT)) {
						// We cant afford to borrow any more money, so give up!
						AILog.Error("      CAN'T AFFORD IT - ABORTING!");
						break;
					} else {
						// Otherwise, borrow some more money
						FinanceManager.Borrow();
					}
				break;
				case AIError.ERR_VEHICLE_IN_THE_WAY:
					// Theres a vehicle in the way... just wait a bit.
					PathZilla.Sleep(50);
				break;
				// NO idea what to do here! Just give up.
				case AIError.ERR_UNKNOWN:
						break;
				break;
			}
		}

	}
	
	if(!success) {
		local strType = (truckStation) ? "TRUCK" : ((roadType == AIRoad.ROADTYPE_TRAM) ? "TRAM" : "BUS");
		AILog.Error(strType + " STOP WAS NOT BUILT");
		//AISign.BuildSign(stationTile, ""+trnc(AIError.GetLastErrorString()));
	}

	return (success) ? AIStation.GetStationID(stationTile) : -1;
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
function RoadManager::CanRoadTilesBeConnected(zTile, aTile, bTile) {
	local origTile = zTile;
	if(origTile == null) {
		local tiles = LandManager.GetAdjacentTileList(aTile);
		tiles.RemoveTile(bTile);
		tiles.Valuate(AIRoad.AreRoadTilesConnected, aTile);
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
	
	local connectable = AIRoad.CanBuildConnectedRoadPartsHere(aTile, origTile, bTile) > 0;
	
	if(AIRoad.IsDriveThroughRoadStationTile(aTile)) {
		connectable = connectable && (AIRoad.GetRoadStationFrontTile(aTile) == bTile || AIRoad.GetDriveThroughBackTile(aTile) == bTile);
	}

	if(AIRoad.IsDriveThroughRoadStationTile(bTile)) {
		connectable = connectable && (AIRoad.GetRoadStationFrontTile(bTile) == aTile || AIRoad.GetDriveThroughBackTile(bTile) == aTile);
	} else if(AIRoad.IsRoadTile(bTile)) {
		local nRoads = LandManager.GetAdjacentTileList(bTile);
		nRoads.Valuate(function (tile, bTile) {
			return (AIRoad.IsRoadTile(tile) && AIRoad.AreRoadTilesConnected(tile, bTile)) ? 1 : 0;
		}, bTile);
		nRoads.KeepValue(1);
		
		foreach(roadTile, _ in nRoads) {
			connectable = connectable && (AIRoad.CanBuildConnectedRoadPartsHere(bTile, aTile, roadTile) != 0);
		}
	}
	
	return connectable;
}
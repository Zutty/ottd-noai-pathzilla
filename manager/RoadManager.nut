/*
 *	Copyright ? 2008 George Weller
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
 * Version: 1.1
 */

class RoadManager {
	constructor() {
	}
}

/*
 * Build the required infrastructure for the specified service in the specified
 * schema. Stations will be built if necessary, then a road found between the 
 * stations, and finally depots will be built if necessary. The supplied set 
 * targetsUpdated will be updated with targets that were modified in the 
 * operation.
 */
function RoadManager::BuildInfrastructure(service, schema, targetsUpdated) {
	// Set the correcy road type before starting
	AIRoad.SetCurrentRoadType(schema.GetSubType());

	// Ensure that stations available for each target
	foreach(idx, target in service.GetTargets()) {
		if(target.GetType() == Target.TYPE_TOWN) {
			// Ensure that the source town has stations
			local added = RoadManager.BuildTownStations(target, service.GetCargo(), service.GetSubType(), service.GetCoverageTarget(), PathZilla.MAX_INITIAL_STATIONS);
			if(added > 0) {
				targetsUpdated.append(idx);
			}
		} else {
			// Ensure there is a station at the target
			if(!RoadManager.BuildIndustryStation(target, service.GetCargo(), service.GetSubType())) {
				AILog.Error("Could not complete infrastructure");
				return false;
			}
		}
	}
	
	// Ensure the targets are connected by road
	local prev = 0;
	for(local next = 1; next < service.GetTargets().len(); next++) {
		local from = service.GetTargets()[prev];
		local to = service.GetTargets()[next];

		// Find a path through the graph
		local path = schema.GetPlanGraph().FindPath(Vertex.FromTile(from.GetLocation()), Vertex.FromTile(to.GetLocation()));
		if(path == null) {
			AILog.Error("No path could be found");
			return false;
		} 
		
		local success = true;
		
		// Walk along the path and ensure the nodes are connected by roads
		for(local walk = path; walk.GetParent() != null; walk = walk.GetParent()) {
			local a = walk.GetVertex();
			local b = walk.GetParent().GetVertex();
			local edge = Edge(a, b);
			
			// If the nodes are not connected in the actual graph a road needs to be built
			if(!schema.GetActualGraph().GetEdges().Contains(edge)) {
				// Get the towns on this edges
				local aTarget = ::pz.targetManager.GetTarget(a.ToTile());
				local bTarget = ::pz.targetManager.GetTarget(b.ToTile());
				
				// If the tile is not yet fixed, find one				
				if(bTarget.IsTileUnfixed()) RoadManager.PreFixTarget(aTarget, bTarget, walk, schema);
	
				// Ensure we can afford to do some construction				
				FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
				// Try to build a link between the towns
				AILog.Info(" Building a road between " + aTarget.GetName() + " and " + bTarget.GetName() + "...");
				local feat = [PathWrapper.FEAT_SEPARATE_ROAD_TYPES, PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_COUNTRY_LANE];
				local path = PathWrapper.FindPath(aTarget.GetTile(), bTarget.GetTile(), service.GetSubType(), [], false, feat);
	
				success = PathWrapper.TryBuildPath(path, aTarget.GetTile(), bTarget.GetTile(), service.GetSubType(), [], false, feat);
				
				// Only proceed if we were able to build the link
				if(success && path != null) {
					// Firmly fix tiles to better suit what has been built
					if(aTarget.IsTileSemiFixed()) RoadManager.PostFixTarget(aTarget, clone path, false);
					if(bTarget.IsTileSemiFixed()) RoadManager.PostFixTarget(bTarget, clone path, true);

					// Add the edge to the actual graph
					schema.GetActualGraph().AddEdge(edge);
				} else {
					break;
				}
			}
		}
		
		if(!success) {
			AILog.Error("Could not link");
			return false;
		}
		
		prev = next;
	}

	// Also ensure depots are available for each target
	//  - We do this after for a reason!
	foreach(target in service.GetTargets()) {
		RoadManager.BuildDepot(target, service.GetSubType());
	}

	return true;
}

/*
 * Fix a buildable tile before station construction based on distance to  
 * neighboring targets.
 */
function RoadManager::PreFixTarget(aTarget, bTarget, walk, schema) {
	local aTile = aTarget.GetLocation();
	local bTile = bTarget.GetLocation();
	local cTile = bTile;
	if (walk.GetParent().GetParent() != null) {
		cTile = walk.GetParent().GetParent().GetVertex().ToTile();
	}
	
	// Get a list of tiles around the target
	local rad = PathZilla.TARGET_FIX_RADIUS;
	local offset = AIMap.GetTileIndex(rad, rad);
	local tileList = AITileList();
	tileList.AddRectangle(bTile - offset, bTile + offset);

	// Find a tile that is roughly equidistant from the other 
	// targets and has the most buildable tiles around it
	local sqDist = sqrt(AITile.GetDistanceSquareToTile(aTile, cTile));
	foreach(tile, _ in tileList) {
		local cDist = AITile.GetDistanceSquareToTile(cTile, tile);
		local score = sqDist - sqrt(cDist);
		
		tileList.SetValue(tile, (AITile.IsBuildable(tile)) ? score.tointeger() : 0);
	}
	tileList.Sort(AIAbstractList.SORT_BY_VALUE, false);
	
	bTarget.FixTile(tileList.Begin());
}

/*
 * Fix a buildable tile after station construction based on a path.
 */
function RoadManager::PostFixTarget(target, path, rev) {
	local ftile = target.GetTile();
	while (path != null) {
		ftile = path.GetTile(); 
		path = path.GetParent();
		if(!rev && AITile.GetDistanceManhattanToTile(target.GetTile(), ftile) < 10) break;
		if(rev && AITile.GetDistanceManhattanToTile(target.GetTile(), ftile) > 10) break;
	}
	target.FixTile(ftile);
}

/*
 * Maintain the infrastructure for the specified service, by ensuring that 
 * enough stations have been built. The supplied set targetsUpdated will be
 * updated with targets that were modified in the operation.
 */
function RoadManager::MaintainInfrastructure(service, targetsTried, targetsUpdated) {
	foreach(idx, target in service.GetTargets()) {
		if(target.GetType() == Target.TYPE_TOWN) {
			local completeTram = (service.GetSubType() == AIRoad.ROADTYPE_TRAM) && (RoadManager.GetStations(target, service.GetCargo(), service.GetSubType()).Count() > 0);
			if(!targetsTried.Contains(target.GetId()) && !completeTram) {
				targetsTried.Insert(target.GetId());
				local added = RoadManager.BuildTownStations(target, service.GetCargo(), service.GetSubType(), service.GetCoverageTarget(), 1);
				
				if(added > 0) {
					targetsUpdated.append(idx);
				}
			}
		} else if(target.GetType() == Target.TYPE_INDUSTRY) {
			// Ensure a station can be found at the target
			RoadManager.BuildIndustryStation(target, service.GetCargo(), service.GetSubType());
		}
	}
}

/*
 * Get a list of all the road stations in a town for a specified cargo
 */
function RoadManager::GetStations(target, cargo, roadType) {
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);
	
	// Ensure we get the right type of station
	local stationList = AIList();
	if(target.IsTown()) {
		stationList = AIStationList(stationType);
		stationList.Valuate(AIStation.IsWithinTownInfluence, target.GetId());
		stationList.RemoveValue(0);
	} else {
		local coveredTiles = (target.ProducesCargo(cargo)) ? AITileList_IndustryProducing(target.GetId(), radius) : AITileList_IndustryAccepting(target.GetId(), radius);
		foreach(tile, _ in coveredTiles) {
			local st = AIStation.GetStationID(tile);
			if(AIStation.IsValidStation(st)) {
				stationList.AddItem(st, 0);
			}
		}
	}
	
	// Ensure the stations have the correct road type
	foreach(station, _ in stationList) {
		local correctRt = (AIRoad.HasRoadType(AIStation.GetLocation(station), roadType));
		stationList.SetValue(station, (correctRt) ? 1 : 0);
	}
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
	foreach(station, _ in stationList) {
		stationList.SetValue(station, (AIRoad.HasRoadType(AIStation.GetLocation(station), roadType)) ? 1 : 0);
	}
	stationList.RemoveValue(0);
	
	
	// Get a list of tiles that fall within the coverage area of those stations
	local coveredTiles = AITileList();
	foreach(station, _ in stationList) {
		local tile = AIStation.GetLocation(station);
		coveredTiles.AddRectangle(tile - offset, tile + offset);
	}
	
	// Include competitors stations if we are not agressive
	if(!Settings.IsAggressive()) {
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

	// Reinstate the following after OpenTTD 0.7.2 si released
	//coveredTiles.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, 0);
	coveredTiles.Valuate(LandManager.CargoAcceptanceOnTile, cargo);
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
function RoadManager::BuildTownStations(target, cargo, roadType, coverageTarget, maxAdd = 100) {
	local town = target.GetId();
	local strType = (roadType == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
	AILog.Info("  Building " + strType + " stations in " + target.GetName() + "...");

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
	while(((stationList.Count() + numStationsBuilt == 0) || RoadManager.GetTownCoverage(town, cargo, roadType) <= coverageTarget) && stationID >= 0 && numStationsBuilt < maxAdd) {
		PathZilla.Sleep(1);

		stationID = RoadManager.BuildStation(target, cargo, roadType);
		if(stationID >= 0) {
			numStationsBuilt++;
		}
	}

	return numStationsBuilt;
}

/*
 * Check that a station has been built to serivce the specified industry and 
 * cargo. If not one will be built and the target tile semi-fixed.
 */
function RoadManager::BuildIndustryStation(target, cargo, roadType) {
	local stations = RoadManager.GetStations(target, cargo, roadType);
	local station = null;
	
	if(stations.IsEmpty()) {
		station = RoadManager.BuildStation(target, cargo, roadType);
	} else {
		station = stations.Begin();
	}

	if(!target.IsTileFixed() && station != null && station >= 0) {
		local tile = AIRoad.GetRoadStationFrontTile(AIStation.GetLocation(station));
		target.SemiFixTile(tile);
	}
	
	return (station >= 0);
}

/*
 * Build a single station in the specified town to accept the specified cargo.
 * The position of the station will be selected based on the maximum level
 * of acceptance.
 */
function RoadManager::BuildStation(target, cargo, roadType) {
	local targetLocation = target.GetLocation();
	local targetTile = target.GetTile();

	// Get a list of tiles to search in
	local searchRadius = min(AIMap.DistanceFromEdge(targetLocation) - 1, PathZilla.MAX_TOWN_RADIUS);
	local offset = AIMap.GetTileIndex(searchRadius, searchRadius);

	// Before we do anything, check the local authority rating
	local nearestTown = TownManager.FindNearestTown(targetLocation)
	
	// Try to improve the local authority rating if necessary
	TownManager.HandleRating(nearestTown);

	// Check if we are allowed to build in town
	if(!TownManager.CanBuildInTown(nearestTown)) {
		AILog.Error(AITown.GetName(nearestTown) + " local authority refuses construction");
		return -1;
	}
	
	// Get the type of station we should build and its radius	
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Get a list of tiles
	local tileList = AITileList();
	if(target.IsTown()) {
		tileList.AddRectangle(targetLocation - offset, targetLocation + offset);
	} else {
		if(target.ProducesCargo(cargo)) {
			tileList = AITileList_IndustryProducing(target.GetId(), radius);
		} else {
			tileList = AITileList_IndustryAccepting(target.GetId(), radius);
		}
	}
	
	// Get a list of existing stations - INCOMPATIBLE WITH MULTIPLE TRANSPORT TYPES
	local stationList = AIList();
	if(target.IsTown()) {
		stationList = AIStationList(stationType);
		stationList.Valuate(AIStation.IsWithinTownInfluence, target.GetId());
		stationList.RemoveValue(0);
	} else {
		local coveredTiles = (target.ProducesCargo(cargo)) ? AITileList_IndustryProducing(target.GetId(), radius) : AITileList_IndustryAccepting(target.GetId(), radius);
		foreach(tile, _ in coveredTiles) {
			local st = AIStation.GetStationID(tile);
			if(AIStation.IsValidStation(st)) stationList.AddItem(st, 0);
		}
	}
	
	// Remove tiles surrounging our stations, to ensure they aren't built too close
	local stationSpacing = (radius * 3) / 2;
	offset = AIMap.GetTileIndex(stationSpacing, stationSpacing);
	foreach(station, _ in stationList) {
		local tile = AIStation.GetLocation(station);
		tileList.RemoveRectangle(tile - offset, tile + offset);
	}

	// Calculate the station spacing
	local comptSpacing = (target.IsTown() && (Settings.IsAggressive() || stationList.Count() == 0)) ? 1 : stationSpacing;

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
	
	// Check if the game allows us to build DTRSes on town roads and get the road type
	local dtrsOnTownRoads = (AIGameSettings.GetValue("construction.road_stop_on_town_road") == 1);

	// Get some information about the nearest town's road layout
	local layoutType = AITown.GetRoadLayout(nearestTown);
	local tlayout = (layoutType == AITown.ROAD_LAYOUT_2x2) ? 3 : ((layoutType == AITown.ROAD_LAYOUT_3x3) ? 4 : 0);
	local tx = AIMap.GetTileX(AITown.GetLocation(nearestTown));
	local ty = AIMap.GetTileY(AITown.GetLocation(nearestTown));

	// Rank those tiles by their suitability for a station
	foreach(tile, _ in tileList) {
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
		foreach(_tile, _ in parlRoadList) {
			local parl = AIRoad.IsRoadTile(_tile) && !AIRoad.AreRoadTilesConnected(tile, _tile);
			parlRoadList.SetValue(_tile, (parl) ? 1 : 0);
		}
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
		local acceptable = LandManager.IsLevel(tile) && cl;
		if(target.IsTown()) acceptable = acceptable && AITown.IsWithinTownInfluence(target.GetId(), tile);
		
		// Do not allow stations on the junctions in a town with a grid layout
		if(target.IsTown() && tlayout != 0) {
			local dx = abs(AIMap.GetTileX(tile) - tx) % tlayout;
			local dy = abs(AIMap.GetTileY(tile) - ty) % tlayout;
			if(dx == 0 && dy == 0) acceptable = false; 
		}				

		// Get the cargo acceptance around the tile
		local score = 0;
		local threshold = 0;
		if(!target.IsTown() && target.ProducesCargo(cargo)) {
			score = AITile.GetCargoProduction(tile, cargo, 1, 1, radius);
		} else {
			score = AITile.GetCargoAcceptance(tile, cargo, 1, 1, radius);
			threshold = 8;
		}
		acceptable = acceptable && (score >= threshold);
		
		if(target.IsTown()) {
			// Penalise tiles in a corner
			score /= (inCorner) ? 3 : 1;
		
			// Promote tiles on road we can build on
			score += (AIRoad.IsRoadTile(tile) && canBuildOnRoad) ? 30 : 0;
		}

		// If the spot is acceptable, return tile score
		tileList.SetValue(tile, ((acceptable) ? score : 0));
	}
	tileList.Sort(AIAbstractList.SORT_BY_VALUE, false);
	
	// Remove unacceptable tiles
	tileList.RemoveValue(0);
	
	// If we can't find any suitable tiles then just give up!			
	if(tileList.Count() == 0) {
		if(stationList.Count() == 0) {
			AILog.Error("  Station could not be built at " + target.GetName() + "!");
		}
		
		return -1;
	}
	
	// The tiles we need for reference
	local stationTile = null;
	local roadTile = null;
	local otherSide = null;
	
	// Check each tile for valid paths that will connect it to the town.
	foreach(stTile, _ in tileList) {
 		local path = true;
 		
 		// Find a path only if we know where were going
 		if(target.IsTileFixed()) {
 			path = PathWrapper.FindPath(targetTile, stTile, roadType, [], true, [PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_DEPOT_ALIGN, PathWrapper.FEAT_SHORT_SCOPE]);
 		}
 		
 		// If no path was found, try another tile 
		if(path == null) continue;

		// Find and check the road and other side tiles
		if(target.IsTileFixed()) {
			roadTile = (path.GetParent() != null) ? path.GetParent().GetTile() : targetTile;
			otherSide = LandManager.GetApproachTile(stTile, roadTile);
			
			// If the other side is unsuitable, try another tile
			if(!LandManager.IsRoadable(otherSide)) continue;
		} else {
			// Choose an orientation for the station
			local adj = LandManager.GetAdjacentTileList(stTile);
			foreach(rtile, _ in adj) {
				local otile = LandManager.GetApproachTile(stTile, rtile);
				local acc = LandManager.IsRoadable(rtile) && LandManager.IsRoadable(otile) && AIRoad.CanBuildConnectedRoadPartsHere(stTile, rtile, otile);
				local score = ((acc) ? 1 : 0) + ((AIRoad.IsRoadTile(rtile)) ? 1 : 0) + ((AIRoad.IsRoadTile(otile)) ? 1 : 0);
				adj.SetValue(rtile, score);
			}
			adj.RemoveValue(0);
			
			// If it doesn't fit either way around, try another tile
			if(adj.IsEmpty()) continue;
			
			// Set the road and other side tiles
			roadTile = adj.Begin();
			otherSide = LandManager.GetApproachTile(stTile, roadTile);
		}
		
		// Choose a tile to loop to
		local loopTile = (target.IsTown() && stTile != targetTile) ? targetTile : roadTile;
		
		// Set the list of RPF features for the loop
		local features = [PathWrapper.FEAT_SHORT_SCOPE];
		if(target.IsTown() || AITown.IsWithinTownInfluence(nearestTown, stTile)) features.append(PathWrapper.FEAT_GRID_LAYOUT);
		if(target.IsTown()) features.append(PathWrapper.FEAT_ROAD_LOOP);

		// Find a loop back to the town
		local loop = PathWrapper.FindPath(loopTile, otherSide, roadType, [stTile], true, features);
		
		// Get the first tile in the loop
		local firstTile = (loop != null) ? PathWrapper.GetFirstTile(loop) : -1;
		
		// Check that the loop exists and that it can connect to the station
		if(loop != null && loop.GetParent() != null && (AIRoad.CanBuildConnectedRoadPartsHere(otherSide, stTile, loop.GetParent().GetTile()) != 0) && (AIRoad.CanBuildConnectedRoadPartsHere(loopTile, stTile, firstTile) != 0)) {
			// Build the path. If it fails try another tile.
			local pathed = true;
			if(target.IsTileFixed()) pathed = (PathWrapper.BuildPath(path, roadType) == 0);
			if(!pathed) continue;

			// Build the loop. If it fails try another tile.
			local looped = (PathWrapper.BuildPath(loop, roadType) == 0);
			if(!looped) continue;
			
			// Join the path and the loop to the station tile
			RoadManager.SafelyBuildRoad(otherSide, stTile);
			RoadManager.SafelyBuildRoad(roadTile, stTile);
			stationTile = stTile;
			break;
		} else {
			AILog.Warning("  Could not find loop to station!");
		}
	}
	
	// If we couldn;t find a path to any of the tiles then give up.
	if(stationTile == null) {
		AILog.Error("  Station could not be reached at " + target.GetName() + "!");
		return -1;
	}
	
	// Ensure we have a bit of cash available
	FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
	AILog.Info("  Building a station at " + target.GetName() + "...");
	
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
		local rvType = (truckStation) ? AIRoad.ROADVEHTYPE_TRUCK : AIRoad.ROADVEHTYPE_BUS;
		success = AIRoad.BuildDriveThroughRoadStation(stationTile, roadTile, rvType, AIStation.STATION_NEW);
	
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
 * Build a depot at the specified target if none exits
 */
function RoadManager::BuildDepot(target, roadType) {
	local strType = (roadType == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
	AILog.Info("  Checking for a " + strType + " depot in " + target.GetName() + "...");

	local targetTile = target.GetTile();
	AIRoad.SetCurrentRoadType(roadType);

	// Check for existing depots in the town
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AIRoad.HasRoadType, roadType);
	depots.KeepValue(1);
	if(target.IsTown()) {
		foreach(depot, _ in depots) {
			local inTown = AITown.IsWithinTownInfluence(target.GetId(), depot);
			depots.SetValue(depot, (inTown) ? 1 : 0);
		}
		depots.KeepValue(1);
	} else {
		depots.Valuate(AITile.GetDistanceManhattanToTile, targetTile);
		depots.KeepBelowValue(10);
		foreach(depot, _ in depots) {
			local value = 1; // TODO - Is depot connected to target tile
			depots.SetValue(depot, value);
		}
		depots.KeepValue(1);
	}
	
	// If there aren't any we need to build one
	if(depots.Count() == 0) {
		AILog.Info("    Building a new depot...");

		// Get some details about the nearest town		
		local nearestTown = -1;
		if(target.IsTown()) {
			nearestTown = target.GetId();
		} else {
			local towns = AITownList();
			towns.Valuate(AITown.GetDistanceManhattanToTile, targetTile);
			towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
			nearestTown = towns.Begin();
		}
		local layoutType = AITown.GetRoadLayout(nearestTown);
		local tlayout = (layoutType == AITown.ROAD_LAYOUT_2x2) ? 3 : ((layoutType == AITown.ROAD_LAYOUT_3x3) ? 4 : 0);
		local tx = AIMap.GetTileX(AITown.GetLocation(nearestTown));
		local ty = AIMap.GetTileY(AITown.GetLocation(nearestTown));
		
		// Get a list of tiles to search in
		local searchRadius = min(AIMap.DistanceFromEdge(targetTile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(targetTile - offset, targetTile + offset);

		// Rank those tiles by their suitability for a depot
		foreach(tile, _ in tileList) {
			// Find suitable roads adjacent to the tile
			local adjRoads = LandManager.GetAdjacentTileList(tile);
			foreach(_tile, _ in adjRoads) {
				local adj = (AITile.GetSlope(_tile) == AITile.SLOPE_FLAT && AIRoad.IsRoadTile(_tile) && AIRoad.HasRoadType(_tile, roadType));
				adjRoads.SetValue(_tile, (adj) ? 1 : 0);
			}
			adjRoads.KeepValue(1);
			
			local score = 0;
			
			// Only score tiles that can be built on
			if(!AITile.IsWaterTile(tile) && LandManager.IsLevel(tile) && !AIRoad.IsRoadTile(tile) && !AIRoad.IsRoadStationTile(tile)
				 && !AIBridge.IsBridgeTile(tile) && !AITunnel.IsTunnelTile(tile) && !AIRoad.IsRoadDepotTile(tile)) {
				score = AITile.GetDistanceManhattanToTile(target.GetTile(), tile);
				if(!target.IsTown()) score = (searchRadius * searchRadius) - score;
				if(adjRoads.Count() > 0) score += 10000;
				if(AITile.IsBuildable(tile)) score += 100;
				if(target.IsTown() && AITown.IsWithinTownInfluence(target.GetId(), tile)) score += 1000;
				
				// If the town has a grid road layout, penalise tiles that fall on the grid
				if(tlayout != 0) {
					local dx = abs(AIMap.GetTileX(tile) - tx) % tlayout;
					local dy = abs(AIMap.GetTileY(tile) - ty) % tlayout;
					if(dx == 0 || dy == 0) score = AITile.GetDistanceManhattanToTile(target.GetTile(), tile); 
				}				
			}
			
			tileList.SetValue(tile, score);
		}
		tileList.Sort(AIAbstractList.SORT_BY_VALUE, false);
	
		// Remove tiles that are unsuitable 	
		tileList.RemoveValue(0);
		
		// Try each location
		foreach(depotTile, _ in tileList) {
			local path = PathWrapper.FindPath(targetTile, depotTile, roadType, [], true, [PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_DEPOT_ALIGN, PathWrapper.FEAT_SHORT_SCOPE, PathWrapper.FEAT_NO_WORMHOLES]);
			if(path != null) {
				if(PathWrapper.BuildPath(path, roadType) != 0) continue;
				AITile.DemolishTile(depotTile);
				AIRoad.BuildRoadDepot(depotTile, path.GetParent().GetTile());
				break;
			} else {
				AILog.Warning("  Could not find path to depot!");
			}
		}
		
		PathZilla.Sleep(1);

		AILog.Info("    Done building depot.");
	}
}
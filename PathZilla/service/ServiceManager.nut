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
 * ServiceManager.nut
 * 
 * Handles all service related functions and maintains service lists.
 * 
 * Author:  George Weller (Zutty)
 * Created: 27/07/2008
 * Version: 1.0
 */

class ServiceManager {
	// Serialization constants
	CLASS_NAME = "ServiceManager";
	SRLZ_SERVICE_LIST = 0;
	SRLZ_TOWNS_UPDATED = 1;
	SRLZ_POTENTIAL_SERVICES = 2;
	SRLZ_TOWNS_CONSIDERED = 3;
	
	// Member variables
	pz = null;
	potentialServices = null;
	townsConsidered = null;
	serviceList = null;
	townsUpdated = null;
	
	constructor(pathzilla) {
		this.pz = pathzilla;
		
		this.townsUpdated = AIList();
		this.townsConsidered = AIList();
		
		this.serviceList = SortedSet();		
		this.potentialServices = BinaryHeap();
	}
}

/*
 * Get a list of services currently in operation.
 */
function ServiceManager::GetServices() {
	return this.serviceList;
}

/*
 * Maintians the operating services. This function ensures that all towns have
 * enough stations to cover them, and that all the vehciles in each service are
 * distributed adequately.
 */
function ServiceManager::MaintainServices() {
	local townsTried = AIList();
	
	foreach(service in this.serviceList) {
		PathZilla.Sleep(1);

		if(!townsTried.HasItem(service.GetFromTown())) {
			townsTried.AddItem(service.GetFromTown(), 0);
			local added = RoadManager.BuildStations(service.GetFromTown(), service.GetCargo(), service.GetRoadType(), service.GetCoverageTarget());
			
			if(added > 0) {
				this.townsUpdated.AddItem(service.GetFromTown(), 0);
			}
		}

		if(!townsTried.HasItem(service.GetToTown())) {
			townsTried.AddItem(service.GetToTown(), 0);
			local added = RoadManager.BuildStations(service.GetToTown(), service.GetCargo(), service.GetRoadType(), service.GetCoverageTarget());
			
			if(added > 0) {
				this.townsUpdated.AddItem(service.GetToTown(), 0);
			}
		}
		
		if(this.townsUpdated.HasItem(service.GetFromTown()) || this.townsUpdated.HasItem(service.GetToTown())) {
			AILog.Info("  Updating service - " + AITown.GetName(service.GetFromTown()) + " to " + AITown.GetName(service.GetToTown()));
			this.UpdateOrders(service);
		}
	}

	this.townsUpdated = AIList();
}

/*
 * Gets a list of potential services as service descriptors. At present this
 * searchs through a matrix of all towns in the map, checks which would turn a
 * profit, and ranks them by their profitability.
 */
function ServiceManager::FindNewServices() {
	local schema = pz.GetNextSchema();
	local cargo = schema.GetCargo();
	local roadType = schema.GetRoadType();

	// Discard the towns that we have already been to, or that can't be reached
	local towns = AITownList();
	towns.RemoveList(this.townsConsidered);
	towns.Valuate(function (town, planGraph) {
		return (planGraph.ContainsTown(town)) ? 1 : 0;
	}, schema.GetPlanGraph());
	towns.RemoveValue(0);
	
	// Check that there are any towns left that we haven't considered
	if(towns.Count() > 0) {
		// Order the remaining towns by populations, placing the home town first
		towns.Valuate(function (town, homeTown) {
			return (town == homeTown) ? 1000000 : AITown.GetPopulation(town);
		}, pz.homeTown);
		
		// Choose the first town and save it 
		local aTown = towns.Begin();
		this.townsConsidered.AddItem(aTown, 0);
		
		AILog.Info("  Looking for potential services from "+AITown.GetName(aTown)+"...");

		// Get the shortest distances accross the network
		local netDist = schema.GetPlanGraph().GetShortestDistances(Vertex.FromTown(aTown));

		// Iterate over each town to test each possible connection
		local steps = 0;
		foreach(bTown, _ in AITownList()) {
			if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
				PathZilla.Sleep(1);
			}

			// Ensure that its possible to connect to the town, and that we 
			// don't already provide this service
			if(bTown != aTown && schema.GetPlanGraph().ContainsTown(bTown) && !this.ProvidesService(aTown, bTown, cargo, roadType)) {
				local bTile = AITown.GetLocation(bTown);
				local engine = this.SelectEngine(aTown, bTown, cargo, roadType, false);
				
				if(engine == null) {
					AILog.Error("    There are no suitable vehicles for this route! [" + AITown.GetName(aTown) + " to " + AITown.GetName(bTown)+ "]");
					continue;
				}
				
				if(netDist[bTile] < 0) {
					AILog.Error("    There is no possible path between " + AITown.GetName(aTown) + " and " + AITown.GetName(bTown));
					continue;
				}
				
				local crowDist = AITown.GetDistanceManhattanToTile(aTown, AITown.GetLocation(bTown));
				local travelTime = (179 * netDist[bTile]) / (10 * AIEngine.GetMaxSpeed(engine)); // in days

				// Get the base income for one trip				
				local rawIncome = AICargo.GetCargoIncome(cargo, crowDist, travelTime);

				// Project revenue and costs
				local factor = 100; // Compensate for integer mathematics
				local annualRevenue = (rawIncome * AIEngine.GetCapacity(engine)) * ((364 * factor) / travelTime);
				local annualCost = AIEngine.GetRunningCost(engine) * factor;
				local annualProfit = (annualRevenue - annualCost) / factor;
				
				// Decide on a limit for the target coverage level
				local coverageLimit = PathZilla.MAX_TARGET_COVERAGE;
				local year = AIDate.GetYear(AIDate.GetCurrentDate());
				if(year < 1950) {
					year = max(year, 1910);
					coverageLimit = ((year - 1900) * 16 / 10);
				}

				// Decide on the coverage level itself
				// TODO: Move this code into the schema and make it more general
				local maxCoverage = PathZilla.MAX_TARGET_COVERAGE;
				local coverageTarget = maxCoverage;
				if(roadType == AIRoad.ROADTYPE_TRAM) coverageTarget = maxCoverage / 2; // Penalise trams to prevent sprawl
				if(AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) coverageTarget = maxCoverage / 4; // Penalise mail to prevent over-servicing
				
				// Ensure the target does not exceed the limit
				coverageTarget = min(coverageTarget, coverageLimit);
				
				// Only consider the service if it is more profitable than it is costly
				if(annualProfit > (annualCost/factor)) {
					this.potentialServices.Insert(ServiceDescriptor(schema.GetId(), aTown, bTown, cargo, roadType, engine, netDist[bTile], annualProfit, coverageTarget));
				}
			}
		}

		// To prevent an exponential buildup of descriptors, keep only the top 
		// MAX_POTENTIAL_SERVICES most profitable ones
		this.potentialServices.Prune(PathZilla.MAX_POTENTIAL_SERVICES);

		AILog.Info("    Done.");
	}
}

/*
 * Checks to see if the company provides a service from a to b for the
 * specified cargo and road type.
 */
function ServiceManager::ProvidesService(a, b, cargo, roadType) {
	foreach(service in this.serviceList) {
		if(service.GetCargo() == cargo && service.GoesTo(a) && service.GoesTo(b) && service.GetRoadType() == roadType) {
			return true;
		}
	}
	
	return false;
}

/*
 * Checks to see if the company already provides the specified service.
 */
function ServiceManager::ProvidesThisService(svc) {
	return this.ProvidesService(svc.GetFromTown(), svc.GetToTown(), svc.GetCargo(), svc.GetRoadType());
}

/*
 * Choose the next best service descriptor from pententialServices to be 
 * implemented in the game world. This function ensures that roads are built to
 * connect the towns in the service to the network (described by actualGraph),
 * builds preliminary stations at the town, and then creates the vehciles that
 * will operate the service.
 */
function ServiceManager::ImplementService() {
	// Check whether or not we can build any more vehicles
	local proceed = (AIVehicleList().Count() < AIGameSettings.GetValue("vehicle.max_roadveh"));
	
	// Only proceed if we are even able to implement any further services
	if(proceed) {
		// Implement the service at the top of the list
		local bestService = this.potentialServices.Peek();
	
		// Check that we don't already provide this service
		while(bestService != null && this.ProvidesThisService(bestService)) {
			// If we already provide it then move on to the next one
			this.potentialServices.Pop();
			bestService = this.potentialServices.Peek();
		}
		
		// Only proceed if there are any services left to implement
		if(bestService != null) {
			local schema = pz.GetSchema(bestService.GetSchemaId());
			local service = bestService.Create();
			
			local strType = (service.GetRoadType() == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
			AILog.Info("Best service takes " + AICargo.GetCargoLabel(service.GetCargo()) + " from " + AITown.GetName(service.GetFromTown()) + " to " + AITown.GetName(service.GetToTown()) + " by " + strType);
			
			local path = schema.GetPlanGraph().FindPath(Vertex.FromTown(service.GetFromTown()), Vertex.FromTown(service.GetToTown()));
			
			// Set the correcy road type before starting
			AIRoad.SetCurrentRoadType(schema.GetRoadType());
		
			for(local walk = path; walk.GetParent() != null; walk = walk.GetParent()) {
				local a = walk.GetVertex();
				local b = walk.GetParent().GetVertex();
				local edge = Edge(a, b);
		
				if(!schema.GetActualGraph().GetEdges().Contains(edge)) {
					// Get the towns on this edges
					local townA = GetTown(a.ToTile());
					local townB = GetTown(b.ToTile());
		
					// Ensure we can afford to do some construction				
					FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
		
					// Build a link between the towns
					AILog.Info(" Building a road between " + AITown.GetName(townA) + " and " + AITown.GetName(townB) + "...");
					local success = PathWrapper.BuildRoad(a.ToTile(), b.ToTile(), service.GetRoadType(), [], false, [PathWrapper.FEAT_SEPARATE_ROAD_TYPES, PathWrapper.FEAT_GRID_LAYOUT]);
					
					// If we were able to build the link, add the edge to the actual graph
					if(success > 0) {
						schema.GetActualGraph().AddEdge(edge);
					}
				}
			}
			
			// Ensure that the source town has bus stops
			local added = RoadManager.BuildStations(service.GetFromTown(), service.GetCargo(), service.GetRoadType(), service.GetCoverageTarget());
			if(added > 0) {
				this.townsUpdated.AddItem(service.GetFromTown(), 0);
			}
			
			// Ensure that the destination town has bus stops
			added = RoadManager.BuildStations(service.GetToTown(), service.GetCargo(), service.GetRoadType(), service.GetCoverageTarget());
			if(added > 0) {
				this.townsUpdated.AddItem(service.GetToTown(), 0);
			}
			
			// Ensure depot exist in both towns
			this.BuildDepotInTown(service.GetFromTown(), service.GetRoadType());
			this.BuildDepotInTown(service.GetToTown(), service.GetRoadType());
	
			// Create a fleet of vehicles to operate this service
			this.CreateFleet(service);
	
			// Finally, add the service to the list	
			this.serviceList.Insert(service);
			
			AILog.Info("Done implementing service.");
		}
	
		// Don't remove it until we are finished
		this.potentialServices.Pop();
	}
}

/*
 * Choose an engine to run between two specified towns, and carry the specified
 * cargo. This method is compatible with NewGRF sets that require vehciles to 
 * be refitted.
 */
function ServiceManager::SelectEngine(fromTown, toTown, cargo, roadType, checkStations) {
	local availableFunds = FinanceManager.GetAvailableFunds();
	local forbidArv = false;
	
	if(checkStations) {
		// Get the coverage radius of the appropriate station type	
		local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
		local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
		local radius = AIStation.GetCoverageRadius(stationType);
	
		local fromStations = RoadManager.GetStations(fromTown, cargo, roadType);
		fromStations.Valuate(AIStation.GetLocation);
		local toStations = RoadManager.GetStations(toTown, cargo, roadType);
		toStations.Valuate(AIStation.GetLocation);
		
		local fromAcc = 0;
		local fromArvAcc = 0;
		local toAcc = 0;
		local toArvAcc = 0;
		
		foreach(stationTile in fromStations) {
			local acceptance = AITile.GetCargoAcceptance(stationTile, cargo, 1, 1, radius);
			
			fromAcc += acceptance;
			if(AIRoad.IsDriveThroughRoadStationTile(stationTile)) {
				fromArvAcc += acceptance;
			}
		}
				
		foreach(stationTile in toStations) {
			local acceptance = AITile.GetCargoAcceptance(stationTile, cargo, 1, 1, radius);
			
			toAcc += acceptance;
			if(AIRoad.IsDriveThroughRoadStationTile(stationTile)) {
				toArvAcc += acceptance;
			}
		}
		
		local fromArvAccR = (fromArvAcc * 100) / max(1, fromAcc);
		local toArvAccR = (toArvAcc * 100) / max(1, toAcc);
	
		forbidArv = (fromArvAccR < PathZilla.ARV_ACC_THRESHOLD) || (toArvAccR < PathZilla.ARV_ACC_THRESHOLD);
		
		if(forbidArv) AILog.Warning("Cannot build ARVs for this service");
	}
	
	local engineList = AIEngineList(AIVehicle.VT_ROAD);
	engineList.Valuate(function (engine, cargo, availableFunds, forbidArv, roadType) {
		if(AIEngine.GetRoadType(engine) != roadType) return -1;
		if(!(AIEngine.GetCargoType(engine) == cargo || AIEngine.CanRefitCargo(engine, cargo))) return -1;
		if(AIEngine.GetPrice(engine) > availableFunds) return -1;
		if(forbidArv && AIEngine.IsArticulated(engine)) return -1;
		return 1;
	}, cargo, availableFunds, forbidArv, roadType);
	
	// Discount vehciles that are invalid or that can't be built
	engineList.RemoveValue(-1);

	// If none are left, then return with nothing	
	if(engineList.Count() == 0) {
		return null;
	}
	
	local distance = AITown.GetDistanceManhattanToTile(fromTown, AITown.GetLocation(toTown));
	//local totalPopulation = (AITown.GetPopulation(fromTown) + AITown.GetPopulation(toTown));
		
	// Build a function to compute the profit making potential of each vehicle
	local profitValuator = function (engine, cargo, distance) {
		local travelTime = (179 * distance) / (10 * AIEngine.GetMaxSpeed(engine)); // AIEngine.GetReliability(engine) / 100
		local unitIncome = AICargo.GetCargoIncome(cargo, distance, travelTime);
		local period = 5; // years
		local tco = AIEngine.GetPrice(engine) + (AIEngine.GetRunningCost(engine) * period);
		local income = unitIncome * AIEngine.GetCapacity(engine) * ((364 * period) / travelTime); 
		local profit = income - tco;
		return profit;
	}
	
	// Find the highest profit level
	engineList.Valuate(profitValuator, cargo, distance);
	local maxProfit = engineList.GetValue(engineList.Begin());
	
	// Findthe highest capacity
	engineList.Valuate(AIEngine.GetCapacity);
	local maxCapactiy = engineList.GetValue(engineList.Begin());
	
	// Get the minimum acceptance for the service
	local minAcceptance = -1;
	
	if(checkStations) { 
		// Get coverage radius of stations the vechies will stop at
		local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
		local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
		local radius = AIStation.GetCoverageRadius(stationType);

		// Get the stations
		local fromStations = RoadManager.GetStations(fromTown, cargo, roadType);
		local toStations = RoadManager.GetStations(toTown, cargo, roadType);
			
		// Create a lambda function to rank stations based on acceptance
		local accValuator = function(station, cargo, radius) {
			return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
		}
		
		// Prime the lists with acceptance values
		fromStations.Valuate(accValuator, cargo, radius);
		toStations.Valuate(accValuator, cargo, radius);
	
		// Get the total acceptance for both towns
		local fromSum = ListSum(fromStations);
		local toSum = ListSum(toStations);
		
		// Get the lesser of the two
		minAcceptance = min(fromSum, toSum);
	}
	
	// Rank the remaining engines by their score
	engineList.Valuate(function (engine, profitValuator, cargo, distance, maxProfit, maxCapactiy, minAcceptance) {
		local profitTerm = (max(0, profitValuator(engine, cargo, distance)) * 100) / maxProfit;
		local reliabilityTerm = AIEngine.GetReliability(engine);
		local normCapacity = (AIEngine.GetCapacity(engine) * 100) / maxCapactiy;
		local accUpper = 250;
		local overkillTerm = 100 - abs(normCapacity - (min(minAcceptance, accUpper) * 100 / accUpper));
		return (profitTerm + reliabilityTerm + overkillTerm) / 3;
	}, profitValuator, cargo, distance, maxProfit, maxCapactiy, minAcceptance);
	
	// If the engines are good enough then choose randomly from the best ones 
	if(engineList.GetValue(engineList.Begin()) >= PathZilla.ENGINE_SCORE_THRESHOLD) {
		engineList.RemoveBelowValue(PathZilla.ENGINE_SCORE_THRESHOLD);
		engineList.Valuate(AIBase.RandItem);
	}
	
	// Return the selected engine
	return engineList.Begin();
}

/*
 * Create a fleet of vehicles for the specified service. This method assumes 
 * that the towns that the service run between are already on the network and  
 * have stations built. The function finds the nearest depot, then estimates a 
 * suitable fleet size, then builds the vehicles with randomly distributed 
 * orders between the stations in both towns.
 */
function ServiceManager::CreateFleet(service) {
	AILog.Info("  Creating a fleet of vehicles...");

	// Initialise
	local fromTown = service.fromTown;
	local toTown = service.toTown;
	local cargo = service.GetCargo();
	
	// Select an engine type
	local engine = this.SelectEngine(service.GetFromTown(), service.GetToTown(), service.GetCargo(), service.GetRoadType(), true);
	service.SetEngine(engine);
	
	// Get the stations
	local fromStations = RoadManager.GetStations(fromTown, cargo, service.GetRoadType());
	local toStations = RoadManager.GetStations(toTown, cargo, service.GetRoadType());
	
	// If the engine type is articulated, forbid the vehicle from visiting regular stations
	if(AIEngine.IsArticulated(engine)) {
		local callback = function (station) {
			return AIRoad.IsDriveThroughRoadStationTile(AIStation.GetLocation(station));
		};
		
		fromStations.Valuate(callback);
		fromStations.RemoveValue(0);
		toStations.Valuate(callback);
		toStations.RemoveValue(0);
	}
	
	// Get the locations of the target towns
	local fromTile = AITown.GetLocation(fromTown);
	local toTile = AITown.GetLocation(toTown);
	
	// Find the closest depots to the starting town
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AIRoad.HasRoadType, service.GetRoadType());
	depots.KeepValue(1);
	depots.Valuate(AITile.GetDistanceManhattanToTile, fromTile);
	depots.KeepBottom(1);
	local fromDepot = depots.Begin();
	
	// Find the closest depots to the destination town
	depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AIRoad.HasRoadType, service.GetRoadType());
	depots.KeepValue(1);
	depots.Valuate(AITile.GetDistanceManhattanToTile, toTile);
	depots.KeepBottom(1);
	local toDepot = depots.Begin();

	// Get type of station the vechies will stop at
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Estimate the amount that will be waiting and other details that will 
	// influence our decision on fleet size.
	local townSize = max(AITown.GetPopulation(fromTown), AITown.GetPopulation(toTown));
	local distance = AITile.GetDistanceManhattanToTile(fromTile, toTile);
	local capacity = AIEngine.GetCapacity(engine);
	local speed = AIEngine.GetMaxSpeed(engine);

	// Create a lambda function to rank stations based on acceptance
	local accValuator = function(station, cargo, radius) {
		return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
	}
	
	// Prime the lists with acceptance values
	fromStations.Valuate(accValuator, cargo, radius);
	toStations.Valuate(accValuator, cargo, radius);

	// Get the total acceptance for both towns
	local fromSum = ListSum(fromStations);
	local toSum = ListSum(toStations);
	
	// Get the lesser of the two
	local minAcceptance = min(fromSum, toSum);

	// Estimate how many vehicles will be needed to cover the route
	local minFleetSize = fromStations.Count() + toStations.Count();
	local fleetSize = (minAcceptance / (capacity * 2)) * ((distance * 3) / speed);
	
	// Adjust the fleet size for early routes
	// TODO: Make this more generic
	local year = AIDate.GetYear(AIDate.GetCurrentDate());
	if(year < 1950) {
		year = max(year, 1905);
		fleetSize = (fleetSize * (year - 1900)) / 50;
	}

	// Ensure the fleet is not too small
	fleetSize = max(minFleetSize, fleetSize);
	
	local engineName = AIEngine.GetName(engine);
	AILog.Info("  Building a fleet of " + fleetSize + " " + engineName + ((ends_with(engineName, "s")) ? "es" : "s") + "...");
	
	// Borrow enough to buy whole fleet of vehicles
	FinanceManager.EnsureFundsAvailable(AIEngine.GetPrice(engine) * (fleetSize + 1));
	
	// Check if the vehicles will need to be refitted
	local needRefit = (AIEngine.GetCargoType(engine) != service.GetCargo());
	
	// Clone a fleet from the prototype vehicle
	local first = true;
	for(local i = 0; i < fleetSize; i++) {
		// Wait some time to spread the vechiles out a bit.
		pz.Sleep(PathZilla.NEW_VEHICLE_SPREAD_DELAY);
		
		//local fromTile = (fromStations.HasNext()) ? AIStation.GetLocation((first) ? fromStations.Begin() : fromStations.Next())
		//										  : AIStation.GetLocation(RandomItemByWeight(fromStations, fromSum));
		//local toTile = (toStations.HasNext()) ? AIStation.GetLocation((first) ? toStations.Begin() : toStations.Next())
		//									  : AIStation.GetLocation(RandomItemByWeight(toStations, toSum));
		//first = false;

		// Choose stations to send the vechicles to
		local fromTile = AIStation.GetLocation(RandomItemByWeight(fromStations, fromSum));
		local toTile = AIStation.GetLocation(RandomItemByWeight(toStations, toSum));		
		
		// Alternate between depots
		local alt = (i + 1) % 2;
		local depot = (alt == 0) ? fromDepot : toDepot;
		
		// Build a new vehicle at that depot
		local v = AIVehicle.BuildVehicle(depot, engine);
		
		// Refit the vehicle if necessary
		if(needRefit) {
			AIVehicle.RefitVehicle(v, service.GetCargo());
		}
		
		// Add orders to the vehicle
		AIOrder.AppendOrder(v, fromTile, AIOrder.AIOF_NON_STOP_INTERMEDIATE);// AIOrder.AIOF_FULL_LOAD);
		AIOrder.AppendOrder(v, toTile, AIOrder.AIOF_NON_STOP_INTERMEDIATE);// AIOrder.AIOF_FULL_LOAD);

		// Send the vehicle to the destination nearest the depot we built it at
		AIVehicle.SkipToVehicleOrder(v, alt);
		
		// Add the vehicle to the service
		service.AddVehicle(v);

		// Start the vehicle
		AIVehicle.StartStopVehicle(v);
	}
}

/*
 * Update orders for all the vehicles in a service to ensure that vechicles are
 * distributed correctly between the available stations. 
 */
function ServiceManager::UpdateOrders(service) {
	// Get the stations
	local fromStations = RoadManager.GetStations(service.GetFromTown(), service.GetCargo(), service.GetRoadType());
	local toStations = RoadManager.GetStations(service.GetToTown(), service.GetCargo(), service.GetRoadType());
	
	// If the engine type is articulated, forbid the vehicle from visiting regular stations
	if(AIEngine.IsArticulated(service.GetEngine())) {
		local callback = function (station, roadType) {
			// Ensure we check the correct road type
			AIRoad.SetCurrentRoadType(roadType);
			return AIRoad.IsDriveThroughRoadStationTile(AIStation.GetLocation(station));
		};
		
		fromStations.Valuate(callback, service.GetRoadType());
		fromStations.RemoveValue(0);
		toStations.Valuate(callback, service.GetRoadType());
		toStations.RemoveValue(0);
	}

	// Get the coverage radius of the stations	
	local truckStation = !AICargo.HasCargoClass(service.GetCargo(), AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Prime the lists
	local accValuator = function(station, cargo, radius) {
		return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
	}
	
	fromStations.Valuate(accValuator, service.GetCargo(), radius);
	toStations.Valuate(accValuator, service.GetCargo(), radius);

	local fromSum = ListSum(fromStations);
	local toSum = ListSum(toStations);
	local first = true;
	
	// Shuffle the vehicle orders between the stations
	foreach(v, _ in service.GetVehicles()) {
		//local fromTile = (fromStations.HasNext()) ? AIStation.GetLocation((first) ? fromStations.Begin() : fromStations.Next())
		//										  : AIStation.GetLocation(RandomItemByWeight(fromStations, fromSum));
		//local toTile = (toStations.HasNext()) ? AIStation.GetLocation((first) ? toStations.Begin() : toStations.Next())
		//									  : AIStation.GetLocation(RandomItemByWeight(toStations, toSum));
		//first = false;

		// Choose stations to send the vechicles to
		local fromTile = AIStation.GetLocation(RandomItemByWeight(fromStations, fromSum));
		local toTile = AIStation.GetLocation(RandomItemByWeight(toStations, toSum));
		
		local currentOrder = AIOrder.ResolveOrderPosition(v, AIOrder.ORDER_CURRENT);
		//local destination = AIOrder.GetOrderDestination(v, currentOrder);
		
		// Clear the order list i It would be nice to have an AIOrder.ClearOrders() function
		AIOrder.RemoveOrder(v, 1);
		AIOrder.RemoveOrder(v, 0);
		
		// Set the new orders
		AIOrder.AppendOrder(v, fromTile, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		AIOrder.AppendOrder(v, toTile, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		
		// Ensure the vehicle is still heading to the same town it was before
		AIVehicle.SkipToVehicleOrder(v, currentOrder);
	}
}

/*
 * Build a depot int eh specified town if none exits
 */
function ServiceManager::BuildDepotInTown(town, roadType) {
	local strType = (roadType == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
	AILog.Info("  Checking for a " + strType + " depot in " + AITown.GetName(town) + "...");

	local townTile = AITown.GetLocation(town);
	AIRoad.SetCurrentRoadType(roadType);

	// Check for existing depots in the town
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(function (depot, town, roadType) {
		return AITown.IsWithinTownInfluence(town, depot) && AIRoad.HasRoadType(depot, roadType);
	}, town, roadType);
	depots.KeepValue(1);
	
	// If there aren't any we need to build one
	if(depots.Count() == 0) {
		AILog.Info("    Building a new depot...");

		// Get a list of tiles to search in
		local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, 20);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(townTile - offset, townTile + offset);
		
		// Rank those tiles by their suitability for a depot
		tileList.Valuate(function(tile, roadType, town) {
			// Find suitable roads adjacent to the tile
			local adjRoads = LandManager.GetAdjacentTileList(tile);
			adjRoads.Valuate(function (_tile, roadType) {
				return (AIRoad.IsRoadTile(_tile) && AIRoad.HasRoadType(_tile, roadType)) ? 1 : 0;
			}, roadType);
			adjRoads.KeepValue(1);
			
			local score = 0;
			
			if(!AITile.IsWaterTile(tile) && LandManager.IsLevel(tile) && !AIRoad.IsRoadTile(tile) && !AIRoad.IsRoadStationTile(tile)
				 && !AIBridge.IsBridgeTile(tile) && !AITunnel.IsTunnelTile(tile) && !AIRoad.IsRoadDepotTile(tile)) {
				score = AITown.GetDistanceManhattanToTile(town, tile);
				if(adjRoads.Count() > 0) score += 10000;
				if(AITile.IsBuildable(tile)) score += 100;
				if(AITown.IsWithinTownInfluence(town, tile)) score += 1000;
			}
			
			return score;
		}, roadType, town);
		
		tileList.RemoveValue(0);
		
		foreach(depotTile, _ in tileList) {
			local path = PathWrapper.FindPath(townTile, depotTile, roadType, [], true, [PathWrapper.FEAT_GRID_LAYOUT, PathWrapper.FEAT_DEPOT_ALIGN]);
			if(path != null) {
				PathWrapper.BuildPath(path, roadType);
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

/*
 * Saves data to a table.
 */
function ServiceManager::Serialize() {
	local data = {};
	
	data[SRLZ_TOWNS_UPDATED] <- ListToArray(this.townsUpdated); 
	data[SRLZ_POTENTIAL_SERVICES] <- this.potentialServices.Serialize();
	data[SRLZ_TOWNS_CONSIDERED] <- ListToArray(this.townsConsidered); 
	data[SRLZ_SERVICE_LIST] <- this.serviceList.Serialize();
	
	return data;
}

/*
 * Loads data from a table.
 */
function ServiceManager::Unserialize(data) {
	this.townsUpdated = ArrayToList(data[SRLZ_TOWNS_UPDATED]); 
	this.townsConsidered = ArrayToList(data[SRLZ_TOWNS_CONSIDERED]); 
	
	this.potentialServices = BinaryHeap();
	this.potentialServices.Unserialize(data[SRLZ_POTENTIAL_SERVICES]);

	this.serviceList = SortedSet();
	this.serviceList.Unserialize(data[SRLZ_SERVICE_LIST]);
}

/*
 * This call should be made after data has been loaded and the game has 
 * started, to load vehicles into the service list.
 */
function ServiceManager::PostLoad() {
	foreach(service in this.serviceList) {
		local allVehicles = AIVehicleList();
		allVehicles.Valuate(AIVehicle.GetGroupID);
		allVehicles.KeepValue(service.group);
		service.vehicles = allVehicles;
	}
}
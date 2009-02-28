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
 * Version: 1.1
 */

class ServiceManager {
	// Serialization constants
	CLASS_NAME = "ServiceManager";
	SRLZ_SERVICE_LIST = 0;
	SRLZ_TARGETS_UPDATED = 1;
	SRLZ_POTENTIAL_SERVICES = 2;
	SRLZ_TARGETS_CONSIDERED = 3;
	
	// Member variables
	pz = null;
	potentialServices = null;
	targetsConsidered = null;
	serviceList = null;
	targetsUpdated = null;
	
	constructor(pathzilla) {
		this.pz = pathzilla;
		
		this.targetsConsidered = SortedSet();
		this.targetsUpdated = SortedSet();
		
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
	local targetsTried = SortedSet();
	
	foreach(service in this.serviceList) {
		PathZilla.Sleep(1);
		
		// Update fleet size
		this.CreateFleet(service, true);

		if(service.GetTransportType() == AITile.TRANSPORT_ROAD) {
			RoadManager.MaintainInfrastructure(service, targetsTried, this.targetsUpdated);
		}
		
		local needUpdate = false;
		foreach(target in service.GetTargets()) {
			needUpdate = needUpdate && this.targetsUpdated.Contains(target);
		}
		if(needUpdate) {
			AILog.Info("  Updating service - " + service);
			this.UpdateOrders(service);
		}
	}

	this.targetsUpdated = SortedSet();
}

/*
 * Gets a list of potential services as service descriptors. At present this
 * searchs through a matrix of all towns in the map, checks which would turn a
 * profit, and ranks them by their profitability.
 */
function ServiceManager::FindNewServices() {
	local schema = pz.GetNextSchema();
	local cargo = schema.GetCargo();
	local transportType = schema.GetTransportType();
	local subType = schema.GetSubType();

	// Discard the towns that we have already been to, or that can't be reached
	local targets = clone schema.GetPlanGraph().GetTargets();
	targets.RemoveAll(this.targetsConsidered);
	targets.Filter(function (target) {
		return !target.IsProducer();
	});
	
	// Check that there are any towns left that we haven't considered
	if(targets.Len() > 0) {
		// Order the remaining towns by populations, placing the home town first
		targets.SortBy(Target.SortByPotential(pz.homeTown, cargo));
		
		// Choose the first town and save it 
		local aTarget = targets.Begin();
		this.targetsConsidered.Insert(aTarget);
		
		AILog.Info("  Looking for potential services from " + aTarget.GetName() + "...");

		// Get the shortest distances accross the network
		local netDist = schema.GetPlanGraph().GetShortestDistances(aTarget.GetVertex());

		// Iterate over each town to test each possible connection
		local steps = 0;
		foreach(bTarget in schema.GetPlanGraph().GetTargets()) {
			if(!bTarget.IsAccepter()) continue;
			
			if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
				PathZilla.Sleep(1);
			}

			// Build a list of targets
			local targets = [aTarget, bTarget];

			// Ensure that its possible to connect to the town, and that we 
			// don't already provide this service
			if(bTarget != aTarget && !this.ProvidesService(targets, cargo, transportType, subType)) {
				local bTile = bTarget.GetLocation();

				// Select an engine
				local engine = this.SelectEngine(targets, cargo, transportType, subType, false);
				if(engine == null) {
					AILog.Error("    There are no suitable vehicles for this route! [" + aTarget.GetName() + " to " + bTarget.GetName()+ "]");
					continue;
				}
				
				if(netDist[bTile] < 0) {
					AILog.Error("    There is no possible path between " + aTarget.GetName() + " and " + bTarget.GetName());
					continue;
				}
				
				local crowDist = AITile.GetDistanceManhattanToTile(aTarget.GetLocation(), bTile);
				local travelTime = (179 * netDist[bTile]) / (10 * AIEngine.GetMaxSpeed(engine)); // in days
				travelTime = max(1, travelTime); // Compensate for ultra-fast vehicles

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
				if(subType == AIRoad.ROADTYPE_TRAM) coverageTarget = maxCoverage / 2; // Penalise trams to prevent sprawl
				if(AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) coverageTarget = maxCoverage / 4; // Penalise mail to prevent over-servicing
				
				// Ensure the target does not exceed the limit
				coverageTarget = min(coverageTarget, coverageLimit);
				
				// Only consider the service if it is more profitable than it is costly
				if(annualProfit > (annualCost/factor)) {
					this.potentialServices.Insert(Service(schema.GetId(), targets, cargo, transportType, subType, engine, netDist[bTile], annualProfit, coverageTarget));
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
function ServiceManager::ProvidesService(targets, cargo, transportType, subType) {
	foreach(service in this.serviceList) {
		if(service.GetCargo() == cargo && service.GoesToAll(targets) && service.GetTransportType() == transportType && service.GetSubType() == subType) {
			return true;
		}
	}
	
	return false;
}

/*
 * Checks to see if the company already provides the specified service.
 */
function ServiceManager::ProvidesThisService(svc) {
	return this.ProvidesService(svc.GetTargets(), svc.GetCargo(), svc.GetTransportType(), svc.GetSubType());
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
	if(AIVehicleList().Count() == AIGameSettings.GetValue("vehicle.max_roadveh")) return false;
	
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
		local success = false;
		local schema = pz.GetSchema(bestService.GetSchemaId());
		
		AILog.Info("Best service takes " + bestService);
		
		if(bestService.GetTransportType() == AITile.TRANSPORT_ROAD) {
			success = RoadManager.BuildInfrastructure(bestService, schema, this.targetsUpdated);
		}
		
		if(!success) return false;

		// Create a fleet of vehicles to operate this service
		bestService.Create();
		this.CreateFleet(bestService);

		// Finally, add the service to the list	
		this.serviceList.Insert(bestService);
		
		AILog.Info("Done implementing service.");
	}

	// Don't remove it until we are finished
	this.potentialServices.Pop();
	
	return true;
}

/*
 * Choose an engine to run between two specified towns, and carry the specified
 * cargo. This method is compatible with NewGRF sets that require vehciles to 
 * be refitted.
 */
function ServiceManager::SelectEngine(targets, cargo, transportType, subType, checkStations) {
	local availableFunds = FinanceManager.GetAvailableFunds();
	
	local vtTypeMap = {};
	vtTypeMap[AITile.TRANSPORT_ROAD] <- AIVehicle.VT_ROAD;
	
	local engineList = AIEngineList(vtTypeMap[transportType]);
	engineList.Valuate(function (engine, cargo, availableFunds, transportType, subType) {
		if(transportType == AITile.TRANSPORT_ROAD) {
			if(AIEngine.GetRoadType(engine) != subType) return -1;
		}
		if(!(AIEngine.GetCargoType(engine) == cargo || AIEngine.CanRefitCargo(engine, cargo))) return -1;
		if(AIEngine.GetPrice(engine) > availableFunds) return -1;
		return 1;
	}, cargo, availableFunds, transportType, subType);
	
	// Discount vehciles that are invalid or that can't be built
	engineList.RemoveValue(-1);

	// If none are left, then return with nothing	
	if(engineList.Count() == 0) {
		return null;
	}
	
	// Calculate the total distance
	local distance = 0;
	local prev = 0;
	for(local next = 1; next < targets.len(); next++) {
		distance += AITile.GetDistanceManhattanToTile(targets[prev].GetTile(), targets[next].GetTile());
	}
		
	// Build a function to compute the profit making potential of each vehicle
	local profitValuator = function (engine, cargo, distance) {
		local travelTime = (179 * distance) / (10 * AIEngine.GetMaxSpeed(engine)); // AIEngine.GetReliability(engine) / 100
		travelTime = max(1, travelTime); // Compensate for ultra-fast vehicles
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

		// Create a valuator function to rank stations based on acceptance
		local accValuator = function(station, cargo, radius) {
			return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
		}

		// Get the minimum level of acceptance for each target		
		minAcceptance = 10000000;
		foreach(target in targets) {
			local stations = RoadManager.GetStations(target, cargo, subType);
			stations.Valuate(accValuator, cargo, radius);
			minAcceptance = min(minAcceptance, ListSum(stations));
		}
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
function ServiceManager::CreateFleet(service, update = false) {
	if(!update) {
		AILog.Info("  Creating a fleet of vehicles...");
	} else {
		AILog.Info("  Updating a fleet of vehicles...");
	}

	// Initialise
	local cargo = service.GetCargo();
	local isIndustry = false;
	
	// Select an engine type
	local engine = null;
	if(update) {
		engine = service.GetEngine();
	} else {
		engine = this.SelectEngine(service.GetTargets(), cargo, service.GetTransportType(), service.GetSubType(), true);
		service.SetEngine(engine);
	}

	// Get the stations
	local stations = {};
	foreach(target in service.GetTargets()) {
		stations[target.GetId()] <- RoadManager.GetStations(target, cargo, service.GetSubType());

		if(!target.IsTown()) isIndustry = true;

		// If the engine type is articulated, forbid the vehicle from visiting regular stations
		if(AIEngine.IsArticulated(engine)) {
			stations[target.GetId()].Valuate(function (station) {
				return AIRoad.IsDriveThroughRoadStationTile(AIStation.GetLocation(station));
			});
			stations[target.GetId()].RemoveValue(0);
		}

		// If the target has no stations then there is no point in building a 
		// fleet - defer until stations have been built
		if(stations[target.GetId()].Count() == 0) {
			AILog.Warning("No stations at " + target.GetName());
			return;
		}
	}
	
	// Find the closest depots to the starting town
	local depots = {};
	foreach(target in service.GetTargets()) {
		local depotList = AIDepotList(AITile.TRANSPORT_ROAD);
		depotList.Valuate(AIRoad.HasRoadType, service.GetSubType());
		depotList.KeepValue(1);
		depotList.Valuate(AITile.GetDistanceManhattanToTile, target.GetTile());
		depotList.KeepBottom(1);
		depots[target.GetId()] <- depotList.Begin();
	}

	// Get type of station the vechies will stop at
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Get a few basic details
	local capacity = AIEngine.GetCapacity(engine);
	local speed = AIEngine.GetMaxSpeed(engine);
	local distance = 0;
	local prev = 0;
	for(local next = 1; next < service.GetTargets().len(); next++) {
		distance += AITile.GetDistanceManhattanToTile(service.GetTargets()[prev].GetTile(), service.GetTargets()[next].GetTile());
	}

	// Calculate the required fleet size
	local fleetSize = 0;

	// If we are updating the service, base the decision on waiting cargo
	if(update) {
		// Get the total waiting cargo for all targets
		local waitingCargo = 0;

		// Prime the station lists with waiting cargo values
		foreach(target in service.GetTargets()) {
			stations[target.GetId()].Valuate(function(station, cargo) {
				return AIStation.GetCargoWaiting(station, cargo);
			}, cargo);
			
			waitingCargo += ListSum(stations[target.GetId()]);
		}

		// Estimate the number of additional vechiles required based on waiting cargo
		local year = AIDate.GetYear(AIDate.GetCurrentDate());
		year = min(max(year, 1915), 1950);
		local multiplier = (65 - (year - 1900)) / 2;
		multiplier /= PathZilla.GetSetting("traffic");
		
		fleetSize = (waitingCargo / (capacity * multiplier)) * ((distance * 3) / speed)
		fleetSize = min(fleetSize, PathZilla.MAX_VEHICLES_PER_SVC);
		fleetSize = fleetSize - service.GetActualFleetSize();
	}

	// Find the minimum acceptance level
	local minAcceptance = 0;
	local accSum = {};
	
	foreach(target in service.GetTargets()) {
		stations[target.GetId()].Valuate(function(station, cargo, radius) {
			return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
		}, cargo, radius);

		// Get the minimum acceptance of all targets
		accSum[target.GetId()] <- ListSum(stations[target.GetId()]);
		if(target.IsAccepter()) {
			minAcceptance = min(minAcceptance, accSum[target.GetId()]);
		}
	}

	// Estimate the amount that will be waiting and other details that will 
	// influence our decision on fleet size.
	if(!update) {
		// Estimate how many vehicles will be needed to cover the route
		fleetSize = (PathZilla.GetSetting("traffic") * minAcceptance / (capacity * 2)) * ((distance * 3) / speed);
	}
	
	// Adjust the fleet size for early routes
	// TODO: Make this more generic
	local year = AIDate.GetYear(AIDate.GetCurrentDate());
	if(year < 1950) {
		year = max(year, 1905);
		fleetSize = (fleetSize * (year - 1900)) / 50;
	}

	// Ensure the fleet is not too small, there is at least one vehicle per station
	local minFleetSize = 0;
	foreach(target in service.GetTargets()) {
		minFleetSize += stations[target.GetId()].Count();
	}
	fleetSize = max(minFleetSize, fleetSize);
	
	// If there is no fleet to build then just return now
	if(fleetSize == 0) return;
	
	// If the service is industrial, apply a multiplier
	if(isIndustry) fleetSize = fleetSize * PathZilla.INDUSTRY_FLEET_MULTI;

	local engineName = AIEngine.GetName(engine);
	AILog.Info(((update) ? "  Updating a fleet with " : "  Building a fleet of ") + fleetSize + " " + engineName + "s...");
	
	// Borrow enough to buy whole fleet of vehicles
	FinanceManager.EnsureFundsAvailable(AIEngine.GetPrice(engine) * (fleetSize + 1));
	
	// Check if the vehicles will need to be refitted
	local needRefit = (AIEngine.GetCargoType(engine) != service.GetCargo());
	
	// Clone a fleet from the prototype vehicle
	for(local i = 0; i < fleetSize; i++) {
		// Wait some time to spread the vechiles out a bit.
		PathZilla.Sleep(PathZilla.NEW_VEHICLE_SPREAD_DELAY);
		
		// Alternate between depots
		local alt = (i + 1) % service.GetTargets().len();
		local depot = depots[service.GetTargets()[alt].GetId()];
		
		// Build a new vehicle at that depot
		local v = AIVehicle.BuildVehicle(depot, engine);
		
		// Refit the vehicle if necessary
		if(needRefit) {
			AIVehicle.RefitVehicle(v, service.GetCargo());
		}
		
		// Choose stations and assign orders
		local j = 0;
		foreach(target in service.GetTargets()) {
			local tile = AIStation.GetLocation(RandomItemByWeight(stations[target.GetId()], accSum[target.GetId()]));
			local flags = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
			if(!target.IsTown() && target.IsProducer()) flags = flags | AIOrder.AIOF_FULL_LOAD;
			AIOrder.AppendOrder(v, tile, flags);
		}
		
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
	local stations = {};
	foreach(target in service.GetTargets()) {
		stations[target.GetId()] <- RoadManager.GetStations(target, cargo, service.GetSubType());

		// If the engine type is articulated, forbid the vehicle from visiting regular stations
		if(AIEngine.IsArticulated(engine)) {
			stations[target.GetId()].Valuate(function (station) {
				return AIRoad.IsDriveThroughRoadStationTile(AIStation.GetLocation(station));
			});
			stations[target.GetId()].RemoveValue(0);
		}

		// If the target has no stations then there is no point in building a 
		// fleet - defer until stations have been built
		if(stations[target.GetId()].Count() == 0) {
			AILog.Warning("No stations at " + target.GetName());
			return;
		}
	}

	// Get the coverage radius of the stations	
	local truckStation = !AICargo.HasCargoClass(service.GetCargo(), AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Find the acceptance list sums
	local accSum = {};
	
	foreach(target in service.GetTargets()) {
		stations[target.GetId()].Valuate(function(station, cargo, radius) {
			return AITile.GetCargoAcceptance(AIStation.GetLocation(station), cargo, 1, 1, radius) + 1;
		}, cargo, radius);

		// Get the minimum acceptance of all targets
		accSum[target.GetId()] <- ListSum(stations[target.GetId()]);
	}

	// Shuffle the vehicle orders between the stations
	foreach(v, _ in service.GetVehicles()) {
		local currentOrder = AIOrder.ResolveOrderPosition(v, AIOrder.ORDER_CURRENT);

		// Clear the order list
		local ocount = AIOrder.GetOrderCount(v);
		for(local i = 0; i < ocount; i++) {
			AIOrder.RemoveOrder(v, i);
		}

		// Set the new orders
		foreach(target in service.GetTargets()) {
			local tile = AIStation.GetLocation(RandomItemByWeight(stations[target.GetId()], accSum[target.GetId()]));
			local flags = AIOrder.AIOF_NON_STOP_INTERMEDIATE;
			if(!target.IsTown() && target.IsProducer()) flags = flags & AIOrder.AIOF_FULL_LOAD;
			AIOrder.AppendOrder(v, tile, flags);
		}

		// Ensure the vehicle is still heading to the same town it was before
		AIVehicle.SkipToVehicleOrder(v, currentOrder);
	}
}

/*
 * Saves data to a table.
 */
function ServiceManager::Serialize() {
	local data = {};
	
	data[SRLZ_TARGETS_UPDATED] <- this.targetsUpdated.Serialize(); 
	data[SRLZ_POTENTIAL_SERVICES] <- this.potentialServices.Serialize();
	data[SRLZ_TARGETS_CONSIDERED] <- this.targetsConsidered.Serialize(); 
	data[SRLZ_SERVICE_LIST] <- this.serviceList.Serialize();
	
	return data;
}

/*
 * Loads data from a table.
 */
function ServiceManager::Unserialize(data) {
	this.targetsUpdated = SortedSet();
	this.targetsUpdated.Unserialize(data[SRLZ_TARGETS_UPDATED]); 

	this.targetsConsidered = SortedSet();
	this.targetsConsidered.Unserialize(data[SRLZ_TARGETS_CONSIDERED]); 
	
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
		service.vehicles.AddList(allVehicles);
	}
}
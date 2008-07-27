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
 * ServiceManager.nut
 * 
 * Handles all service related functions and maintains service lists.
 * 
 * Author:  George Weller (Zutty)
 * Created: 27/07/2008
 * Version: 1.0
 */

class ServiceManager {
	pz = null;
	potentialServices = null;
	serviceList = null;
	townsUpdated = null;
	
	constructor(pathzilla) {
		this.pz = pathzilla;
		this.serviceList = SortedSet();
		this.townsUpdated = AIList();
		
		this.potentialServices = this.FindPotentialServices();
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
			local added = RoadManager.BuildStations(service.GetFromTown(), service.GetCargo());
			
			if(added > 0) {
				this.townsUpdated.AddItem(service.GetFromTown(), 0);
			}
		}

		if(!townsTried.HasItem(service.GetToTown())) {
			townsTried.AddItem(service.GetToTown(), 0);
			local added = RoadManager.BuildStations(service.GetToTown(), service.GetCargo());
			
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
function ServiceManager::FindPotentialServices() {
	local cargo = pz.GetCargo();
	local services = SortedSet();

	foreach(aTown, _ in AITownList()) {
		if(pz.planGraph.ContainsTown(aTown)) {
			foreach(bTown, _ in AITownList()) {
				PathZilla.Sleep(1);
	
				if(bTown != aTown && pz.planGraph.ContainsTown(bTown)) {
					local engine = this.SelectEngine(aTown, bTown, cargo);
					
					if(engine == null) {
						AILog.Error("There are no suitable vehicles for this route!");
						continue;
					}
					
					local path = pz.planGraph.FindPath(Vertex.FromTown(aTown), Vertex.FromTown(bTown));
					
					if(path == null) {
						AILog.Error("  There is no possible path between " + AITown.GetName(aTown) + " and " + AITown.GetName(bTown));
					}
					
					local netDist = path.GetDistance();
					local crowDist = AITown.GetDistanceManhattanToTile(aTown, AITown.GetLocation(bTown));
					local travelTime = (179 * netDist) / (10 * AIEngine.GetMaxSpeed(engine)); // in days
	
					// Get the base income for one trip				
					local rawIncome = AICargo.GetCargoIncome(cargo, crowDist, travelTime);
	
					// Project revenue and costs
					local annualRevenue = (rawIncome * AIEngine.GetCapacity(engine)) * (364 / travelTime);
					local annualCost = AIEngine.GetRunningCost(engine);
					
					if(annualRevenue > annualCost) {
						services.Insert(ServiceDescriptor(aTown, bTown, cargo, engine, path, (annualRevenue - annualCost)));
					}
				}
			}
		}
	}
	
	return services;
}
	
/*
 * Choose the next best service descriptor from pententialServices to be 
 * implemented in the game world. This function ensures that roads are built to
 * connect the towns in the service to the network (described by actualGraph),
 * builds preliminary stations at the town, and then creates the vehciles that
 * will operate the service.
 */
function ServiceManager::ChooseService() {
	this.potentialServices.Sort();
	local bestService = this.potentialServices.Pop();
	
	if(bestService != null) {
		local service = bestService.Create();
		
		this.serviceList.Insert(service);
		
		local distTerm = AITown.GetDistanceManhattanToTile(service.GetFromTown(), AITown.GetLocation(service.GetToTown()));
		local fromTotal = 0;
		local toTotal = 0;
		foreach(svc in this.serviceList) {
			if(svc.GoesTo(service.GetFromTown())) {
				fromTotal += (svc.GetActualFleetSize() * 1000 ) / distTerm;
			}
			if(svc.GoesTo(service.GetToTown())) {
				toTotal += (svc.GetActualFleetSize() * 1000 ) / distTerm;
			}
		}
		//AISign.BuildSign(AITown.GetLocation(service.GetFromTown()) + AIMap.GetTileIndex(1, 1), "SF "+fromTotal);
		//AISign.BuildSign(AITown.GetLocation(service.GetToTown()) + AIMap.GetTileIndex(1, 1), "ST "+toTotal);
		
		AILog.Info("Best service goes from " + AITown.GetName(service.GetFromTown()) + " to " + AITown.GetName(service.GetToTown()));
	
		for(local walk = service.GetPath(); walk.GetParent() != null; walk = walk.GetParent()) {
			local a = walk.GetVertex();
			local b = walk.GetParent().GetVertex();
			local edge = Edge(a, b);
	
			if(!pz.actualGraph.GetEdges().Contains(edge)) {
				// Get the towns on this edges
				local townA = GetTown(a.ToTile());
				local townB = GetTown(b.ToTile());
	
				// Ensure we can afford to do some construction				
				FinanceManager.EnsureFundsAvailable(PathZilla.FLOAT);
	
				// Build a link between the towns
				AILog.Info(" Building a road between " + AITown.GetName(townA) + " and " + AITown.GetName(townB) + "...");
				AILog.Info("================================================");
				local success = PathFinder.FindPath(a.ToTile(), b.ToTile());
				AILog.Info("================================================");
				AILog.Info("");
				
				// If we were able to build the link, add the edge to the actual graph
				if(success > 0) {
					pz.actualGraph.AddEdge(edge);
				}
			}
		}
		
		// Ensure that the source town has bus stops
		local added = RoadManager.BuildStations(service.GetFromTown(), service.GetCargo());
		if(added > 0) {
			this.townsUpdated.AddItem(service.GetFromTown(), 0);
		}
		
		// Ensure that the destination town has bus stops
		added = RoadManager.BuildStations(service.GetToTown(), service.GetCargo());
		if(added > 0) {
			this.townsUpdated.AddItem(service.GetToTown(), 0);
		}

		// Implement the service itself
		this.CreateService(service);
	}
}

/*
 * Choose an engine to run between two specified towns, and carry the specified
 * cargo. This method is compatible with NewGRF sets that require vehciles to 
 * be refitted.
 */
function ServiceManager::SelectEngine(fromTown, toTown, cargo) {
	local availableFunds = FinanceManager.GetAvailableFunds();
	
	local engineList = AIEngineList(AIVehicle.VEHICLE_ROAD);
	engineList.Valuate(function (engine, cargo, availableFunds) {
		if(AIEngine.GetRoadType(engine) != AIRoad.ROADTYPE_ROAD) return -1;
		if(!(AIEngine.GetCargoType(engine) == cargo || AIEngine.CanRefitCargo(engine, cargo))) return -1;
		if(AIEngine.GetPrice(engine) > availableFunds) return -1;
		return 1;
	}, cargo, availableFunds);
	
	// Discount vehciles that are invalid or that can't be built
	engineList.RemoveValue(-1);

	// If none are left, then return with nothing	
	if(engineList.Count() == 0) {
		return null;
	}
	
	local distance = AITown.GetDistanceManhattanToTile(fromTown, AITown.GetLocation(toTown));
	//local totalPopulation = (AITown.GetPopulation(fromTown) + AITown.GetPopulation(toTown));
	
	// Rank the remaining engines based on suitability
	engineList.Valuate(function (engine, cargo, distance) {
		local travelTime = (179 * distance) / (10 * AIEngine.GetMaxSpeed(engine));
		local unitIncome = AICargo.GetCargoIncome(cargo, distance, travelTime);
		local profit = (unitIncome * AIEngine.GetCapacity(engine)) - ((AIEngine.GetRunningCost(engine) * travelTime) / 364);
		return profit * (AIEngine.GetReliability(engine) / 2);
	}, cargo, distance);
	
	// Return the best one
	return engineList.Begin();
}

/*
 * Implement the specified service. This method assumes that the towns that the
 * service run between are already on the network and have stations built. The
 * function finds the nearest depot, then estimates a suitable fleet size, then
 * builds the vehicles with randomly distributed orders between the stations in
 * both towns.
 */
function ServiceManager::CreateService(service) {
	// Initialise
	local fromTown = service.fromTown;
	local toTown = service.toTown;
	local cargo = service.GetCargo();
	
	// Get the stations
	local fromStations = RoadManager.GetStations(fromTown, cargo);
	local toStations = RoadManager.GetStations(toTown, cargo);
	
	// Get the locations of the target towns
	local fromTile = AITown.GetLocation(fromTown);
	local toTile = AITown.GetLocation(toTown);
	
	// Find the closest depots to the starting town
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AITile.GetDistanceManhattanToTile, fromTile);
	depots.KeepBottom(1);
	local fromDepot = depots.Begin();
	
	// Find the closest depots to the destination town
	depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AITile.GetDistanceManhattanToTile, toTile);
	depots.KeepBottom(1);
	local toDepot = depots.Begin();

	// Get type of station the vechiesl will stop at
	local truckStation = !AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS);
	local stationType = (truckStation) ? AIStation.STATION_TRUCK_STOP : AIStation.STATION_BUS_STOP;
	local radius = AIStation.GetCoverageRadius(stationType);

	// Estimate the amount that will be waiting and other details that will 
	// influence our decision on fleet size.
	local townSize = max(AITown.GetPopulation(fromTown), AITown.GetPopulation(toTown));
	local distance = AITile.GetDistanceManhattanToTile(fromTile, toTile);
	local capacity = AIEngine.GetCapacity(service.GetEngine());
	local speed = AIEngine.GetMaxSpeed(service.GetEngine());

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
	local fleetSize = max(minFleetSize, ((minAcceptance) / (capacity * 2)) * ((distance * 2) / speed));
	
	local engineName = AIEngine.GetName(service.GetEngine());
	AILog.Info("  Building a fleet of " + fleetSize + " " + engineName + ((ends_with(engineName, "s")) ? "es" : "s") + "...");
	
	// Borrow enough to buy whole fleet of vehicles
	FinanceManager.EnsureFundsAvailable(AIEngine.GetPrice(service.GetEngine()) * (fleetSize + 1));
	
	// Check if the vehicles will need to be refitted
	local needRefit = (AIEngine.GetCargoType(service.GetEngine()) != service.GetCargo());
	
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
		local v = AIVehicle.BuildVehicle(depot, service.GetEngine());
		
		// Refit the vehicle if necessary
		if(needRefit) {
			AIVehicle.RefitVehicle(v, service.GetCargo());
		}
		
		// Add orders to the vehicle
		AIOrder.AppendOrder(v, fromTile, AIOrder.AIOF_NONE);// AIOrder.AIOF_FULL_LOAD);
		AIOrder.AppendOrder(v, toTile, AIOrder.AIOF_NONE);// AIOrder.AIOF_FULL_LOAD);

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
	local fromStations = RoadManager.GetStations(service.GetFromTown(), service.GetCargo());
	local toStations = RoadManager.GetStations(service.GetToTown(), service.GetCargo());

	local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);

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
		
		local currentOrder = AIOrder.ResolveOrderPosition(v, AIOrder.CURRENT_ORDER);
		//local destination = AIOrder.GetOrderDestination(v, currentOrder);
		
		// Clear the order list i It would be nice to have an AIOrder.ClearOrders() function
		AIOrder.RemoveOrder(v, 2);
		AIOrder.RemoveOrder(v, 1);
		
		// Set the new orders
		AIOrder.AppendOrder(v, fromTile, AIOrder.AIOF_NONE);
		AIOrder.AppendOrder(v, toTile, AIOrder.AIOF_NONE);
		
		// Ensure the vehicle is still heading to the same town it was before
		AIVehicle.SkipToVehicleOrder(v, currentOrder);
	}
}
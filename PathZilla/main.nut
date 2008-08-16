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
 * main.nut
 *
 * PathZilla - A road networking AI. See readme.txt for details.
 * 
 * Author:  George Weller (Zutty)
 * Created: 16/05/2008
 * Version: 1.2
 */

class PathZilla extends AIController {
	// Constants - DO NOT change these!
	DIR_NORTH = 1;
	DIR_SOUTH = 2;
	DIR_EAST = 3;
	DIR_WEST = 4;
	TILE_LENGTH_KM = 429;

	// Info constants	
	PZ_IDENT = "PATHZILLA!"
	PZ_VERSION = 2;
	
	// Serialisation constants
	SRLZ_IDENT = 0;
	SRLZ_VERSION = 1;
	SRLZ_COMPANY_NAME = 6;
	SRLZ_HOME_TOWN = 2;
	SRLZ_PLAN_GRAPH = 3;
	SRLZ_ACTUAL_GRAPH = 4;
	SRLZ_SRVC_MANAGER = 5;
			
	// Configurable constants
	PROCESSING_PRIORITY = 100;     // Governs how often intensive procesisng tasks should wait
	PATHFINDER_MAX_STEPS = 25000;  // Maximum time the pathfinder can take to find a path
	MAX_TARGETS = 750;             // Maximum number of targets that can be in a single graph 
	FLOAT = 20000;                 // Minimum amount of money to keep at all times
	TARGET_TOWN_COVERAGE = 80;     // Percentage of town houses to fall within combined station coverage area
	NEW_VEHICLE_SPREAD_DELAY = 20; // The delay in ms between launching new vehicles in a fleet.
	MAX_BRIDGE_LENGTH = 64;        // The maximum allowable bridge length - to prevent ridiculous bridges
	MAX_POTENTIAL_SERVICES = 200;  // The maximum allowable number of potential service descriptors  
	
	// Member variables
	stop = false;
	loaded = false;
	companyName = null;
	homeTown = null;
	planGraph = null;
	actualGraph = null;
	serviceManager = null;

	constructor() {
		require("graph/Edge.nut");
		require("graph/Graph.nut");
		require("graph/GraphPathNode.nut");
		require("graph/Triangle.nut");
		require("graph/Vertex.nut");
		require("graph/impl/MinimumSpanTree.nut");
		require("graph/impl/ShortestPathTree.nut");
		require("graph/impl/Triangulation.nut");
		require("pathfinding/BasicCost.nut");
		require("pathfinding/PathCost.nut");
		require("pathfinding/PathFinder.nut");
		require("pathfinding/PathNode.nut");
		require("pathfinding/PathNodeFactory.nut");
		require("service/Service.nut");
		require("service/ServiceDescriptor.nut");
		require("service/ServiceManager.nut");
		require("struct/Collection.nut");
		require("struct/BinaryHeap.nut");
		require("struct/SortedSet.nut");
		require("common.nut");
		require("FinanceManager.nut");
		require("LandManager.nut");
		require("RoadManager.nut");

		this.loaded = false;
		this.companyName = null;
		this.serviceManager = ServiceManager(this);
	}
}

/*
 * Get a graph showing which roads we plan to build.
 */
function PathZilla::GetPlanGraph() {
	return this.planGraph;
}

/*
 * Get a graph showing which roads we have already built.
 */
function PathZilla::GetActualGraph() {
	return this.actualGraph;
}

/*
 * Start running. Most of the planning, including calculating the plan graph is
 * done before we start looping, though services are selected on the fly. The 
 * main loop manages the loan and events, maintains existing services, attempts
 * to find new services, and then finally builds one.   
 */
function PathZilla::Start() {
	AILog.Info("Starting PathZilla.... RAWR!");
	
	//local dtrsOnTownRoads = AIGameSettings.GetValue("construction.road_stop_on_town_road");
	
	// Enable auto-renew
	AICompany.SetAutoRenewStatus(true);

	// Choose a company name if we have not loaded one
	if(!this.loaded) {
		this.companyName = this.ChooseName();
	}
	
	// Set the name
	AICompany.SetCompanyName(this.companyName);

	// Select a home town from which all construction will be based
	if(!this.loaded) {
		this.homeTown = this.SelectLargeTown();
	}
	AILog.Info("  My home town is " + AITown.GetName(this.homeTown));

	// Initialse other data, based on load status
	if(!this.loaded) {
		// Build the graphs we need to plan routes
		this.InitialiseGraphs();
	} else {
		// Load the vehicles into their groups
		this.serviceManager.PostLoad();
	}
	
	// Initialise
	local ticker = 0;
	local noServices = true;
	
	// Load settings for loop latency
	local latency = this.GetSetting("latency");
	local workInterval = max(100, latency * 200);
	local maintenanceInterval = max(100, workInterval * latency * 2);
	local expansionInterval = max(100, workInterval * latency * 3);
	
	// Start the main loop
	while(!this.stop) {
		// Try to keep the amount of funds available around FLOAT, by borrowing
		// or repaying the loan.
		FinanceManager.MaintainFunds(PathZilla.FLOAT);
		
		// Check for events
		this.HandleEvents();
		
		// Maintain existing services
		if(ticker % maintenanceInterval == 0) {
			this.serviceManager.MaintainServices();
		}
		
		// Look for some new services that we can implement
		this.serviceManager.FindNewServices();
		
		// Wait until we have a fair bit of cash before building a new line
		if(noServices || (ticker % expansionInterval == 0
			 && FinanceManager.GetAvailableFunds() >= (AICompany.GetMaxLoanAmount() / 2))) {
			this.serviceManager.ImplementService();
			noServices = false;
		}

		// Advance the ticker
		ticker += workInterval;
		this.Sleep(workInterval);
	}
}

/*
 * Load state and data structures from a table. This method checks a signature
 * and version number before loading, to ensure that the data being loaded is
 * compatible with this AI. The method also relies on the classes that are used
 * as data structures implementing the Unserialize method.
 */
function PathZilla::Load(data) {
	local dataValid = false;
	
	// First check that the data is for this AI, and this verion
	if(data.rawin(PathZilla.SRLZ_IDENT)) {
		if(typeof data[PathZilla.SRLZ_IDENT] == typeof PathZilla.PZ_IDENT) {
			dataValid = (data[PathZilla.SRLZ_IDENT] == PathZilla.PZ_IDENT)
					     && (data[PathZilla.SRLZ_VERSION] == PathZilla.PZ_VERSION);
		}
	}
	
	// If we have found the right data, start loading it
	if(dataValid) { 
		this.companyName = data[PathZilla.SRLZ_COMPANY_NAME];
		this.homeTown = data[PathZilla.SRLZ_HOME_TOWN];
		
		if(data[PathZilla.SRLZ_PLAN_GRAPH] != null) {
			this.planGraph = Graph();
			this.planGraph.Unserialize(data[PathZilla.SRLZ_PLAN_GRAPH]);
		} 
		
		if(data[PathZilla.SRLZ_ACTUAL_GRAPH] != null) {
			this.actualGraph = Graph();
			this.actualGraph.Unserialize(data[PathZilla.SRLZ_ACTUAL_GRAPH]);
		}
		
		if(data.rawin(PathZilla.SRLZ_SRVC_MANAGER)) {
			this.serviceManager.Unserialize(data[PathZilla.SRLZ_SRVC_MANAGER]);
		}
		
		this.loaded = true;
	} else {
		AILog.Error("Got invalid save data");
	}
}

/*
 * Save state and data structures to a table for the game to persist. This 
 * method relies on the classes that are used as data structures implementing
 * the Serialize method.
 */
function PathZilla::Save() {
	local data = {};
	
	// Store the ident and version number
	data[PathZilla.SRLZ_IDENT] <- PathZilla.PZ_IDENT;
	data[PathZilla.SRLZ_VERSION] <- PathZilla.PZ_VERSION

	// Store the actual data
	data[PathZilla.SRLZ_COMPANY_NAME] <- this.companyName;
	data[PathZilla.SRLZ_HOME_TOWN] <- this.homeTown;
	
	if(this.planGraph != null) {
		data[PathZilla.SRLZ_PLAN_GRAPH] <- this.planGraph.Serialize();
	} 
	
	if(this.actualGraph != null) {
		data[PathZilla.SRLZ_ACTUAL_GRAPH] <- this.actualGraph.Serialize();
	} 

	if(this.serviceManager != null) {
		data[PathZilla.SRLZ_SRVC_MANAGER] <- this.serviceManager.Serialize();
	}

	return data;
}

/*
 * Chooses a company name that does not already exist and returns it. The name
 * must be applied in exec mode separately.
 */
function PathZilla::ChooseName() {
	{
		local _ = AITestMode();
		local i = 1;
		local name = "";
		
		do {
			name = "PathZilla #" + i++;
		} while(!AICompany.SetCompanyName(name));
		
		return name;
	}
}

/*
 * Randomly choose a large town from the top 10 percentile by popuation.
 */
function PathZilla::SelectLargeTown() {
	// Get a list of towns by population
	local towns = AITownList();
	towns.Valuate(AITown.GetPopulation);

	// Remove all but the larges
	local upperLimit = AITown.GetPopulation(towns.Begin());
	local lowerLimit = (upperLimit * 9) / 10;
	towns.RemoveBelowValue(lowerLimit);
	
	// Select a random town from remaining ones
	towns.Valuate(AIBase.RandItem);
	return towns.Begin();
}

/*
 * Create the plan and actual graphs based on a triangulation of all targets 
 * (up to a maximum of MAX_TARGETS) on the map.
 */
function PathZilla::InitialiseGraphs() {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(this.homeTown));
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	allTowns.Valuate(AITown.GetLocation);

	// Get the master graph for the whole map
	local masterGraph = Triangulation(allTowns);
	
	// For the plan graph use a combination of the shortest path from the home 
	// town and the minimum spanning tree.
	this.planGraph = ShortestPathTree(masterGraph, AITown.GetLocation(this.homeTown));
	this.planGraph.Merge(MinimumSpanTree(masterGraph));
	
	// Create a blank graph to represent what has actually been built
	this.actualGraph = Graph();
}

/*
 * Handle any waiting events. This is a place-holder implementation for now!
 */
function PathZilla::HandleEvents() {
	while(AIEventController.IsEventWaiting()) {
		local event = AIEventController.GetNextEvent();
		switch(event.GetEventType()) {
			case AIEvent.AI_ET_ENGINE_PREVIEW:
				local evt = AIEventEnginePreview.Convert(event);
				evt.AcceptPreview();
			break;
		}
	}
}

/*
 * Get the first basic passenger cargo ID.
 */
function PathZilla::GetCargo() {
	local cargoList = AICargoList();
	cargoList.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
	return cargoList.Begin();
}

/*
 * Get whether or not the AI should play aggressively.
 */
function PathZilla::IsAggressive() {
	return (PathZilla.GetSetting("aggressive") == 1);
}
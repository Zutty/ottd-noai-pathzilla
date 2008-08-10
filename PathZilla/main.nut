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
 * PathZilla - A road networking AI.
 * 
 * Author:  George Weller (Zutty)
 * Created: 16/05/2008
 * Version: 0.1
 */

class PathZilla extends AIController {
	// Constants - DO NOT change these!
	DIR_NORTH = 1;
	DIR_SOUTH = 2;
	DIR_EAST = 3;
	DIR_WEST = 4;
	TILE_LENGTH_KM = 429;
	
	// Configurable constants
	WORK_INTERVAL = 500;           // Interval between any actions
	MAINTENANCE_INTERVAL = 2000;   // Interval between updating existing services
	EXPANSION_INTERVAL = 3000;     // Interval between creating new services
	PROCESSING_PRIORITY = 100;     // Governs how often intensive procesisng tasks should wait
	PATHFINDER_MAX_STEPS = 25000;  // Maximum time the pathfinder can take to find a path 
	FLOAT = 20000;                 // Minimum amount of money to keep at all times
	TARGET_TOWN_COVERAGE = 80;     // Percentage of town houses to fall within combined station coverage area
	NEW_VEHICLE_SPREAD_DELAY = 20; // The delay in ms between launching new vehicles in a fleet.
	MAX_BRIDGE_LENGTH = 64;        // The maximum allowable bridge length - to prevent ridiculous bridges
	
	// Member variables
	stop = false;
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
		require("struct/BinaryHeap.nut");
		require("struct/SortedSet.nut");
		require("common.nut");
		require("FinanceManager.nut");
		require("LandManager.nut");
		require("RoadManager.nut");

		this.serviceManager = null;		
	}
}

function PathZilla::GetPlanGraph() {
	return this.planGraph;
}

function PathZilla::GetActualGraph() {
	return this.actualGraph;
}

function PathZilla::Start() {
	AILog.Info("Starting PathZilla.... RAWR!");
	
	// Pick a company name
    local i = 1;
    while(!AICompany.SetCompanyName(this.ChooseName(i++)));

	// Enable auto-renew
	AICompany.SetAutoRenewStatus(true);

	// Select a home town from which all construction will be based
	this.homeTown = this.SelectLargeTown();
	AILog.Info("  My home town is " + AITown.GetName(this.homeTown));
	
	// Build the graphs we need to plan routes
	this.InitialiseGraphs();
	
	// Create the service manager
	this.serviceManager = ServiceManager(this);
	
	// Initialise
	local ticker = 0;
	local noServices = true;

	// Start the main loop
	while(!this.stop) {
		// Try to keep the amount of funds available around FLOAT, by borrowing
		// or repaying the loan.
		FinanceManager.MaintainFunds(PathZilla.FLOAT);
		
		// Check for events
		this.HandleEvents();
		
		// Maintain existing services
		if(ticker % PathZilla.MAINTENANCE_INTERVAL) {
			this.serviceManager.MaintainServices();
		}
		
		// Look for some new services that we can implement
		this.serviceManager.FindNewServices();

		// Wait until we have a fair bit of cash before building a new line
		if(noServices || (ticker % PathZilla.EXPANSION_INTERVAL
			 && FinanceManager.GetAvailableFunds() >= (AICompany.GetMaxLoanAmount() / 2))) {
			this.serviceManager.ImplementService();
			noServices = false;
		}

		// Advance the ticker
		ticker += this.WORK_INTERVAL;
		this.Sleep(this.WORK_INTERVAL);
	}
}

function PathZilla::ChooseName(idx) {
	return "PathZilla #" + idx;
}

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

function PathZilla::InitialiseGraphs() {
	// Prime a list of targets
	local allTowns = AITownList();
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
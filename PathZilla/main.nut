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
 * PathZilla - A networking AI. See readme.txt for details.
 * 
 * Author:  George Weller (Zutty)
 * Created: 16/05/2008
 * Updated: 08/07/2009
 * Version: 6
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
	PZ_VERSION = 6;
	
	// Serialisation constants
	SRLZ_IDENT = 0;
	SRLZ_STOP = 1;
	SRLZ_COMPANY_NAME = 2;
	SRLZ_HOME_TOWN = 3;
	SRLZ_SCHEMA_IDX = 4;
	SRLZ_SCHEMAS = 5;
	SRLZ_SRVC_MANAGER = 6;
	SRLZ_SCMA_MANAGER = 9;
	SRLZ_TRGT_MANAGER = 10;
	SRLZ_TRAFFIC_BLACKSPOTS = 7;
	SRLZ_VEHICLES_TO_SELL = 8;
			
	// Configurable constants
	PROCESSING_PRIORITY = 100;     // Governs how often intensive procesisng tasks should wait
	MAX_TARGETS = 750;             // Maximum number of targets that can be in a single graph 
	FLOAT = 20000;                 // Minimum amount of money to keep at all times
	MAX_TARGET_COVERAGE = 70;      // Maximum percentage of town houses to fall within combined station coverage area
	NEW_VEHICLE_SPREAD_DELAY = 20; // The delay in ms between launching new vehicles in a fleet.
	MAX_BRIDGE_LENGTH = 16;        // The maximum allowable bridge length - to prevent ridiculous bridges
	MAX_POTENTIAL_SERVICES = 200;  // The maximum allowable number of potential service descriptors  
	ARV_ACC_THRESHOLD = 50;        // Minimum percentage of acceptance via DTRSs before ARVs can be built
	ENGINE_SCORE_THRESHOLD = 80;   // The minimum score for an engine to be randomly selected
	MAX_CONSTR_ATTEMPTS = 20;	   // The maximum number of attempts when trying to build something
	BRIBE_THRESHOLD = 3000000;	   // Minimum funds available before a bribe will be considered
	MAX_TREE_SPEND = 8000;		   // Maximum we can spend on trees to improve rating
	MAX_TOWN_RADIUS = 20;		   // Maximum distance from a town centre that anything can be built
	MAX_REPATH_TRIES = 5		   // Maximum number a times path can be re-found due to construction problems
	MAX_VEHICLES_PER_SVC = 100;	   // Maximum number of vehicles per service
	INDUSTRY_FLEET_MULTI = 4;	   // Fleet size multiplier for industrial services
	TARGET_FIX_RADIUS = 4;		   // Radius around a target we should look to fix a tile
	MAX_INITIAL_STATIONS = 3;	   // Maximum number of stations to start a service with
	PAX_SERVICE_CAP_BASE = 100;	   // Base level for limit on number of passengers AI will aim to transport
	SERVICE_PROFIT_THRESHOLD = 0;  // Threshold at which to declare a service profitable
	
	// Member variables
	stop = false;
	loaded = false;
	companyName = null;
	homeTown = null;
	serviceManager = null;
	schemaManager = null;
	targetManager = null;
	
	constructor() {
		require("aop/ProxyFactory.nut");
		require("graph/Edge.nut");
		require("graph/Graph.nut");
		require("graph/GraphPathNode.nut");
		require("graph/Triangle.nut");
		require("graph/Vertex.nut");
		require("graph/impl/MinimumSpanTree.nut");
		require("graph/impl/ShortestPathTree.nut");
		require("graph/impl/Triangulation.nut");
		require("manager/FinanceManager.nut");
		require("manager/LandManager.nut");
		require("manager/RoadManager.nut");
		require("manager/SchemaManager.nut");
		require("manager/TargetManager.nut");
		require("manager/TownManager.nut");
		require("pathfinding/PathWrapper.nut");
		require("pathfinding/Road.nut");
		require("schema/Schema.nut");
		require("service/Service.nut");
		require("service/ServiceManager.nut");
		require("service/Target.nut");
		require("struct/Collection.nut");
		require("struct/BinaryHeap.nut");
		require("struct/Map.nut");
		require("struct/SortedSet.nut");
		require("Settings.nut");
		require("common.nut");

		// Some presets that must go here
		this.loaded = false;
		
		// Set this as the singleton instance
		::pz <- this;
	}
}

/*
 * Start running. Most of the planning, including calculating the plan graph is
 * done before we start looping, though services are selected on the fly. The 
 * main loop manages the loan and events, maintains existing services, attempts
 * to find new services, and then finally builds one.   
 */
function PathZilla::Start() {
	AILog.Info("Starting PathZilla.... RAWR!");
	
	// Initialise the AI
	this.Initialise();
	
	AILog.Info("  My home town is " + AITown.GetName(this.homeTown));

	// Initialise the main loop
	local ticker = 0;
	local noServices = true;
	
	// Load settings for loop latency
	local latency = Settings.GetLatency();
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
			 && FinanceManager.GetAvailableFunds() >= (AICompany.GetMaxLoanAmount() / 4))) {
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
function PathZilla::Load(version, data) {
	local dataValid = false;
	
	// First check that the data is for this AI, and this verion
	if(SRLZ_IDENT in data) {
		if(typeof data[SRLZ_IDENT] == typeof PZ_IDENT) {
			dataValid = (data[SRLZ_IDENT] == PZ_IDENT) && (version == PZ_VERSION);
		}
	}
	
	// If the data is not valid, do not try to load
	if(!dataValid) {
		AILog.Error("Got invalid save data");
		return false;
	}

	this.loaded = true;
	::loadData <- data;
}

/*
 * Save state and data structures to a table for the game to persist. This 
 * method relies on the classes that are used as data structures implementing
 * the Serialize method.
 */
function PathZilla::Save() {
	local data = {};
	
	// Store the ident
	data[SRLZ_IDENT] <- PZ_IDENT;
	
	// Store the global variables
	data[SRLZ_TRAFFIC_BLACKSPOTS] <- ListToArray(::trafficBlackSpots);
	data[SRLZ_VEHICLES_TO_SELL] <- ListToArray(::vehiclesToSell); 

	// Store the basic data
	data[SRLZ_STOP] <- this.stop;
	data[SRLZ_COMPANY_NAME] <- this.companyName;
	data[SRLZ_HOME_TOWN] <- this.homeTown;
	
	// Store the schemas
	data[SRLZ_SRVC_MANAGER] <- this.serviceManager.Serialize();
	data[SRLZ_SCMA_MANAGER] <- this.schemaManager.Serialize();
	data[SRLZ_TRGT_MANAGER] <- this.targetManager.Serialize();

	return data;
}

/*
 * Initialise the state of the AI, either from saved state or from scratch.
 */
function PathZilla::Initialise() {
	// Enable auto-renew
	AICompany.SetAutoRenewStatus(true);
	
	// Set the managers
	this.serviceManager = ServiceManager();
	this.schemaManager = SchemaManager();
	this.targetManager = TargetManager();

	// If there is data to load then use it, otherwise start from scratch
	if(this.loaded) {
		// Load some global variables
		::trafficBlackSpots <- ArrayToList(::loadData[SRLZ_TRAFFIC_BLACKSPOTS]); 
		::vehiclesToSell <- ArrayToList(::loadData[SRLZ_VEHICLES_TO_SELL]); 

		// Load the basic data
		this.stop = ::loadData[SRLZ_STOP];
		this.homeTown = ::loadData[SRLZ_HOME_TOWN];
		this.companyName = ::loadData[SRLZ_COMPANY_NAME];

		// Load the managers
		this.serviceManager.Unserialize(::loadData[SRLZ_SRVC_MANAGER]);
		this.schemaManager.Unserialize(::loadData[SRLZ_SCMA_MANAGER]);
		this.targetManager.Unserialize(::loadData[SRLZ_TRGT_MANAGER]);

		// Load the vehicles into their groups
		this.serviceManager.PostLoad();
	} else {
		// Initialise some global variables
		::trafficBlackSpots <- AIList();
		::vehiclesToSell <- AIList();

		// Set the basic data
		this.stop = false;
		this.homeTown = this.SelectHomeTown();
		this.companyName = this.ChooseName();

		// Build the schemas
		this.schemaManager.BuildSchemas();
	}
	
	// Set the company name
	AICompany.SetName(trnc(this.companyName));
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
		} while(!AICompany.SetName(trnc(name)));
		
		return name;
	}
}

/*
 * Randomly choose a large town from the top 10 percentile by popuation.
 */
function PathZilla::SelectHomeTown() {
	// Get a list of towns by population
	local towns = AITownList();
	towns.Valuate(AITown.GetPopulation);

	// Remove all but the larges
	local upperLimit = AITown.GetPopulation(towns.Begin());
	local lowerLimit = (upperLimit * 5) / 10;
	towns.RemoveBelowValue(lowerLimit);
	
	// Find towns that have no competitors in them
	foreach(town, _ in towns) {
		// Get a list of tiles to search in
		local townTile = AITown.GetLocation(town);
		local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(townTile - offset, townTile + offset);
		tileList.Valuate(AITile.IsStationTile);
		tileList.RemoveValue(0);
		towns.SetValue(town, (tileList.IsEmpty()) ? 1 : 0);
	}
	towns.RemoveValue(0);
	
	// If there are no empty towns, just reset the list
	if(towns.IsEmpty()) {
		towns = AITownList();
		towns.Valuate(AITown.GetPopulation);
		towns.RemoveBelowValue(lowerLimit);
	}

	// Select a random town from remaining ones
	towns.Valuate(AIBase.RandItem);
	return towns.Begin();
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
			case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
				local evt = AIEventVehicleWaitingInDepot.Convert(event);
				local vehicle = evt.GetVehicleID();
				
				// If the vehicle exists and need to be sold, sell it
				if(AIVehicle.IsValidVehicle(vehicle) && ::vehiclesToSell.HasItem(vehicle)) {
					AIVehicle.SellVehicle(vehicle);
					FinanceManager.MaintainFunds(PathZilla.FLOAT);
					::vehiclesToSell.RemoveItem(vehicle);
				}
			break;
		}
	}
}
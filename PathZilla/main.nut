/*
 *	Copyright � 2008 George Weller
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
 * Updated: 24/01/2009
 * Version: 5
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
	PZ_VERSION = 5;
	
	// Serialisation constants
	SRLZ_IDENT = 0;
	SRLZ_VERSION = 1;
	SRLZ_COMPANY_NAME = 6;
	SRLZ_HOME_TOWN = 2;
	SRLZ_PLAN_GRAPH = 3;
	SRLZ_ACTUAL_GRAPH = 4;
	SRLZ_SRVC_MANAGER = 5;
	SRLZ_SCHEMAS = 7;
			
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
	
	// Member variables
	stop = false;
	loaded = false;
	companyName = null;
	homeTown = null;
	schemaIndex = 0;
	schemas = null;
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
		require("manager/FinanceManager.nut");
		require("manager/LandManager.nut");
		require("manager/RoadManager.nut");
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

		this.loaded = false;
		this.companyName = null;
		this.serviceManager = ServiceManager();
		this.schemaIndex = -1;
		this.schemas = {};
		
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
	
	// Set some global variables
	::trafficBlackSpots <- AIList();
	
	// Enable auto-renew
	AICompany.SetAutoRenewStatus(true);

	// Select a home town from which all construction will be based
	if(!this.loaded) {
		this.homeTown = this.SelectHomeTown();
	}
	AILog.Info("  My home town is " + AITown.GetName(this.homeTown));

	// Choose a company name if we have not loaded one
	if(!this.loaded) {
		this.companyName = this.ChooseName();
	}
	
	// Set the company name
	AICompany.SetName(trnc(this.companyName));

	// Initialse other data, based on load status
	if(!this.loaded) {
		// Add passenger schemas by road and tram
		local townList = AIList();
		local tramList = AIList();

		foreach(cargo, _ in AICargoList()) {
			local townprod = 0;
			foreach(town, _ in AITownList()) {
				townprod += AITown.GetMaxProduction(town, cargo);
			}
	
			local tramable = false;
			foreach(engine, _ in AIEngineList(AIVehicle.VT_ROAD)) {
				if(AIEngine.GetRoadType(engine) == AIRoad.ROADTYPE_TRAM && AIEngine.CanRefitCargo(engine, cargo)) {
					tramable = true;
					break;
				}
			}
			
			if(townprod > 0 && AICargo.GetTownEffect(cargo) != AICargo.TE_NONE) {
				townList.AddItem(cargo, 0);
			}
	
			if(tramable && AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS)) {
				tramList.AddItem(cargo, 0);
			}
		}
	

		// Add the town schema
		this.AddSchema(Schema(this.homeTown, townList, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_ROAD));
		
		// Add the tram schema, if they are supported
		if(AIRoad.IsRoadTypeAvailable(AIRoad.ROADTYPE_TRAM)) this.AddSchema(Schema(this.homeTown, tramList, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_TRAM));

		// Add raw industry cargos
		foreach(type, _ in AIIndustryTypeList()) {
			if(AIIndustryType.IsRawIndustry(type)) {
				local cargos = AIIndustryType.GetProducedCargo(type);
				cargos.Valuate(AICargo.GetTownEffect);
				cargos.KeepValue(AICargo.TE_NONE);
				
				this.AddSchema(Schema(this.homeTown, cargos, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_ROAD));
			}
		}
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
	if(data.rawin(PathZilla.SRLZ_IDENT)) {
		if(typeof data[PathZilla.SRLZ_IDENT] == typeof PathZilla.PZ_IDENT) {
			dataValid = (data[PathZilla.SRLZ_IDENT] == PathZilla.PZ_IDENT)
					     && (version == PathZilla.PZ_VERSION);
		}
	}
	
	// If we have found the right data, start loading it
	if(dataValid) { 
		this.companyName = data[PathZilla.SRLZ_COMPANY_NAME];
		this.homeTown = data[PathZilla.SRLZ_HOME_TOWN];
		
		foreach(idx, schemaData in data[PathZilla.SRLZ_SCHEMAS]) {
			this.schemas[idx] <- Schema.instance();
			this.schemas[idx].Unserialize(schemaData);
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
	
	// Store the ident
	data[PathZilla.SRLZ_IDENT] <- PathZilla.PZ_IDENT;

	// Store the basic data
	data[PathZilla.SRLZ_COMPANY_NAME] <- this.companyName;
	data[PathZilla.SRLZ_HOME_TOWN] <- this.homeTown;
	
	// Store the schemas
	data[PathZilla.SRLZ_SCHEMAS] <- {};
	foreach(idx, schema in this.schemas) {
		data[PathZilla.SRLZ_SCHEMAS][idx] <- schema.Serialize();
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
	towns.Valuate(function (town) {
		// Get a list of tiles to search in
		local townTile = AITown.GetLocation(town);
		local searchRadius = min(AIMap.DistanceFromEdge(townTile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(townTile - offset, townTile + offset);
		tileList.Valuate(AITile.IsStationTile);
		tileList.RemoveValue(0);
		return tileList.IsEmpty();
	});
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
		}
	}
}

/*
 * Get the netwrok schema with the specified id.
 */
function PathZilla::GetSchema(schemaId) {
	return this.schemas[schemaId];
}

/*
 * Increment the internal schema counter and return the schema with that
 * index. This is used to cycle through schemas in a stateless fashion.
 */
function PathZilla::GetNextSchema() {
	if(++this.schemaIndex >= this.schemas.len()) this.schemaIndex = 0; 
	return this.schemas[this.schemaIndex];
}

/*
 * Add a new network schema to them main table and give it an id.
 */
function PathZilla::AddSchema(schema) {
	local schemaId = this.schemas.len();
	schema.SetId(schemaId);
	return this.schemas[schemaId] <- schema;
	return schemaId;
}
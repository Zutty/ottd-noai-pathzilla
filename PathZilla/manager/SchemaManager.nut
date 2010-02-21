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
 * SchemaManager.nut
 * 
 * Handles all schema related functions and factory methods.
 * 
 * Author:  George Weller (Zutty)
 * Created: 21/02/2010
 * Version: 1.0
 */
 
class SchemaManager {
	// Serialisation constants
	SRLZ_SCHEMA_IDX = 0;
	SRLZ_SCHEMAS = 1;
	
	// Member variables
	schemaIndex = 0;
	schemas = null;
	
	constructor() {
		this.schemaIndex = -1;
		this.schemas = {};
	}
}

/*
 * Get the netwrok schema with the specified id.
 */
function SchemaManager::GetSchema(schemaId) {
	return this.schemas[schemaId];
}

/*
 * Increment the internal schema counter and return the schema with that
 * index. This is used to cycle through schemas in a stateless fashion.
 */
function SchemaManager::GetNextSchema() {
	if(++this.schemaIndex >= this.schemas.len()) this.schemaIndex = 0; 
	return this.schemas[this.schemaIndex];
}

/*
 * Add a new network schema to them main table and give it an id.
 */
function SchemaManager::AddSchema(schema) {
	local schemaId = this.schemas.len();
	schema.SetId(schemaId);

	local self = this;
	local proxy = ProxyFactory.CreateProxy(schema);
	ProxyFactory.AddAspect(proxy, ProxyFactory.CUT_BEFORE, "GetTargets", function ():(self) {
		if(targets == null) self.InitialiseTargets(this);
	}); 
	ProxyFactory.AddAspect(proxy, ProxyFactory.CUT_BEFORE, "GetPlanGraph", function ():(self) {
		if(planGraph == null) self.InitialiseGraphs(this);
	}); 
	ProxyFactory.DisposeAfter(proxy, "GetPlanGraph", ::pz.schemaManager.schemas ,schemaId);

	return this.schemas[schemaId] <- proxy;
	return schemaId;
}

/*
 * Build a series of schemas based on the cargos, towns, and industries 
 * available in the map.
 */
function SchemaManager::BuildSchemas() {
	// Add passenger schemas by road and tram
	local townList = AIList();
	local tramList = AIList();
	
	// Check each available cargo
	foreach(cargo, _ in AICargoList()) {
		// Get the amount of this cargo produced in towns
		local townprod = 0;
		foreach(town, _ in AITownList()) {
			townprod += AITown.GetLastMonthProduction(town, cargo);
		}
		
		// Check if there are any trams that can carry the cargo
		local tramable = false;
		foreach(engine, _ in AIEngineList(AIVehicle.VT_ROAD)) {
			if(AIEngine.GetRoadType(engine) == AIRoad.ROADTYPE_TRAM && AIEngine.CanRefitCargo(engine, cargo)) {
				tramable = true;
				break;
			}
		}
		
		// If the cargo is produced in towns and has a town effect, use it in 
		// the town schema
		if(townprod > 0 && AICargo.GetTownEffect(cargo) != AICargo.TE_NONE) {
			townList.AddItem(cargo, 0);
		}
		
		// If a cargo can be carried by tram and has is of the passenger class,
		// add it to the tram schema
		if(tramable && AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS)) {
			tramList.AddItem(cargo, 0);
		}
	}
	
	// Add the town schema
	this.AddSchema(Schema(::pz.homeTown, townList, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_ROAD));
	
	// Add the tram schema, if they are supported
	if(AIRoad.IsRoadTypeAvailable(AIRoad.ROADTYPE_TRAM)) this.AddSchema(Schema(::pz.homeTown, tramList, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_TRAM));
	
	// Check each available industry type
	foreach(type, _ in AIIndustryTypeList()) {
		// Only add support raw industries taht are not on water
		if(AIIndustryType.IsRawIndustry(type) && !AIIndustryType.IsBuiltOnWater(type)) {
			// Only transport those cargos from this industry that have no town
			// effect, i.e. dont carry passengers from oil rigs, etc...
			local cargos = AIIndustryType.GetProducedCargo(type);
			cargos.Valuate(AICargo.GetTownEffect);
			cargos.KeepValue(AICargo.TE_NONE);
			
			// Add the schema
			this.AddSchema(Schema(::pz.homeTown, cargos, AITile.TRANSPORT_ROAD, AIRoad.ROADTYPE_ROAD));
		}
	}
}

/*
 * Create the list of targets that can be serviced in this schema.
 */
function SchemaManager::InitialiseTargets(schema) {
	// Start with either industries or towns
	if(schema.IsIndustrial()) {
		schema.SetTargets(::pz.targetManager.GetIndustryTargets(schema.GetCargos()));

		// Add towns if we need to route cargo through them
		if(Settings.RouteCargoThroughTowns()) {
			schema.GetTargets().Extend(::pz.targetManager.GetTownTargets(schema));
		} else {
			// The source node is currently a town, which is no good!
			schema.SetSourceNode(this.ChooseSourceNode(schema));
		}
	} else {
		schema.SetTargets(::pz.targetManager.GetTownTargets(schema));
	}
}

/*
 * Choose a source node for the specified schema.
 */
function SchemaManager::ChooseSourceNode(schema) {
	local source;
	local bestDist = 99999;
	local homeLocation = AITown.GetLocation(schema.sourceNode);
	foreach(target in schema.GetTargets()) {
		local dist = AIIndustry.GetDistanceManhattanToTile(target.GetId(), homeLocation);
		if(dist < bestDist) {
			bestDist = dist;
			source = target;
		}
	}
	return source;
}

/*
 * Create the plan and actual graphs based on a triangulation over a list of
 * targets, chosen based on the type of schema and global settings.
 */
function SchemaManager::InitialiseGraphs(schema) {
	// Ensure the list of targets has been initialised
	if(schema.GetTargets() == null) this.InitialiseTargets(schema);
	 
	local masterGraph = Triangulation(schema.GetTargets());

	// For the plan graph use a combination of the shortest path from the home 
	// town and the minimum spanning tree.
	schema.planGraph = ShortestPathTree(masterGraph, AITown.GetLocation(schema.GetSourceNode()));
	schema.planGraph.Merge(MinimumSpanTree(masterGraph));
	
	// Create a blank graph to represent what has actually been built
	schema.actualGraph = Graph();
}

/*
 * Saves the data to a table.
 */
function SchemaManager::Serialize() {
	local data = {};
	
	data[SRLZ_SCHEMA_IDX] <- this.schemaIndex;
	data[SRLZ_SCHEMAS] <- {};
	foreach(idx, schema in this.schemas) {
		data[SRLZ_SCHEMAS][idx] <- schema.Serialize();
	}
	
	return data;
}

/*
 * Loads data from a table.
 */
function SchemaManager::Unserialize(data) {
	this.schemaIndex = data[SRLZ_SCHEMA_IDX];
	foreach(idx, schemaData in data[SRLZ_SCHEMAS]) {
		this.schemas[idx] <- Schema.instance();
		this.schemas[idx].Unserialize(schemaData);
	}
}
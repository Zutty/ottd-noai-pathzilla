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
 * Schema.nut
 *
 * A unique entity that encapsulates the graph, road and cargo types for an 
 * independant road network. The roads are not necessairly distinct from those
 * used by other schemas, but any roads shared by schemas is strictly informal,
 * as dictated by the path finder.
 * 
 * Author:  George Weller (Zutty)
 * Created: 30/08/2008
 * Version: 1.0
 */

class Schema {
	// Serialization constants
	CLASS_NAME = "Schema";
	SRLZ_SCHEMA_ID = 0;
	SRLZ_SOURCE_NODE = 1;
	SRLZ_CARGO = 2;
	SRLZ_ROAD_TYPE = 3;
	SRLZ_PLAN_GRAPH = 4;
	SRLZ_ACTUAL_GRAPH = 5;
	
	// Member variables
	id = 0;
	sourceNode = null;
	cargos = null;
	transportType = null;
	subType = null;
	planGraph = null;
	actualGraph = null;
	industrial = null;
	targets = null;

	constructor(sourceNode, cargos, transportType, subType) {
		this.id = 0;
		this.sourceNode = sourceNode;
		this.cargos = cargos;
		this.transportType = transportType;
		this.subType = subType;
		this.planGraph = null;
		this.actualGraph = null;
		this.targets = null;

		// Decide if this is an industrial service or not		
		local sampleCargo = cargos.Begin();
		local noEffect = (AICargo.GetTownEffect(sampleCargo) == AICargo.TE_NONE);

		if(!AICargo.IsFreight(sampleCargo) && !noEffect) {
			industrial = false;
		} else if(noEffect) {
			industrial = true;
		} else {
			// TODO - Heterogenous services
		}
	}
}

/*
 * Gets the schema id.
 */
function Schema::GetId() {
	return this.id;
}

/*
 * Sets the schema id.
 */
function Schema::SetId(schemaId) {
	this.id = schemaId;
}

/*
 * Get the list of cargo IDs.
 */
function Schema::GetCargos() {
	return this.cargos;
}

/*
 * Get the transport type 
 */
function Schema::GetTransportType() {
	return this.transportType;
}

/*
 * Get the sub type 
 */
function Schema::GetSubType() {
	return this.subType;
}

/*
 * Get a graph showing which links we plan to build.
 */
function Schema::GetPlanGraph() {
	if(this.planGraph == null) this.Initialise();
	
	return this.planGraph;
}

/*
 * Get a graph showing which links we have already built.
 */
function Schema::GetActualGraph() {
	if(this.actualGraph == null) this.Initialise();

	return this.actualGraph;
}

/*
 * Check if the schema is industrial, i.e. that it services industries rather
 * than towns.
 */
function Schema::IsIndustrial() {
	return this.industrial;
}

function Schema::GetTargets() {
	if(this.targets == null) this.InitialiseTargets();

	return this.targets;
}

function Schema::GetTarget(id) {
	if(this.targets == null) this.InitialiseTargets();

	return this.targets[id];
}

/*
 * Create an array of targets from all towns (up to a maximum of MAX_TARGETS)  
 * on the map.
 */
function Schema::GetTownTargets() {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(this.sourceNode));
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	
	// HACK: If using trams, only consider large towns
	if(this.GetSubType() == AIRoad.ROADTYPE_TRAM) {
		allTowns.Valuate(AITown.GetPopulation);
		allTowns.RemoveBelowValue(1000);
	}
	
	// Build a list of targets
	local targets = Map();
	foreach(town, _ in allTowns) {
		targets.Insert(Target(Target.TYPE_TOWN, town));
	}
	
	return targets;
}

/*
 * Create an array of targets from industries on the map that accept or produce 
 * the predefined cargo for this schema. 
 */
function Schema::GetIndustryTargets() {
	// Get a list of all industries that handle the appropriate cargo
	local indList = AIList();
	
	foreach(cargo, _ in this.cargos) {
		indList.AddList(AIIndustryList_CargoAccepting(cargo));
		indList.AddList(AIIndustryList_CargoProducing(cargo));
	}
	
	// The source node is currently a town, which is no good!
	indList.Valuate(AIIndustry.GetDistanceManhattanToTile, AITown.GetLocation(this.sourceNode));
	indList.Sort(AIAbstractList.SORT_BY_VALUE, true);
	this.sourceNode = indList.Begin();
	
	// Build a list of targets
	local targets = Map();
	foreach(industry, _ in indList) {
		targets.Insert(Target(Target.TYPE_INDUSTRY, industry));
	}

	return targets;
}

/*
 * Create the list of targets that can be serviced in this schema.
 */
function Schema::InitialiseTargets() {
	// Start with either industries or towns
	if(this.industrial) {
		this.targets = this.GetIndustryTargets();

		// Add towns if we need to route cargo through them
		if(Settings.RouteCargoThroughTowns()) {
			this.targets.Extend(this.GetTownTargets());
		}
	} else {
		this.targets = this.GetTownTargets();
	}
}

/*
 * Create the plan and actual graphs based on a triangulation over a list of
 * targets, chosen based on the type of schema and global settings.
 */
function Schema::Initialise() {
	// Ensure the list of targets has been initialised
	if(this.targets == null) this.InitialiseTargets();

	// Get the master graph for the whole map
	local masterGraph = Triangulation(this.targets);

	// For the plan graph use a combination of the shortest path from the home 
	// town and the minimum spanning tree.
	this.planGraph = ShortestPathTree(masterGraph, AITown.GetLocation(this.sourceNode));
	this.planGraph.Merge(MinimumSpanTree(masterGraph));
	
	// Create a blank graph to represent what has actually been built
	this.actualGraph = Graph();
}

/*
 * Saves data to a table.
 */
function Schema::Serialize() {
	local data = {};

	data[SRLZ_SCHEMA_ID] <- this.id;
	data[SRLZ_SOURCE_NODE] <- this.sourceNode;
	data[SRLZ_CARGO] <- this.cargo;
	data[SRLZ_ROAD_TYPE] <- this.roadType;
	data[SRLZ_PLAN_GRAPH] <- this.planGraph.Serialize();
	data[SRLZ_ACTUAL_GRAPH] <- this.actualGraph.Serialize();
	
	return data;
}

/*
 * Loads data from a table.
 */
function Schema::Unserialize(data) {
	this.id = data[SRLZ_SCHEMA_ID];
	this.sourceNode = data[SRLZ_SOURCE_NODE];
	this.cargo = data[SRLZ_CARGO];
	this.roadType = data[SRLZ_ROAD_TYPE];
	
	this.planGraph = Graph();
	this.planGraph.Unserialize(data[SRLZ_PLAN_GRAPH]);
	
	this.actualGraph = Graph();
	this.actualGraph.Unserialize(data[SRLZ_ACTUAL_GRAPH]);
}

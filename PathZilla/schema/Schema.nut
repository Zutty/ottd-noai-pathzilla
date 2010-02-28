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
	SRLZ_CARGOS = 2;
	SRLZ_TRANSPORT_TYPE = 3;
	SRLZ_SUB_TYPE = 4;
	SRLZ_PLAN_GRAPH = 5;
	SRLZ_ACTUAL_GRAPH = 6;
	SRLZ_INDUSTRIAL = 7;
	SRLZ_TARGETS = 8;
	
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
 * Get the source node of the schema's graph.
 */
function Schema::GetSourceNode() {
	return this.sourceNode;
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
	return this.planGraph;
}

/*
 * Set the graph showing which links we plan to build. 
 */
function Schema::SetPlanGraph(graph) {
	this.planGraph = graph;
}

/*
 * Get a graph showing which links we have already built.
 */
function Schema::GetActualGraph() {
	return this.actualGraph;
}

/*
 * Set the graph showing which links have already been built.
 */
function Schema::SetActualGraph(graph) {
	this.actualGraph = graph;
}

/*
 * Check if the schema is industrial, i.e. that it services industries rather
 * than towns.
 */
function Schema::IsIndustrial() {
	return this.industrial;
}

/*
 * Get the list of targets included in this schema. 
 */
function Schema::GetTargets() {
	return this.targets;
}

/*
 * Set the list of targets included in this schema.
 */
function Schema::SetTargets(tgts) {
	this.targets = tgts;
}

/*
 * Saves data to a table.
 */
function Schema::Serialize() {
	local data = {};

	data[SRLZ_SCHEMA_ID] <- this.id;
	data[SRLZ_SOURCE_NODE] <- this.sourceNode;
	data[SRLZ_CARGOS] <- ListToArray(this.cargos);
	data[SRLZ_TRANSPORT_TYPE] <- this.transportType;
	data[SRLZ_SUB_TYPE] <- this.subType;
	data[SRLZ_INDUSTRIAL] <- this.industrial;

	if(this.planGraph != null) data[SRLZ_PLAN_GRAPH] <- this.planGraph.Serialize();
	if(this.actualGraph != null) data[SRLZ_ACTUAL_GRAPH] <- this.actualGraph.Serialize();
	
	if(this.targets != null) data[SRLZ_TARGETS] <- this.targets.Serialize();
	
	return data;
}

/*
 * Loads data from a table.
 */
function Schema::Unserialize(data) {
	this.id = data[SRLZ_SCHEMA_ID];
	this.sourceNode = data[SRLZ_SOURCE_NODE];
	this.cargos = ArrayToList(data[SRLZ_CARGOS]);
	this.transportType = data[SRLZ_TRANSPORT_TYPE];
	this.subType = data[SRLZ_SUB_TYPE];
	this.industrial = data[SRLZ_INDUSTRIAL];
	
	if(SRLZ_PLAN_GRAPH in data) {
		this.planGraph = Graph();
		this.planGraph.Unserialize(data[SRLZ_PLAN_GRAPH]);
	}
	
	if(SRLZ_ACTUAL_GRAPH in data) {
		this.actualGraph = Graph();
		this.actualGraph.Unserialize(data[SRLZ_ACTUAL_GRAPH]);
	}
	
	if(SRLZ_TARGETS in data) {
		this.targets = {};
		this.targets.Unserialize(data[SRLZ_TARGETS]);
	}
}

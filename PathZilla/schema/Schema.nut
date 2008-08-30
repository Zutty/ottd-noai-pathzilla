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

	sourceNode = null;
	cargo = null;
	roadType = null;
	planGraph = null;
	actualGraph = null;

	constructor(sourceNode, cargo, roadType) {
		this.sourceNode = sourceNode;
		this.cargo = cargo;
		this.roadType = roadType;
		this.planGraph = null;
		this.actualGraph = null;
		
		this.InitialiseGraphs();
	}
}

/*
 * Get the cargo ID.
 */
function Schema::GetCargo() {
	return this.cargo;
}

/*
 * Get the road type 
 */
function Schema::GetRoadType() {
	return this.roadType;
}

/*
 * Get a graph showing which links we plan to build.
 */
function Schema::GetPlanGraph() {
	return this.planGraph;
}

/*
 * Get a graph showing which links we have already built.
 */
function Schema::GetActualGraph() {
	return this.actualGraph;
}

/*
 * Create the plan and actual graphs based on a triangulation of all targets 
 * (up to a maximum of MAX_TARGETS) on the map.
 */
function Schema::InitialiseGraphs() {
	// Prime a list of the closest MAX_TARGETS targets to the home town
	local allTowns = AITownList();
	allTowns.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(this.sourceNode));
	allTowns.KeepTop(PathZilla.MAX_TARGETS);
	
	if(this.GetRoadType() == AIRoad.ROADTYPE_TRAM) {
		allTowns.Valuate(AITown.GetPopulation);
		allTowns.RemoveBelowValue(1000);
	}
	
	allTowns.Valuate(AITown.GetLocation);

	// Get the master graph for the whole map
	local masterGraph = Triangulation(allTowns);
	
	// For the plan graph use a combination of the shortest path from the home 
	// town and the minimum spanning tree.
	this.planGraph = ShortestPathTree(masterGraph, AITown.GetLocation(this.sourceNode));
	this.planGraph.Merge(MinimumSpanTree(masterGraph));
	
	// Create a blank graph to represent what has actually been built
	this.actualGraph = Graph();
}

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
 * Graph.nut
 * 
 * A node graph, composed of a number of vertices.
 * 
 * Author:  George Weller (Zutty)
 * Created: 05/06/2008
 * Version: 1.1
 */

class Graph {
	data = null;
	vertices = null;
	edges = null;
	bestPaths = null;
	
	constructor() {
		this.data = {};
		this.vertices = SortedSet();
		this.edges = SortedSet();
		this.bestPaths = {};
	}
}

/*
 * Add a lone vertex to a graph.
 */
function Graph::AddVertex(vertex) {
	this.vertices.Insert(vertex);
}

/*
 * Removes a vertex from a graph, and also any edges or triangles that were 
 * connected to it.
 */
function Graph::RemoveVertex(vertex) {
	this.data.rawdelete(vertex);
	foreach(entry in this.data) {
		entry.Remove(vertex);
	}
	
	local toRemove = [];
	foreach(edge in this.edges.data) {
		if(vertex == edge.a || vertex == edge.b) {
			toRemove.insert(edge);
		}
	}
	
	foreach(r in toRemove) {
		this.edges.Remove(vertex);
	}
	
	this.vertices.Remove(vertex);
}

/*
 * Returns true if the specified vertex forms part of the graph.
 */
function Graph::ContainsVertex(vertex) {
	return this.vertices.Contains(vertex);
}

/*
 * Returns true if the vertex defined by the specified town forms part of the graph.
 */
function Graph::ContainsTown(town) {
	return this.vertices.Contains(Vertex.FromTown(town));
}

/*
 * Get a list of all vertices in this graph.
 */
function Graph::GetVertices() {
	return this.vertices;
}

/*
 * Get a list of all edges in this graph.
 */
function Graph::GetEdges() {
	return this.edges;
}

/*
 * Get a list of neightboring vertices to specified one.
 */
function Graph::GetNeighbours(vertex) {
	return this.data[vertex.ToTile()];
}

/*
 * Add an edge to the graph. This also adds both vertices.
 */
function Graph::AddEdge(edge) {
	this.edges.Insert(edge);
	this.vertices.Insert(edge.a);
	this.vertices.Insert(edge.b);
	
	if(!this.data.rawin(edge.a.ToTile())) {
		this.data[edge.a.ToTile()] <- SortedSet(); 
	}
	this.data[edge.a.ToTile()].Insert(edge.b);

	if(!this.data.rawin(edge.b.ToTile())) {
		this.data[edge.b.ToTile()] <- SortedSet(); 
	}
	this.data[edge.b.ToTile()].Insert(edge.a);
}

/*
 * Add all the edges from another graph to this one.
 */
function Graph::Merge(graph) {
	this.edges.Merge(graph.edges);
	this.vertices.Merge(graph.vertices);
	foreach(v in this.vertices) {
		if(graph.data.rawin(v.ToTile())) {
			if(!this.data.rawin(v.ToTile())) {
				this.data[v.ToTile()] <- SortedSet(); 
			}
			this.data[v.ToTile()].Merge(graph.data[v.ToTile()]);
		}
	}
}

/*
 * Get the shortest distances accross the graph from the specified source node
 * to every other node. This method uses Dijkstra's algorithm.
 */
function Graph::GetShortestDistances(source) {
	// Initialise
	local queue = BinaryHeap();
	local dist = {};
	local prev = {};
	local infinity = AIMap.GetMapSizeX() + AIMap.GetMapSizeY();
	infinity = infinity * infinity; // Square it  
	
	// Initialise distance and previous node lists
	foreach(v in this.GetVertices()) {
		local tile = v.ToTile();
		dist[tile] <- (tile == source.ToTile()) ? 0 : infinity;
		prev[tile] <- null;
		queue.Insert(DijkstraNode(tile, dist[tile]));
	}
	
	// Process each node in best first order
	local steps = 0;
	foreach(u in queue) {
		// Only sleep once every PROCESSING_PRIORITY iterations
		if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
					
		// Find the best cost node
		local uTile = u.tile;
		local uVertex = Vertex.FromTile(uTile);
		
		// Get the vertices adjacent to the current one and update them
		foreach(v in this.GetNeighbours(uVertex)) {
			local vTile = v.ToTile();
			local alt = dist[uTile] + AIMap.DistanceManhattan(uTile, vTile);
			
			// If the computed cost is better than the stored one then update
			if(alt < dist[vTile]) {
				dist[vTile] = alt;
				prev[vTile] = uVertex;
				queue.Insert(DijkstraNode(vTile, dist[vTile]));
			}
		}
	}
			
	return dist;
}

/*
 * Find the shortest path accross the edges of the graph between two specified 
 * vertices. This method caches paths to save CPU time, as graphs do not 
 * change frequently.
 */
function Graph::FindPath(aVertex, bVertex) {
	// Get the tiles
	local aTile = aVertex.ToTile();
	local bTile = bVertex.ToTile();

	// Check the cache first
	if(aTile in this.bestPaths) {
		if(bTile in this.bestPaths[aTile]) {
			return this.bestPaths[aTile][bTile];
		}
	}
	
	// Initialise	
	local open = BinaryHeap();
	local closed = AIList();
	local node = null;
	local vertex = null;
	local finalPath = null;
	local steps = 0;
	local MAX_STEPS = 1000;

	// Add the root node
	open.Insert(GraphPathNode(aVertex, null, aVertex.GetDistance(bVertex)));

	// Start the main loop
	while(open.Len() > 0) {
		// Dont hog all the CPU
		if(steps % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
		
		// Get the next node		
		node = open.Pop();
		vertex = node.GetVertex();

		// Check that weve not already tried this
		if(closed.HasItem(vertex.ToTile())) {
			continue;
		}

		//AISign.BuildSign(tile, ""+node.GetCost().GetTotalCost());

		// Ensure we dont try it again
		closed.AddItem(vertex.ToTile(), 0);
		
		// Check if we have reached our goal
		if(vertex.equals(bVertex)) {
			finalPath = node;
			break;
		}
		
		// Add potential neighbours to the open list
		foreach(v in this.GetNeighbours(vertex).data) {
			open.Insert(GraphPathNode(v, node, v.GetDistance(bVertex)));
		} 

		// Prevent the pathfinder hanging for a long time for paths that are intractable
		if(steps++ >= MAX_STEPS) {
			AILog.Error("  Path is taking too long to find.");
			break;
		}
	}
	
	// Add path to cache
	if(!this.bestPaths.rawin(aTile)) {
		this.bestPaths[aTile] <- {}
	}
	
	this.bestPaths[aTile][bTile] <- finalPath;
	
	return finalPath; 
}

/*
 * Makes a deep copy of this graph.
 */
function Graph::_cloned(original) {
	local new = Graph();
	new.data = clone original.data;
	new.vertices = clone original.vertices;
	new.edges = clone original.edges;
	return new;
}
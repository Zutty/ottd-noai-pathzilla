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
 * Version: 1.2
 */

class Graph {
	// Serialization constants
	CLASS_NAME = "Graph";
	SRLZ_EDGE_DATA = 0;
	
	// Member variables
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
	local t = vertex.ToTile();
	return (t in this.data) ? this.data[t] : SortedSet();
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
	
	// If there is only one vertex, Dijkstra wont work!
	if(this.GetVertices().Len() <= 1) {
		dist[source.ToTile()] <- 0;
		return dist;
	}

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
 * Saves data to a table.
 */
function Graph::Serialize() {
	local saveData = {};
	
	/* TODO - If non-standard targets are ever used, uncomment this
	// Serialise the targets linked to the graph
	foreach(v in this.vertices) {
		saveData[v.ToTile()+1] <- v.GetTargetId();
	}
	*/

	// Serialise a list of edges from the graph
	local edgeData = [];
	foreach(e in this.edges) {
		edgeData.append(e.a.ToTile());
		edgeData.append(e.b.ToTile());
	}
	saveData[SRLZ_EDGE_DATA] <- edgeData;
	
	return saveData;
}

/*
 * Loads data from a table.
 */
function Graph::Unserialize(saveData) {
	/* TODO - If non-standard targets are ever used, uncomment this
	// Build a list of vertices and their targets
	local vtxMap = {};
	foreach(idx, targetId in saveData) {
		if(idx < 1) continue;
		local vTile = idx - 1;
		local v = Vertex.FromTile(vTile);
		v.targetId = targetId;
		this.vertices.RawInsert(v);
		vtxMap[vTile] <- v;
	}
	*/

	// Build a graph from a serialised list of edges		
	local edgeData = saveData[SRLZ_EDGE_DATA];
	for(local i = 0; i < edgeData.len(); i += 2) {
		// Get the raw data
		local aTile = edgeData[i];
		local bTile = edgeData[i + 1];

		// Build vertices and an edge
		local a = Vertex.FromTile(aTile);
		local b = Vertex.FromTile(bTile);
		local e = Edge(a, b);
		
		// Store them
		this.vertices.RawInsert(a);
		this.vertices.RawInsert(b);
		this.edges.RawInsert(e);

		// Build neightbour lists
		if(!this.data.rawin(aTile)) {
			this.data[aTile] <- SortedSet(); 
		}
		this.data[aTile].RawInsert(b);

		if(!this.data.rawin(bTile)) {
			this.data[bTile] <- SortedSet(); 
		}
		this.data[bTile].RawInsert(a);
	}
	
	// Remove duplicate vertices
	this.vertices.RemoveDuplicates();
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
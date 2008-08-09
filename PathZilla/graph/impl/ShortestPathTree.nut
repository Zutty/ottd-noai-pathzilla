/*
 *	Copyright © 2008 George Weller
 *	
 *	This file is part of PathZilla.
 *	
 *	PathZilla is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
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
 * ShortestPathTree.nut
 * 
 * The shortest path tree of a complete graph, based on Dijkstra's algorithm. A
 * shortest path tree is a graph such that all nodes are connected to a 
 * specified root node by the shortest distance possible.
 *
 * Dijkstra's algorithm works by building up two lists; one of the best 
 * distance to the root found so far for each node, and the other of a previous
 * node for each, to trace a path back to the root by a sort of linked list. We
 * radiate out from the root node updating these lists as we go, and then when
 * finished we compile the previous node list into a list of edges for the 
 * graph.
 * 
 * Author:  George Weller (Zutty)
 * Created: 07/06/2008
 * Version: 1.1
 */

class ShortestPathTree extends Graph {
	constructor(masterGraph, rootNode) {
		Graph.constructor();
		
		// Initialise
		local source = Vertex.FromTile(rootNode);
		local dist = {};
		local prev = {};
		local visited = AIList();
		local infinity = AIMap.GetMapSizeX() + AIMap.GetMapSizeY();
		infinity = infinity * infinity; // Square it  
		
		AILog.Info("  Computing shortest path tree...");
		
		local queue = BinaryHeap();

		// Initialise distance and previous node lists
		foreach(v in masterGraph.GetVertices().data) {
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
			foreach(v in masterGraph.GetNeighbours(uVertex)) {
				local vTile = v.ToTile();
				local alt = dist[uTile] + AIMap.DistanceSquare(uTile, vTile);

				// If the computed cost is better than the stored one then update
				if(alt < dist[vTile]) {
					dist[vTile] = alt;
					prev[vTile] = uVertex;
					queue.Insert(DijkstraNode(vTile, dist[vTile]));
				}
			}
		}
	
		this.vertices = clone masterGraph.GetVertices();

		// Compile the linked list of prev nodes into a graph
		foreach(uTile, v in prev) {
			if(v != null) {
				local u = Vertex.FromTile(uTile);
				local vTile = v.ToTile();
				this.edges.RawInsert(Edge(u, v));
	
				if(!this.data.rawin(uTile)) {
					this.data[uTile] <- SortedSet(); 
				}
				this.data[uTile].RawInsert(v);
	
				if(!this.data.rawin(vTile)) {
					this.data[vTile] <- SortedSet(); 
				}
				this.data[vTile].RawInsert(u);
			}
		}

		AILog.Info("     Done");
	}
}

class DijkstraNode {
	tile = null;
	dist = null;
	
	constructor(t, d) {
		this.tile = t;
		this.dist = d;
	}
}

function DijkstraNode::_cmp(node) {
	return (this.dist == node.dist) ? 0 : ((this.dist < node.dist) ? -1 : 1);
}
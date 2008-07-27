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
 *	Foobar is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *	
 *	You should have received a copy of the GNU General Public License
 *	along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
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
 * Version: 1.0
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
		
		AILog.Info("  Computing shortest path tree...");

		// Initialise distance and previous node lists
		foreach(v in masterGraph.GetVertices().data) {
			dist[v.ToTile()] <- infinity;
			prev[v.ToTile()] <- null;
		}

		// Initialise the distance at the source node to zero		
		dist[source.ToTile()] = 0;
	
		// 
		local steps = 0;
		while(visited.Count() < masterGraph.GetVertices().Len()) {
			// Only sleep once every PROCESSING_PRIORITY iterations
			if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
				PathZilla.Sleep(1);
			}
						
			// Find the best cost node
			local bestCost = infinity + 1;
			local uTile = null;
			foreach(tile, cost in dist) {
				if(cost < bestCost && !visited.HasItem(tile)) {
					uTile = tile;
					bestCost = cost;
				}
			}
			
			local u = Vertex.FromTile(uTile);
			visited.AddItem(uTile, 0);
			
			//AILog.Info("  Selected "+u);
			
			foreach(v in masterGraph.GetNeighbours(u).data) {
				local vTile = v.ToTile();
				if(!visited.HasItem(vTile)) {
					local alt = dist[uTile] + u.GetDistance(v);
					if(alt < dist[vTile]) {
						dist[vTile] = alt;
						prev[vTile] = u;
					}
				}
			}
		}
	
		// Compile the linked list of prev nodes into a graph
		foreach(uTile, v in prev) {
			if(v != null) {
				this.AddEdge(Edge(Vertex.FromTile(uTile), v));
			}
		}

		AILog.Info("    Done.");
	}
}
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
 * MinimumSpanTree.nut
 * 
 * The minimum spanning tree of a complete graph, based on Prim's algorithm. A
 * minimum spanning tree is a tree that includes every vertex on a graph, 
 * connected by the minium distance possible.
 *
 * Prim's algorithm works by building up a graph starting from an arbitrary 
 * seed node, by adding the shortest edges that connects the graph to a vertex
 * not yet in the graph.
 *
 * This implementation uses a crude adjacency matrix and is not particularly
 * efficient, but since it is only executed once per game I'm not guing to
 * worry about it for now!
 * 
 * Author:  George Weller (Zutty)
 * Created: 06/06/2008
 * Version: 1.0
 */

class MinimumSpanTree extends Graph {
	constructor(masterGraph) {
		Graph.constructor();
		
		AILog.Info("  Computing minimum spanning tree...");

		local count = masterGraph.GetVertices().Len();
	
		// Initialise the graph using the home town
		this.AddVertex(masterGraph.GetVertices().Begin());
		
		// Connect each vertex only once 
		while(this.GetVertices().Len() < count) {
			local bestEdge = null;
			
			// Find the best edge from the master graph that connects to the
			// minimum span graph.
			foreach(v in this.GetVertices()) {
				foreach(n in masterGraph.GetNeighbours(v)) {
					if(!this.GetVertices().Contains(n)) {
						local e = Edge(v, n);
						if(bestEdge == null || e.GetLength() < bestEdge.GetLength()) {
							bestEdge = e;
						}
					}
				}
			}
			
			// Add the edge to the minimum span graph
			this.AddEdge(bestEdge);
		}
		
		AILog.Info("    Done.");
	}
}
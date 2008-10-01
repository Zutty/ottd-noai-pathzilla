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
 * This implementation uses a Binary Heap to select the best node, which gives
 * around O(e log v) time complexity, where e is the number of edges and v is
 * the nuber of vertices. This is an improvement over the old adjacency matrix
 * implementation, especially on a large map with many towns.
 * 
 * Author:  George Weller (Zutty)
 * Created: 06/06/2008
 * Version: 1.1
 */

class MinimumSpanTree extends Graph {
	constructor(masterGraph) {
		Graph.constructor();
		
		AILog.Info("  Computing minimum spanning tree...");

		// Use a special case if there are less than three vertices
		if(masterGraph.GetVertices().Len() < 3) {
			// Just copy the data!
			this.vertices = clone masterGraph.vertices;
			this.edges = clone masterGraph.edges;
			this.data = clone masterGraph.data;
			
			AILog.Info("     Done");
			return;
		}

		local queue = BinaryHeap();
		local closed = {};
		local edgeSet = SortedSet();
	
		// Initialise the graph using the home town
		local r = masterGraph.GetVertices().Begin();
		queue.Insert(PrimNode(r.ToTile(), null, 0));
		closed[r.ToTile()] <- false;
				
		// Connect each vertex only once 
		foreach(u in queue) {
			local uTile = u.tile;
			
			if(!closed[uTile]) {
				closed[uTile] <- true;
				
				local uVertex = Vertex.FromTile(uTile);
				
				if(uTile != r.ToTile()) {
					edgeSet.RawInsert(Edge(uVertex, Vertex.FromTile(u.otherTile)));
				}
				
				foreach(v in masterGraph.GetNeighbours(uVertex)) {
					local vTile = v.ToTile();

					if(!closed.rawin(vTile)) {
						closed[vTile] <- false;
					} 

					queue.Insert(PrimNode(vTile, uTile, AIMap.DistanceSquare(uTile, vTile)));
				}
			}
		}
		
		this.vertices = clone masterGraph.GetVertices();

		// Build a graph from the spanning tree edges		
		foreach(e in edgeSet) {
			this.edges.RawInsert(e);

			if(!this.data.rawin(e.a.ToTile())) {
				this.data[e.a.ToTile()] <- SortedSet(); 
			}
			this.data[e.a.ToTile()].RawInsert(e.b);

			if(!this.data.rawin(e.b.ToTile())) {
				this.data[e.b.ToTile()] <- SortedSet(); 
			}
			this.data[e.b.ToTile()].RawInsert(e.a);
		}
		
		AILog.Info("     Done.");
	}
}

/*
 * A node for a Prim's algorithm search, that allows a graph to be 
 * reconstructed.
 */
class PrimNode {
	tile = null;
	otherTile = null;
	edgeLen = 0;
	
	constructor(u, v, l) {
		this.tile = u;
		this.otherTile = v;
		this.edgeLen = l;
	}
}

/*
 * Compares this node to another. This methods orders nodes by edge length.
 */
function PrimNode::_cmp(node) {
	return (this.edgeLen == node.edgeLen) ? 0 : ((this.edgeLen < node.edgeLen) ? -1 : 1);
}
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
 * Triangulation.nut
 * 
 * The delaunay triangulation of a set of vertices. A triangulation is a 
 * subdivision of a plane into triangles. It is also a planar graph, i.e. that
 * no two edges intersect. The delaunay triangulation is a trigulation such 
 * that no point is inside the circumcircle of any triangle in the graph. This
 * avoids long, thin triangles where possible.
 *
 * The algorithm uses a sweep-line to improve efficiency. Targets are ordered
 * from south to north and so triangles are built up in this order. Once the
 * main loop reaches a target vertex that is north of any triangle, we know
 * that no further changes will be made to it, and so it is considered 
 * 'complete'. Complete triangles are removed from the main list and re-added
 * afterwards, which reduces the number of circumcircle comparisons that we 
 * need to perform.
 *
 * This implementation is based on an algorithm by Sjaak Priester. See...
 *   http://www.codeguru.com/cpp/cpp/algorithms/general/article.php/c8901
 * 
 * Author:  George Weller (Zutty)
 * Created: 05/06/2008
 * Version: 1.1
 */

class Triangulation extends Graph {
	edgeSet = null;
	
	constructor(targets) {
		Graph.constructor();
		
		targets.sort(function (a, b) {
			local al = a.GetLocation();
			local bl = b.GetLocation();
			//AILog.Info(" "+al+" <-> "+bl); 
			if(al == bl) return 0;
			return (al < bl) ? 1 : -1;
		});
		
		AILog.Info("  Computing triangulation over " + targets.len() + " targets...");

		// If there are fewer than three targets then use a special case
		if(targets.len() == 1) {
			this.vertices.RawInsert(targets[0].GetVertex());

			AILog.Info("     Done.");
			return;
		} else if(targets.len() == 2) {
			local a = targets[0].GetVertex();
			local b = targets[1].GetVertex();
			
			this.vertices.RawInsert(a);
			this.vertices.RawInsert(b);

			this.edges.RawInsert(Edge(a, b));

			this.data[a.ToTile()] <- SortedSet(); 
			this.data[a.ToTile()].RawInsert(b);

			this.data[b.ToTile()] <- SortedSet(); 
			this.data[b.ToTile()].RawInsert(a);
			
			AILog.Info("     Done.");
			return;
		}
		
		// Get the corners of the map
		local superVertices = [
				Vertex(1, 1),
				Vertex(AIMap.GetMapSizeX() - 2, 1),
				Vertex(1, AIMap.GetMapSizeY() - 2),
				Vertex(AIMap.GetMapSizeX() - 2, AIMap.GetMapSizeY() - 2)
			];
	
		// Seed the trianglation with two triangles forming a square over the entire map
		local liveTriangles = [
				Triangle(superVertices[0], superVertices[1], superVertices[2]),
				Triangle(superVertices[1], superVertices[2], superVertices[3]) 
			];
		local completedTriangles = [];
	
		// Compute the trianglation
		local steps = 0;
		foreach(target in targets) {
			// Only sleep once every PROCESSING_PRIORITY iterations
			if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
				PathZilla.Sleep(1);
			}
			
			local vertex = target.GetVertex();
			this.edgeSet = [];
			local toRemove = [];

			// Sort the triangles so that we can cut off when we find the
			// first live triangle.			
			liveTriangles.sort();
				
			// Find triangles that have been completed
			foreach(i, tri in liveTriangles) {
				local s = tri.IsSouthOf(vertex);
				if(s) {
					completedTriangles.append(tri);
					toRemove.append(i);
				} else {
					break;
				}
			}			
			
			// Remove the completed triangles
			local offset = 0;
			foreach(r in toRemove) {
				liveTriangles.remove(r - offset);
				offset++;
			}

			// Reset the remove list
			toRemove = [];

			// Check for non-empty circumcircles
			foreach(i, tri in liveTriangles) {
				// If the circumcircle is non-empty, mark the triangle for removal 
				// and add the edges to the edge buffer.
				if(tri.u.GetDistance(vertex) <= tri.r) {
					this.HandleEdge(tri.a, tri.b);
					this.HandleEdge(tri.b, tri.c);
					this.HandleEdge(tri.c, tri.a);
	
					toRemove.append(i);
				}
			}
	
			// Remove the triangles that were marked earlier		
			offset = 0;
			foreach(r in toRemove) {
				liveTriangles.remove(r - offset);
				offset++;
			}
	
			// Build new triangles from the remaining edges in the buffer
			foreach(e in this.edgeSet) {
				liveTriangles.append(Triangle(e.a, e.b, vertex));
			}
		}
		
		// Combine the two lists of triangles and sort them
		local triangles = [];
		triangles.extend(liveTriangles);
		triangles.extend(completedTriangles);
		triangles.sort();

		// Accumulate a list of edges
		local edgeAcc = SortedSet();
		foreach(tri in triangles) {
			local notSuper = !arraycontains(superVertices, tri.a) && !arraycontains(superVertices, tri.b) && !arraycontains(superVertices, tri.c);
	
			// If the triangle does not stem from any of the original super-vertices
			// (i.e. the corners of the map) then add it to the graph.
			if(notSuper) {
				edgeAcc.RawInsert(Edge(tri.a, tri.b));
				edgeAcc.RawInsert(Edge(tri.b, tri.c));
				edgeAcc.RawInsert(Edge(tri.c, tri.a));
			}
		}
		
		// Remove duplicate edges
		edgeAcc.RemoveDuplicates();

		// Build a graph from the accumulated triangles
		foreach(edge in edgeAcc) {
			this.edges.RawInsert(edge);

			this.vertices.RawInsert(edge.a);
			this.vertices.RawInsert(edge.b);

			if(!this.data.rawin(edge.a.ToTile())) {
				this.data[edge.a.ToTile()] <- SortedSet(); 
			}
			this.data[edge.a.ToTile()].RawInsert(edge.b);

			if(!this.data.rawin(edge.b.ToTile())) {
				this.data[edge.b.ToTile()] <- SortedSet(); 
			}
			this.data[edge.b.ToTile()].RawInsert(edge.a);
		}

		// Remove duplicate vertices
		this.vertices.RemoveDuplicates();

		AILog.Info("     Done.");
	}
}

/*
 * Process a new edge in mid triangulation. If the edge already exists then
 * the dupicate is deleted, otherwise it is added to the list.
 */
function Triangulation::HandleEdge(a, b) {
	local edge = Edge(a, b);
	local idx = arrayfind(this.edgeSet, edge);
	
	if(idx > 0) {
		this.edgeSet.remove(idx);
	} else {
		this.edgeSet.append(edge);
	}
}
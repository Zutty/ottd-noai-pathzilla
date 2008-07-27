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
 * Triangulation.nut
 * 
 * The delaunay triangulation of a set of vertices. A triangulation is a 
 * subdivision of a plane into triangles. It is also a planar graph, i.e. that
 * no two edges intersect. The delaunay triangulation is a trigulation such 
 * that no point is inside the circumcircle of any triangle in the graph. This
 * avoids long, thin triangles where possible.
 *
 * This implementation is based on an algorithm by Sjaak Priester. See...
 *   http://www.codeguru.com/cpp/cpp/algorithms/general/article.php/c8901
 * 
 * Author:  George Weller (Zutty)
 * Created: 05/06/2008
 * Version: 1.0
 */

class Triangulation extends Graph {
	constructor(targetList) {
		Graph.constructor();
		
		// Get the corners of the map
		local superVertices = [
				Vertex(1, 1),
				Vertex(AIMap.GetMapSizeX() - 2, 1),
				Vertex(1, AIMap.GetMapSizeY() - 2),
				Vertex(AIMap.GetMapSizeX() - 2, AIMap.GetMapSizeY() - 2)
			];
	
		// Seed the trianglation with two triangles forming a square over the entire map
		local triangles = [
				Triangle(superVertices[0], superVertices[1], superVertices[2]),
				Triangle(superVertices[1], superVertices[2], superVertices[3]) 
			];
		
		AILog.Info("  Computing delaunay triangulation...");
	
		// Compute the trianglation
		local steps = 0;
		foreach(tile in targetList) {
			// Only sleep once every PROCESSING_PRIORITY iterations
			if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
				PathZilla.Sleep(1);
			}
			
			local vertex = Vertex.FromTile(tile);
			local edges = [];
			local toRemove = [];
			
			//AILog.Info("    Checking circumcircles [" + triangles.len() + " triangles]...");
	
			// Check for non-empty circumcircles
			foreach(i, tri in triangles) {
				// If the circumcircle is non-empty, mark the triangle for removal 
				// and add the edges to the edge buffer.
				if(tri.u.GetDistance(vertex) <= tri.r - 2) {
					edges.append(Edge(tri.a, tri.b));
					edges.append(Edge(tri.b, tri.c));
					edges.append(Edge(tri.c, tri.a));
	
					toRemove.append(i);
				}
			}
	
			// Remove the triangles that were marked earlier		
			local offset = 0;
			foreach(r in toRemove) {
				triangles.remove(r - offset);
				offset++;
			}
			
			// Find duplicate edges in the edge buffer...
			edges.sort();
			local dupes = [];
			local prevEdge = null;
			foreach(e in edges) {
				if(prevEdge != null && prevEdge <= e && prevEdge >= e) {
					dupes.append(e);
				}
				prevEdge = e;
			}
			
			// ...Find which indeces reference those edges...
			toRemove = [];
			foreach(idx, e in edges) {
				if(arraycontains(dupes, e)) {
					toRemove.append(idx);
				}
			}
			
			// ...Remove those edges from the buffer
			offset = 0;
			foreach(r in toRemove) {
				edges.remove(r - offset);
				offset++;
			}
			
			//AILog.Info("    Building triangles [" + edges.len() + " edges]...");
	
			// Build new triangles from the remaining edges in the buffer
			foreach(e in edges) {
				triangles.append(Triangle(e.a, e.b, vertex));
			}
		}
	
		// Build a graph from the accumulated triangles
		foreach(tri in triangles) {
			local notSuper = !arraycontains(superVertices, tri.a) && !arraycontains(superVertices, tri.b) && !arraycontains(superVertices, tri.c);
	
			// If the triangle does not stem from any of the original super-vertices
			// (i.e. the corners of the map) then add it to the graph.
			if(notSuper) {
				this.AddEdge(Edge(tri.a, tri.b));
				this.AddEdge(Edge(tri.b, tri.c));
				this.AddEdge(Edge(tri.c, tri.a));
			}
		}

		AILog.Info("    Done.");
	}
}
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
 * Version: 1.2
 */
 
class Triangulation extends Graph {
	
	static SUPER_VERTICES = [
		Vertex(1, 1),
		Vertex(AIMap.GetMapSizeX() - 2, 1),
		Vertex(1, AIMap.GetMapSizeY() - 2),
		Vertex(AIMap.GetMapSizeX() - 2, AIMap.GetMapSizeY() - 2)
	];
	
	// Member varibles
	triangles = null;

	constructor(targets) {
		Graph.constructor();
		
		AILog.Info("  Computing triangulation over " + targets.len() + " targets...");
		
		// Seed the trianglation with two triangles forming a square over the entire map
		this.triangles = [
				Triangle(SUPER_VERTICES[0], SUPER_VERTICES[1], SUPER_VERTICES[2]),
				Triangle(SUPER_VERTICES[1], SUPER_VERTICES[2], SUPER_VERTICES[3]) 
			];

		// Get an appropriately sorted set of vertices from the list of targets			
		local vertices = this.GetTargetVertices(targets);

		// Perform the sweepline alogrithm to construct a set of delaunay 
		// triangles from the vertices
		this.SweepLine(vertices);
		
		// Convert the triangles into a standard graph representation
		this.BakeTriangles(vertices, true);
		
		// Check that we haven't missed anything
		if(this.vertices.Len() < targets.len()) {
			AILog.Warning("Some targets were not captured in triangulation.");
			// TODO - Handle this in a way that wont break adding vertices at a later time
		}
		
		AILog.Info("     Done.");
	}		
}	

/*
 * Sort the targets by location and return the vertex for each one. 
 */
function Triangulation::GetTargetVertices(targets) {
	local vertices = [];
	
	// Get the vertex for each target
	foreach(target in targets) {
		vertices.append(Vertex.FromTile(target.GetLocation()));
	}

	// Sort the vertices to make the sweepline work
	vertices.sort(function (a, b) {
		local al = a.ToTile();
		local bl = b.ToTile();
		if(al == bl) return 0;
		return (al < bl) ? 1 : -1;
	});
	
	return vertices;
}	

/*
 * Convert a set of vertices to a set of delaunay triangles. This uses the 
 * algorithm described at the top of this file. The input list of vertices is 
 * expected to be sorted. The method returns a list of all the edges that were
 * invalidated during the process, i.e. those that should no longer exist in
 * the graph. The triangles themselves are kept in the triangles member 
 * variable. This includes triangles formed form the four super vertices.
 */
function Triangulation::SweepLine(vertices) {
	local completedTriangles = [];
	local liveTriangles = this.triangles;
	local invalidatedEdges = [];

	// Compute the trianglation
	local steps = 0;
	foreach(vertex in vertices) {
		// Only sleep once every PROCESSING_PRIORITY iterations
		if(steps++ % PathZilla.PROCESSING_PRIORITY == 0) {
			PathZilla.Sleep(1);
		}
		
		// Sort the triangles so that we can cut off when we find the
		// first live triangle.			
		liveTriangles.sort();
			
		// Find triangles that have been completed
		while(liveTriangles.len() > 0) {
			if(liveTriangles[0].IsSouthOf(vertex)) {
				completedTriangles.append(liveTriangles[0]);
				liveTriangles.remove(0);
			} else {
				break;
			}
		}

		// Initialise for the loop		
		local edgeBuffer = [];
		local i = 0;

		// Check for non-empty circumcircles
		while(i < liveTriangles.len()) {
			local tri = liveTriangles[i];
			// If the circumcircle is non-empty, remove the triangle and 
			// add the edges to the edge buffer.
			if(tri.u.GetDistance(vertex) <= tri.r) {
				edgeBuffer.append(Edge(tri.a, tri.b));
				edgeBuffer.append(Edge(tri.b, tri.c));
				edgeBuffer.append(Edge(tri.c, tri.a));
				
				liveTriangles.remove(i);
			} else {
				i++;
			}
		}

		// Sort the edge buffer to group double edges together		
		edgeBuffer.sort();

		// Find double edges in the buffer and mark them for removal
		local toRemove = [];
		for(local idx = 1; idx < edgeBuffer.len(); idx++) {
			// An edge is 'double' if there are two copies of it in the buffer
			if(edgeBuffer[idx].equals(edgeBuffer[idx-1])) {
				// If the edge is double, mark it for removal from the buffer
				toRemove.append(idx-1);
				toRemove.append(idx);
				
				// Then invalidate the edge
				invalidatedEdges.append(edgeBuffer[idx])
				
				// An finally skip over the next in the buffer, as there cannot
				// be triple edges
				idx++;
			}
		}
	
		// Remove the double edges from the buffer
		local offset = 0;
		foreach(r in toRemove) {
			edgeBuffer.remove(r - offset);
			offset++;
		}
		
		// Build new triangles from the remaining edges in the buffer
		foreach(e in edgeBuffer) {
			liveTriangles.append(Triangle(e.a, e.b, vertex));
		}
	}
	
	// Combine the two lists of triangles and sort them
	this.triangles.extend(completedTriangles);
	
	// Return the edges that were invalidated
	return invalidatedEdges;
}

/*
 * Convert the set of triangles generated by the sweep-line algorithm into a
 * graph in the standard format. This method accepts an array containing the
 * vertices that were added in the preceding triangulation step, and a flag
 * specifying if these were ALL the vertices in the entire graph. If this is
 * false then only edges attached to any of these new vertices will be added
 * to the graph. Otherwise, all edges will be added. In both cases, however, 
 * edges connected to any of the four super vertices at the corners of the map
 * will not be added.
 */
function Triangulation::BakeTriangles(newVertices, visitsAll) {
	// Accumulate a list of edges
	local edgeAcc = SortedSet();

	// Inspect each edge in each triangle of the graph
	foreach(tri in this.triangles) {
		// If an edge does not stem from any of the original super-vertices
		// (i.e. the corners of the map) then add it to the graph.
		foreach(edge in tri.GetEdges()) {
			if(!edge.VisitsAny(SUPER_VERTICES) && (visitsAll || edge.VisitsAny(newVertices))) edgeAcc.RawInsert(edge);
		}
	}
	
	// Remove duplicate edges
	edgeAcc.RemoveDuplicates();
	
	// Build a graph from the accumulated triangles
	foreach(edge in edgeAcc) {
		this.edges.RawInsert(edge);
				
		if(!this.data.rawin(edge.a.ToTile())) {
			this.data[edge.a.ToTile()] <- SortedSet(); 
		}
		this.data[edge.a.ToTile()].RawInsert(edge.b);
		
		if(!this.data.rawin(edge.b.ToTile())) {
			this.data[edge.b.ToTile()] <- SortedSet(); 
		}
		this.data[edge.b.ToTile()].RawInsert(edge.a);
	}
	
	// Resolve the vertices
	this.vertices.RawMerge(newVertices);
}

/*
 * Add the specified targets to the triangulation. This re-runs the sweepline
 * and then bakes the triangles again. 
 */
function Triangulation::AddTargets(targets) {
	local vertices = this.GetTargetVertices(targets);
	
	local invalidatedEdges = this.SweepLine(vertices);
	
	foreach(edge in invalidatedEdges) {
		this.edges.Remove(edge);
	}

	this.BakeTriangles(vertices, false);
}

/*
 * Makes this a deep copy of the specified graph.
 */
function Triangulation::_cloned(original) {
	data = clone_table(original.data);
	vertices = clone original.vertices;
	edges = clone original.edges;
	triangles = clone_array(original.triangles);
}
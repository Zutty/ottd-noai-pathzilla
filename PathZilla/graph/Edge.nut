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
 * Edge.nut
 * 
 * An edge in a graph, made up of two vertices.
 * 
 * Author:  George Weller (Zutty)
 * Created: 04/06/2008
 * Version: 1.3
 */

class Edge {
	a = null;
	b = null;
	
	constructor(a, b) {
		if(a < b) {
			this.a = a;
			this.b = b;
		} else {
			this.a = b;
			this.b = a;
		}
	}
}

/*
 * Get the length of the edge
 */
function Edge::GetLength() {
	return this.a.GetDistance(this.b);
}

/*
 * Test if the edge visits the specified vertex.
 */
function Edge::Visits(vertex) {
	return (this.a.equals(vertex) || this.b.equals(vertex));
}

/*
 * Test if the edge visits any of the specified vertices.
 */
function Edge::VisitsAny(vertices) {
	foreach(vertex in vertices) {
		if(this.Visits(vertex)) return true;
	}
	
	return false;
}

/*
 * Checks to see if another edge is the same as another.
 */
function Edge::equals(edge) {
	if(edge == null) return false;
	return ((this.a.equals(edge.a) && this.b.equals(edge.b)) || (this.a.equals(edge.b) && this.b.equals(edge.a)));
}

/*
 * Compare the edge with another. This returns 0 (i.e. equal) if the edges have
 * the same vertices, and otherwise orders them by length (TBH I can't remember 
 * what this method is doing!!).
 */
function Edge::_cmp(edge) {
	if((this.a.equals(edge.a) && this.b.equals(edge.b)) || (this.a.equals(edge.b) && this.b.equals(edge.a))) {
		return 0;
	} else {
		local maxTY = max(this.a.y, this.b.y);
		local maxEY = max(edge.a.y, edge.b.y);
		return (maxTY < maxEY) ? -1 : 1;
	}
}

/*
 * Gets a string representation of this edge.
 */
function Edge::_tostring() {
	return "{" + a + " -> " + b + "}";
}
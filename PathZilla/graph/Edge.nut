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
		this.a = a;
		this.b = b;
	}
}

/*
 * Get the length of the edge
 */
function Edge::GetLength() {
	return this.a.GetDistance(this.b);
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
		local tA = (this.a.x*this.a.x + this.a.y*this.a.y);
		local tB = (this.b.x*this.b.x + this.b.y*this.b.y);
		local eA = (edge.a.x*edge.a.x + edge.a.y*edge.a.y);
		local eB = (edge.b.x*edge.b.x + edge.b.y*edge.b.y);
		
		if(tA + tB > eA + eB) {
			return -1;
		} else {
			return 1;
		}
	}
}
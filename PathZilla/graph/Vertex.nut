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
 * Vertex.nut
 * 
 * A vertex in a graph, and a point on the map that MIGHT be beyond the 
 * boundary.
 * 
 * Author:  George Weller (Zutty)
 * Created: 05/06/2008
 * Version: 1.0
 */

class Vertex {
	x = 0;
	y = 0;
	
	constructor(x, y) {
		this.x = x;
		this.y = y;
	}
}

/*
 * Test if this vertex has the same components as another.
 */
function Vertex::equals(v) {
	return (this.x == v.x && this.y == v.y);
}

/*
 * Compares this vertex to another. If the vertices have the same components 
 * then this function returns 0 (i.e. equal). Otherwise they are ordered by 
 * their Y component (for delaunay triangulation).
 */
function Vertex::_cmp(v) {
	if(this.x == v.x && this.y == v.y) return 0;
	if(this.y < v.y) return -1
	return 1;
}

/*
 * Get a string representation of this vertex
 */
function Vertex::_tostring() {
	return "[" + this.x + ", " + this.y + "]";
}

/*
 * Get the Euclidean distance between this vertex and another. 
 */
function Vertex::GetDistance(v) {
	local dX = v.x - this.x;
	local dY = v.y - this.y;
	return sqrt(dX*dX + dY*dY);
}

/*
 * Convert the vertex into a tile index for the current map.
 */
function Vertex::ToTile() {
	return AIMap.GetTileIndex(this.x, this.y);
}

/*
 * Static method to create a vertex based on a tile index in the current map.
 */
function Vertex::FromTile(tile) {
	return Vertex(AIMap.GetTileX(tile), AIMap.GetTileY(tile));
}

/*
 * Static method to create a vertex based on a town's location.
 */
function Vertex::FromTown(town) {
	local tile = AITown.GetLocation(town);
	return Vertex(AIMap.GetTileX(tile), AIMap.GetTileY(tile));
}
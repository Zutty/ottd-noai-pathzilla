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
 * GraphPathNode.nut
 * 
 * A node in a graph state space search.
 * 
 * Author:  George Weller (Zutty)
 * Created: 28/06/2008
 * Version: 1.0
 */

class GraphPathNode {
	vertex = null;
	parentNode = null;
	cost = 0;
	distance = 0;
	
	constructor(vertex, parentNode, cost) {
		this.vertex = vertex;
		this.parentNode = parentNode;
		
		if (parentNode != null) {
			this.cost = cost + parentNode.GetDistance();
			this.distance = parentNode.GetDistance() + parentNode.GetVertex().GetDistance(vertex);
		} else {
			this.cost = 0;
			this.distance = 0;
		}
	}
}

/*
 * Get the vertex that defines this node.
 */
function GraphPathNode::GetVertex() {
	return this.vertex;
}

/*
 * Get the parent node
 */
function GraphPathNode::GetParent() {
	return this.parentNode;
}

/*
 * Get the cost of this node
 */
function GraphPathNode::GetCost() {
	return this.cost;
}

function GraphPathNode::GetDistance() {
	return this.distance;
}

/*
 * Compare the node to another node. Two path nodes should be compared by their
 * total pathfinding cost.
 */
function GraphPathNode::_cmp(node) {
	if(node.GetCost() < this.GetCost()) return 1;
	if(node.GetCost() > this.GetCost()) return -1;
	return 0;
}

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
 * PathNode.nut
 * 
 * A node in a path finding state space search
 * 
 * Author:  George Weller (Zutty)
 * Created: 17/05/2008
 * Version: 1.0
 */

class PathNode {
	TYPE_FOLLOW = 0;
	TYPE_ROAD = 1;
	TYPE_TUNNEL = 2;
	TYPE_BRIDGE = 3;
	TYPE_FOLLOW_WORMHOLE = 4;
	
	tile = null;
	parentNode = null;
	cost = null; // Cost is an object
	type = 0;
	
	constructor(tile, parentNode, cost, type) {
		this.tile = tile;
		this.parentNode = parentNode;
		this.type = type;
		this.cost = cost;
	}
}

/*
 * Get the tile that defines this node 
 */
function PathNode::GetTile() {
	return this.tile;
}

/*
 * Get the parent node 
 */
function PathNode::GetParent() {
	return this.parentNode;
}

/*
 * Get the node cost object 
 */
function PathNode::GetCost() {
	return this.cost;
}

/*
 * Get the node type (e.g. TYPE_BRIDGE) 
 */
function PathNode::GetType() {
	return this.type;
}

/*
 * Set the node type (e.g. TYPE_BRIDGE) 
 */
function PathNode::SetType(type) {
	this.type = type;
}

/*
 * Compare the node to another node. Two path nodes should be compared by their
 * total pathfinding cost.
 */
function PathNode::_cmp(node) {
	if(node.GetCost().GetTotalCost() < this.GetCost().GetTotalCost()) return 1;
	if(node.GetCost().GetTotalCost() > this.GetCost().GetTotalCost()) return -1;
	return 0;
}

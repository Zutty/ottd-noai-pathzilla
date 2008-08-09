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
 * BinaryHeap.nut
 * 
 * A Squirrel implementation of a binary heap. This is a fast and efficient 
 * data structure for A* pathfinding, as we always select the node at the top
 * of the heap, and we aren't concerned about the ordering of other nodes.
 *
 * The underlying array should not be accessed for any reason.
 * 
 * Author:  George Weller (Zutty)
 * Created: 29/05/2008
 * Version: 1.0
 */

/*
 * Constructs a new empty heap.
 */
class BinaryHeap {
	data = null;
	
	constructor() {
		data = [];
	}
}

/*
 * Get the number of items in the heap.
 */
function BinaryHeap::Len() {
	return this.data.len();
}

/*
 * Insert a new item into the heap. To maintain the properties of the heap, 
 * items must only be inserted by the use of this method.
 */
function BinaryHeap::Insert(item) {
	if(item != null) {
		this.data.append(item);
		this.BubbleUp(this.data.len() - 1);
	}
}

/*
 * Remove the item at the root of the heap. To maintain the shape property, 
 * items can ONLY be removed from the root.
 */
function BinaryHeap::Pop() {
	if(this.data.len() == 0) {
		return null;
	}
	
	// Copy the top item
	local topItem = this.data[0];
	
	// Move the bottom item to the top
	local pos = this.data.len() - 1;
	this.data[0] = this.data[pos]
	this.data.remove(pos);
	
	// Restore the heap property
	this.BubbleDown(0);
	
	return topItem;
}

/*
 * Bubble the item at the specified index down to its correct position, to 
 * maintain the heap property. This method is for private use only.
 */
function BinaryHeap::BubbleDown(index) {
	if(index * 2 >= this.data.len()) {
		return;
	}
	
	local left  = index * 2;
	local right = index * 2 + 1;
	local smallest = left;
	
	if(right < (this.data.len() - 1) && this.data[left] > this.data[right]) {
		smallest = right;
	}
	
	if(this.data[smallest] < this.data[index]) {
		this.Swap(index, smallest);
		return this.BubbleDown(smallest);
	}
}

/*
 * Bubble the item at the specified index up to its correct position, to 
 * maintain the heap property. This method is for private use only.
 */
function BinaryHeap::BubbleUp(index) {
	if(index < 1) {
		return;
	}
	
	local parnt  = index / 2;
	
	if(this.data[index] < this.data[parnt]) {
		this.Swap(parnt, index);
		return this.BubbleUp(parnt);
	}
}

/* 
 * Swap the items at the specified indeces. This method is for private use 
 * only.
 */
function BinaryHeap::Swap(p, q) {
	local buffer = data[p];
	data[p] = data[q];
	data[q] = buffer;
}

/*
 * Used to enable to use of foreach on a binary heap.
 */
function BinaryHeap::_nexti(idx) {
	return (this.Len() >= 1) ? "_pop" : null;
}

/*
 * Used to enable to use of foreach on a binary heap.
 */
function BinaryHeap::_get(idx) {
	return (idx == "_pop") ? this.Pop() : null;
}
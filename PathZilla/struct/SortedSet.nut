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
 * SortedSet.nut
 * 
 * A sorted set is a unique collection of items that are always stored in 
 * sorted order.
 *
 * This is just a placeholder implementation, as I really can't be bothered to 
 * work on this for now!
 * 
 * Author:  George Weller (Zutty)
 * Created: 15/06/2008
 * Version: 1.0
 */

class SortedSet {
	data = null;
	
	constructor() {
		this.data = [];
	}
}

/*
 * Get the number of items in the set.
 */
function SortedSet::Len() {
	return this.data.len();
}

/*
 * Add a new item to the set. If the sety already contains the item then it
 * will not be added. 
 */
function SortedSet::Insert(item) {
	if(!this.Contains(item)) {
		this.data.append(item);
		//this.data.sort();
	}
}

/*
 * Re-sort the set.
 */
function SortedSet::Sort() {
	this.data.sort();
}

/*
 * Get the first item in the set.
 */
function SortedSet::Begin() {
	return (this.Len() > 0) ? this.data[0] : null;
}

/*
 * Remove the first item from the set and return it.
 */
function SortedSet::Pop() {
	return (this.Len() > 0) ? this.data.pop() : null;
}

/*
 * Check if the set contains the specified item.
 */
function SortedSet::Contains(item) {
	foreach(elem in this.data) {
		if(elem <= item && elem >= item) {
			return true;
		}
	}
	
	return false;
	//return (this.BinarySearch(item, 0, this.data.len() - 1) >= 0);
}

/*
 * Perform a binary search on the set for the specified item, between the 
 * specified left and right side pointers.
 */
function SortedSet::BinarySearch(item, left, right) {
	if(right < left) {
		return -1;
	}
	
	local pivot = left + ((right - left) / 2);
	
	if(this.data[pivot] == item) {
		return pivot;
	} else if(item < this.data[pivot]) {
		return this.BinarySearch(item, left, pivot - 1);
	} else {
		return this.BinarySearch(item, pivot + 1, right);
	}
}

/*
 * Remove an item from the set.
 */
function SortedSet::Remove(item) {
	foreach(idx, i in this.data) {
		if(i <= item && i >= item) {
			this.data.remove(idx);
			break;
		}
	}
}

/*
 * Make a deep copy of the set.
 */
function SortedSet::_cloned(original) {
	local new = SortedSet();
	new.data = clone original.data;
	return new;
}

/*
 * Get a item from to set using squirrel standard notation, e.g. sortedSet[1].
 */
function SortedSet::_get(idx) {
	return this.data[idx];
}

/*
 * Get the next index in the set. This is used by the squirrel foreach keyword.
 */
function SortedSet::_nexti(previdx) {
	return (previdx == null) ? ((this.data.len() == 0) ? null : 0)
							 : ((previdx == this.data.len() - 1) ? null : previdx + 1);
}
/*
 *	Copyright © 2008 George Weller
 *	
 *	This file is part of PathZilla.
 *	
 *	PathZilla is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 1 of the License, or
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
 * SortedSet.nut
 * 
 * A sorted set is a unique collection of items that are stored in sorted
 * order.
 *
 * This is just a placeholder implementation, as I really can't be bothered to 
 * work on this for now!
 * 
 * Author:  George Weller (Zutty)
 * Created: 15/06/2008
 * Version: 1.2
 */

class SortedSet extends Collection {
	// Serialization constants
	CLASS_NAME = "SortedSet";

	constructor() {
		::Collection.constructor();
	}
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
 * Adds a new item to the set without checking for duplicates. This is meant to
 * be used in conjuection with the RemoveDuplicates() method afterwards.
 */
function SortedSet::RawInsert(item) {
	this.data.append(item);
}

/*
 * Re-sort the set.
 */
function SortedSet::Sort() {
	this.data.sort();
}

/*
 * Re-sort the set by a certain comparator function.
 */
function SortedSet::SortBy(comparator) {
	this.data.sort(comparator);
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
 * Remove all items in the specified set from this set.
 */
function SortedSet::RemoveAll(set) {
	local toRemove = [];
	foreach(idx, i in this.data) {
		if(set.Contains(i)) {
			toRemove.append(idx);
		}
	}

	local offset = 0;
	foreach(r in toRemove) {
		this.data.remove(r - offset);
		offset++;
	}
}

/*
 * Remove those items in the list that when passed to the supplied filter 
 * function yeild a false return value. The filter should take one 
 * argument and return true if the item should be filtered from the set.
 */
function SortedSet::Filter(filterFn, ...) {
	local argv = [];
	for(local i = 0; i < vargc; i++) {
		argv.append(vargv[i]);
	}

	local toRemove = [];
	foreach(idx, i in this.data) {
		local args = [this, i];
		args.extend(argv);
		if(filterFn.acall(args)) {
			toRemove.append(idx);
		}
	}

	local offset = 0;
	foreach(r in toRemove) {
		this.data.remove(r - offset);
		offset++;
	}
}

/*
 * Remove the item at the specified index.
 */
function SortedSet::Removei(idx) {
	this.data.remove(idx);
}

/*
 * Remove all duplicate items in the set. The items in the set must implement
 * an equals() method, returning true if two items are equal.
 */
function SortedSet::RemoveDuplicates() {
	// Ensure that duplicates are adjacent
	this.data.sort();

	// Find duplicates	
	local toRemove = [];
	local prev = null;
	foreach(idx, item in this.data) {
		if(item.equals(prev)) {
			toRemove.append(idx);
		}
		
		prev = item;
	}
	
	// Remove the edges that were marked earlier		
	local offset = 0;
	foreach(r in toRemove) {
		this.data.remove(r - offset);
		offset++;
	}
}

/*
 * Add all the items from another set to this one, removing duplicates.
 */
function SortedSet::Merge(set) {
	this.data.extend(set.data);
	this.RemoveDuplicates();
}

/*
 * Make a shallow copy of the set.
 */
function SortedSet::_cloned(original) {
	this.data = clone original.data;
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

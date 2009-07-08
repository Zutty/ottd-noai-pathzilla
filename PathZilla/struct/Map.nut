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
 * Map.nut
 * 
 * A generic map structure. This structure uses a table to store the data and
 * associate it to keys, and an array of keys to allow the Map to be sorted and
 * to allow traversal. It is very important to ensure that the array of keys is
 * kept up-to-date, or operations such as SortBy() or RemoveAll() will fail.
 * 
 * Author:  George Weller (Zutty)
 * Created: 27/06/2009
 * Version: 1.0
 */

class Map {
	// Serialization constants
	CLASS_NAME = "Map";

	data = null;
	keys = null;
	
	constructor() {
		this.data = {};
		this.keys = [];
	}
}

/*
 * Get the raw data in this collection.
 */
function Map::GetData() {
	return this.data;
}

/*
 * Insert a new item into the Map. The key will be determined using the 
 * _hashkey() method of the item, which must be specified.
 */
function Map::Insert(item) {
	local key = item._hashkey();
	this.data[key] <- item;
	this.keys.append(key);
}

/*
 * Adds all the items and keys from the specified Map.
 */
function Map::Extend(items) {
	foreach(key, item in items.data) {
		this.data[key] <- item;
		this.keys.append(key);
	}
	this.RebuildKeys();
}

/*
 * Rebuild the list of keys to match those in the main table.
 */
function Map::RebuildKeys() {
	this.keys = [];
	foreach(key, _ in this.data) {
		this.keys.append(key);
	}
}

/*
 * Get the first item in the map as determined by the sorted order of the key
 * array. This is guaranteed to be stable.
 */
function Map::Begin() {
	return this.GetI(0);
}

/*
 * Get the specified item in the map as determined by the sorted order of the 
 * key array. This is guaranteed to be stable.
 */
function Map::GetI(idx) {
	return (this.data.len() > idx) ? this.data[this.keys[idx]] : null;
}

/*
 * Re-sort the keys of the map.
 */
function Map::Sort() {
	this.keys.sort();
}

/*
 * Re-sort the map keys by a certain comparator function.
 */
function Map::SortBy(comparator) {
	// Shouldn't have to do this - NEEDS FIXING
	this.RebuildKeys();

	// We want to sort the keys, but more useful to allow user to specify a 
	// comparator that sorts items instead.
	local me = this;
	this.keys.sort(function (a, b):(me, comparator) {
		return comparator(me.data[a], me.data[b]);
	});
}

/*
 * Get the number of items in the map.
 */
function Map::Len() {
	return this.data.len();
}

/*
 * Remove the specified item from the map. The item is removed by its key,
 * which is determined using the _hashkey() method.
 */
function Map::Remove(item) {
	this.RemoveKey(item._hashkey());
}

/*
 * Remove the item with the specified key from the map.
 */
function Map::RemoveKey(key) {
	// Delete the item from the table
	delete this.data[key];
	
	// Delete the key from the keyset
	foreach(idx, k in this.keys) {
		if(k == key) {
			this.keys.remove(idx);
			break;
		}
	}
}

/*
 * Remove all items from the map with keys found in the specified map.
 */
function Map::RemoveAll(items) {
	foreach(key, item in items.data) {
		if(key in this.data) {
			this.RemoveKey(key);
		}
	}
}

/*
 * Remove those items in the map that when passed to the supplied filter 
 * function yeild a false return value. The filter should take one 
 * argument and return true if the item should be filtered from the map.
 */
function Map::Filter(filterFn, ...) {
	// Build an array of arguments for the filter function
	local argv = [];
	for(local i = 0; i < vargc; i++) {
		argv.append(vargv[i]);
	}

	// Select the keys for items to be removed
	local toRemove = [];
	foreach(key, item in this.data) {
		local args = [item];
		args.extend(argv);

		if(::arr_call(filterFn, args)) {
			toRemove.append(key);
		}
	}

	// Remove them
	foreach(r in toRemove) {
		this.RemoveKey(r);
	}
}

/*
 * Saves data to a table.
 */
function Map::Serialize() {
	local saveData = {};
	
	if(this.data.len() > 0) {
		saveData[CLASS_NAME] <- this.data[this.keys.top()].getclass().CLASS_NAME;

		foreach(key, item in this.data) {
			saveData[key] <- item.Serialize();
		}
	}
	
	return saveData;
}

/*
 * Loads data from a table.
 */
function Map::Unserialize(saveData) {
	this.data = {};
	
	if(saveData.len() > 0) {
		local className = saveData[CLASS_NAME];
		
		foreach(key, item in saveData) {
			local newItem = ::load_class(className).instance();
			//newItem.constructor();
			newItem.Unserialize(item);
			this.data[key] <- newItem;
		}
	}
}

/*
 * Make a shallow copy of the map.
 */
function Map::_cloned(original) {
	this.data = clone original.data;
	this.keys = clone original.keys;
}

/*
 * Get an item from to set using squirrel standard notation, e.g. map[1].
 */
function Map::_get(key) {
	return this.data[key];
}

/*
 * Set an item in the map by the given key.
 */
function Map::_set(key, value) {
	this.data[key] = value;
}

/*
 * Create a new slot in the map.
 */
function Map::_newslot(key, value) {
	this.data[key] <- value;
	this.keys.append(key);
}

/*
 * Get the next index in the map. This is used by the squirrel foreach keyword.
 * This uses an array of keys to specify sorted order and is guaranteed to be
 * stable.
 */
function Map::_nexti(prevkey) {
	if(prevkey == null) return (this.keys.len() == 0) ? null : this.keys[0];
	local idx = ::arrayfind(this.keys, prevkey);
	if(idx == this.keys.len() - 1) return null;
	return this.keys[idx + 1]
}
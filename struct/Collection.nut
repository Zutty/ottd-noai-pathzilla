/*
 *	Copyright ? 2008 George Weller
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
 * Collection.nut
 * 
 * A generic collection of data based on an array. This class implements some
 * generic methods for concrete collection classes to use. This class should
 * not be instantiated directly.
 * 
 * Author:  George Weller (Zutty)
 * Created: 14/08/2008
 * Version: 1.0
 */

class Collection {
	data = null;
	
	constructor() {
		this.data = [];
	}
}

/*
 * Get the raw data in this collection.
 */
function Collection::GetData() {
	return this.data;
}

/*
 * Get the number of items in the collection.
 */
function Collection::Len() {
	return this.data.len();
}

/*
 * Test if the collection is empty.
 */
function Collection::IsEmpty() {
	return this.data.len() == 0;
}

/*
 * Saves an array to a table.
 */
function Collection::SerializeArray(arr) {
	local c = Collection();
	c.data = arr;
	return c.Serialize();
}

/*
 * Loads an array from a table.
 */
function Collection::UnserializeArray(saveData) {
	local c = Collection();
	c.Unserialize(saveData);
	return c.data;
}

/*
 * Saves data to a table.
 */
function Collection::Serialize() {
	local saveData = [];
	
	if(this.data.len() > 0) {
		foreach(item in this.data) {
			saveData.append(item.Serialize());
		}
		
		saveData.append(this.data.top().getclass().CLASS_NAME);
	}
	
	return saveData;
}

/*
 * Loads data from a table.
 */
function Collection::Unserialize(saveData) {
	this.data = [];
	
	if(saveData.len() > 0) {
		local className = saveData.pop();
		
		foreach(item in saveData) {
			local newItem = ::load_class(className).instance();
			//newItem.constructor();
			newItem.Unserialize(item);
			this.data.append(newItem);
		}
	}
}
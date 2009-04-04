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
 * common.nut
 * 
 * A collection of basic helper functions.
 * 
 * Author:  George Weller (Zutty)
 * Created: 24/05/2008
 * Version: 1.2
 */
 
/*
 * Square root using Newton-Raphson method.
 */
::sqrtlut <- [0, 10, 100, 1000, 10000, 100000, 1000000, 10000000];
function sqrt(d) {
    if (d == 0.0) {
    	return 0.0;
    }
    
    local nd = 0;
    for(nd = 7; nd >= 0; nd--) {
    	if(nd <= ::sqrtlut[nd]) break;
    }
    nd++;
    local x = pow(2.0, nd);
    
    for(local i = 0; i < 5; i++) {
    	x = x - (x*x - d) / (2*x);
    }
    
	return x;
}

/*
 * Raises num to the power p.
 */
function pow(num, p) {
	return (p <= 0) ? 1 : num * pow(num, p - 1);
}

/*
 * Get the maximum of two values. This is type agnostic.
 */
function max(a, b) {
	if(a >= b) return a;
	return b;
}

/*
 * Get the minimum of two values. This is type agnostic.
 */
function min(a, b) {
	if(a <= b) return a;
	return b;
}

/*
 * Taylor series approximation is sine.
 */
function sin(x) {
	return x - (pow(x, 3) / 6.0) + (pow(x, 5) / 120.0) - (pow(x, 7) / 5040.0);
}

/*
 * Taylor series approximation is cosine.
 */
function cos(x) {
	return x - (pow(x, 2) / 2.0) + (pow(x, 4) / 24.0) - (pow(x, 6) / 720.0);
}


/*
 * Returns true if the array arr contains the element item.
 */
function arraycontains(arr, item) {
	foreach(elem in arr) {
		if(elem <= item && elem >= item) {
			return true;
		}
	}
	
	return false;
}

/*
 * Get the index of the specified item from the specified array if it exists, 
 * and -1 otherwise.
 */
function arrayfind(arr, item) {
	foreach(idx, elem in arr) {
		if(elem <= item && elem >= item) {
			return idx;
		}
	}
	
	return -1;
}

/*
 * Checks if the specified string ends with the specified pattern
 */
function ends_with(string, pattern) {
	return (string.slice(string.len() - pattern.len()) == pattern);
}

/*
 * Get the town at the specified tile, or null if there isn't one.
 */
function GetTown(tile) {
	local towns = AITownList();
	towns.Valuate(AITown.GetLocation);
	towns.KeepValue(tile);
	
	if(towns.Count() > 0) {
		return towns.Begin();
	} else {
		return null;
	}
}

/*
 * Delete the sign at the specified tile, if any.
 */
function RemoveSign(tile) {
	for(local i = 0; i < AISign.GetMaxSignID(); i++) {
		if(AISign.GetLocation(i) == tile) {
			AISign.RemoveSign(i);
		}
	}
}

/*
 * Draw a line on the map between the specified points using signs. If an array
 * is also passed as a parameter, the sign ID will be appended to the array so
 * that the signs can be cleaned up later.
 */
function DrawLine(a, b, ...) {
	local len = sqrt(AITile.GetDistanceSquareToTile(a, b));
	local collate = vargc > 0;
	
	if(len > 0) {
		local deltaX = AIMap.GetTileX(b) - AIMap.GetTileX(a);
		local deltaY = AIMap.GetTileY(b) - AIMap.GetTileY(a);
		local factor = 1000;
		local stepX = deltaX * factor / len;
		local stepY = deltaY * factor / len;
		local currentPos = a;
		local offX = 0;
		local offY = 0;
		
		for(local i = 0; i < len; i++) {
			offX = (stepX * i) / factor;
			offY = (stepY * i) / factor;
			currentPos = AIMap.GetTileIndex((AIMap.GetTileX(a) + offX).tointeger(), (AIMap.GetTileY(a) + offY).tointeger());
			local signId = AISign.BuildSign(currentPos, "   ");
			if(collate) vargv[0].append(signId);
		}
	}
}

/*
 * Draw a series of lines to represent a graph.
 */
function DrawGraph(graph) {
	foreach(edge in graph.GetEdges().data) {
		this.DrawLine(edge.a.ToTile(), edge.b.ToTile());
	}
}

/*
 * Get the sum of all values in an AIList.
 */
function ListSum(list) {
	local sum = 0;
	for(local j = list.Begin(); list.HasNext(); j = list.Next()) {
		sum += list.GetValue(j);
	}
	return sum;
}

/*
 * Get a random item from an AIList, using the list values as weights. An item
 * with a higher weight value will be chosen with a higher frequency than an
 * item with a lower weight. The weights must sum to the value of the sum 
 * parameter (see ListSum()).
 */
function RandomItemByWeight(list, sum) {
	local pivot = AIBase.RandRange(sum);
	local item = list.Begin();
	local n = 0;
	
	while(list.HasNext()) {
		n += list.GetValue(item);
		
		if(n >= pivot) {
			break;
		} else {
			item = list.Next();
		}
	}

	return item;
}

/*
 * Convert an AIList to an array of integers. Values will be lost.
 */
function ListToArray(list) {
	local array = [];
	
	foreach(item, _ in list) {
		array.append(item);
	}
	
	return array;
}

/*
 * Convert an array of integers to an AIList with no values.
 */
function ArrayToList(array) {
	local list = AIList();
	
	foreach(item in array) {
		list.AddItem(item, 0);
	}
	
	return list;
}

/*
 * Truncate a string to match the OpenTTD name length requirements.
 */
function trnc(str) {
	return (str.len() > 30) ? str.slice(0, 30) : str;
}

/*
 * Get absolute value of a number
 */
function abs(val) {
	return (val < 0) ? -val : val;
}
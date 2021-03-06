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
 * Checks if the specified string starts with the specified pattern
 */
function starts_with(string, pattern) {
	return (string.slice(0, pattern.len()) == pattern);
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
	foreach(sign in AISignList()) {
		if(AISign.GetLocation(sign) == tile) {
			AISign.RemoveSign(sign);
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

/*
 * A dummy class used by the load_class() function
 */
class dummy {
	function load(idx) {
		return this[idx];
	}
}

/*
 * Load the class with the given name from the root table
 */
function load_class(classname) {
	return ::dummy.instance().load(classname);
}

/*
 * Log the values of a structured variable like an array array or table
 */
function show(var) {
	foreach(line in split(_show(var, 0), "|")) {
		if(line != "") AILog.Info(line);
	}
}

/*
 * Callback used for the show() function
 */
function _show(var, depth) {
	if(var == null) {
		return "null";
	} else if(typeof var == "table" || typeof var == "instance") {
		local indent = "";
		for(local i = 0; i < depth; i++) indent += "  ";
		local indent2 = indent + "  ";
		local str = "{|";
		foreach(name, member in var) {
			str += indent2 + name + " = " + _show(member, depth + 1) + "|";
		}
		str += indent + "}|";
			//AILog.Info(""+str);
		return str;
	} else if(typeof var == "array") {
		local indent = "";
		for(local i = 0; i < depth; i++) indent += "  ";
		local indent2 = indent + "  ";
		local str = "[|";
		for(local i = 0; i < depth; i++) indent2 += "  ";
		foreach(member in var) {
			str += indent + _show(member, depth + 1) + "|";
		}
		str += indent + "]|";
		return str;
	} else {
		return ""+var;
	}
}

/*
 * Split a string by the specified delimiter into tokens which will be 
 * returned in an array
 */
function split(str, delim) {
	if(str == null) return [];
	if(delim == null) return [str];
	local idx = str.find(delim);
	local ret = [str.slice(0, (idx != null) ? idx : str.len())];
	if(idx != null) {
		ret.extend(split(str.slice(idx+1), delim));
	}
	return ret;
}

/*
 * Returns a string composed of the elements of the supplied array with the
 * glue string concatenated between them.
 */
function join(tokens, glue) {
	local str = "";
	for(local i = 0; i<tokens.len(); i++) {
		str += tokens[i];
		if(i < tokens.len()) str += glue;
	}
	return str;
}

/*
 * Return the minimum length whole-word substring of str to be at least len 
 * characters long. For instance...
 *   chopstr("Sentfingley Market", 7) = "Sentfingley"
 *   chopstr("Fort Sunningbury", 7) = "Fort Sunningbury"
 *   chopstr("Little Fradinghead Cross", 7) = "Little Fradinghead"
 */
function chopstr(str, len) {
	local tokens = split(str, " ");
	local newStr = "";
	local l = min(len, str.len());
	local i = 0;
	while(newStr.len() < l) {
		if(newStr.len() > 0) newStr += " ";
		newStr += tokens[i++];
	}
	return newStr;
}

/*
 * Reverse the supplied string.
 */
function rev(str) {
	local revstr = "";
	for(local i = str.len(); i>0; i--) {
		revstr += str.slice(i-1, i);
	}
	return revstr;
}

/*
 * Convert the specified string to title case, i.e. where the first letter is
 * upper and all others are lower.
 */
function totitlecase(str) {
	if(str.len() == 1) return str.toupper(); 
	return str.slice(0,1).toupper() + str.slice(1).tolower();
}

/*
 * Remove each element from the array which satisfies the supplied callback.
 */
function filter_array(arr, callback) {
	local i = 0;
	while(i < arr.len()) {
		if(callback(arr[i])) {
			arr.remove(i);
		} else {
			i++;
		}
	}
}

/*
 * Call the spcified function with an array of arguments, without using acall
 */
function arr_call(func, args) {
	switch (args.len()) {
		case 0: return func();
		case 1: return func(args[0]);
		case 2: return func(args[0], args[1]);
		case 3: return func(args[0], args[1], args[2]);
		case 4: return func(args[0], args[1], args[2], args[3]);
		case 5: return func(args[0], args[1], args[2], args[3], args[4]);
		case 6: return func(args[0], args[1], args[2], args[3], args[4], args[5]);
		case 7: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
		case 8: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
		case 9: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
		case 10: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
		case 11: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]);
		case 12: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]);
		case 13: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12]);
		case 14: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13]);
		case 15: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14]);
		default: throw "Too many arguments to CallFunction";
	}
}
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
 * BasicCost.nut
 * 
 * A basic flat cost implementation for basic road following.
 * 
 * Author:  George Weller (Zutty)
 * Created: 29/05/2008
 * Version: 1.0
 */

class BasicCost {
	cost = 0;
	
	constructor(cost) {
		this.cost = cost;
	}
}

/*
 * Get the cost of this node.
 */
function BasicCost::GetTotalCost() {
	return this.cost;
}
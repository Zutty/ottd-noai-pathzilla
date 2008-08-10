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
 * PathCost.nut
 * 
 * A cost of a node in a path finding state space search.
 * 
 * Author:  George Weller (Zutty)
 * Created: 29/05/2008
 * Version: 1.0
 */
 
class PathCost {
	g = 0;
	h = 0;
	i = 0;
	j = 0;
	
	stepsTaken = 0;
	financialCost = 0;
	
	constructor(parentCost, distanceEstimate, furtherSteps, realSpending, additionalCost) {
		if(parentCost != null) { 
			this.stepsTaken = parentCost.stepsTaken + furtherSteps;
			this.financialCost = parentCost.financialCost + realSpending;
			
			g = parentCost.stepsTaken;
			h = distanceEstimate;
			i = parentCost.i + parentCost.j;
			j = additionalCost;
		} else {
			this.stepsTaken = furtherSteps;
			this.financialCost = realSpending;
			
			h = distanceEstimate;
			j = additionalCost;
		}
	}
}

/*
 * An estimate for the Manhattan length of the path.
 */
function PathCost::GetStepsTaken() {
	return this.stepsTaken;
}

/*
 * An estimate for the amount of money it will cost to construct the path.
 */
function PathCost::GetFinancialCost() {
	return this.financialCost;
}

/*
 * The normalised pathfinder cost.
 */
function PathCost::GetTotalCost() {
	//return ((this.g * 2) / 10 + this.h) + ((this.i*4)/10 + this.j);
	return (this.g + this.h) + (this.i + this.j);
}
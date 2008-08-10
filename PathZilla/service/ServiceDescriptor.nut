/*
 *	Copyright � 2008 George Weller
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
 * ServiceDescriptor.nut
 * 
 * A simple struct to allow reasoning on services before they are implemented. A
 * descriptor is essentially a proposed service.
 *
 * There are obvious synergies between this and Service.nut, and I know this 
 * isn't an ideal solutrion that I've opted or, but i'm happy with it for now.
 * 
 * Author:  George Weller (Zutty)
 * Created: 21/07/2008
 * Version: 1.0
 */

class ServiceDescriptor {
	fromTown = null;
	toTown = null;
	cargo = 0;
	engine = null;
	distance = 0;
	rawIncome = 0;
	
	constructor(fromTown, toTown, cargo, engine, distance, rawIncome) {
		this.fromTown = fromTown;
		this.toTown = toTown;
		this.cargo = cargo;
		this.engine = engine;
		this.distance = distance;
		this.rawIncome = rawIncome;
	}
}

/*
 * Get the town this this service would go from.
 */
function ServiceDescriptor::GetFromTown() {
	return this.fromTown;
}

/*
 * Get the town this this service would go to.
 */
function ServiceDescriptor::GetToTown() {
	return this.toTown;
}

/*
 * Get the cargo that this service would carry.
 */
function ServiceDescriptor::GetCargo() {
	return this.cargo;
}

/*
 * Get the engine that would operate this service
 */
function Service::GetEngine() {
	return this.engine;
}

/*
 * Get the graph path this this service would run along.
 */
function ServiceDescriptor::GetDistance() {
	return this.distance;
}

/*
 * Get the estimated income for the proposed service.
 */
function ServiceDescriptor::GetRawIncome() {
	return this.rawIncome;
}

/*
 * Implement a real service based on this descriptor.
 */
function ServiceDescriptor::Create() {
	return Service(this.fromTown, this.toTown, this.cargo, this.engine);
}

/*
 * Compare this service descriptor to another. This function returns 0 (i.e. 
 * equal) for services that would go to/from the same towns, and otherwise 
 * orders descriptors by estimated profitability. 
 */
function ServiceDescriptor::_cmp(desc) {
	if((fromTown == desc.fromTown && toTown == desc.toTown) || (fromTown == desc.toTown && toTown == desc.fromTown)) return 0;

	//local thisTotalPop = AITown.GetPopulation(this.fromTown) + AITown.GetPopulation(this.toTown);
	//local descTotalPop = AITown.GetPopulation(desc.fromTown) + AITown.GetPopulation(desc.toTown);
	
	local thisMaxPop = max(AITown.GetPopulation(this.fromTown), AITown.GetPopulation(this.toTown))
	local thisMinPop = min(AITown.GetPopulation(this.fromTown), AITown.GetPopulation(this.toTown))
	local descMaxPop = max(AITown.GetPopulation(desc.fromTown), AITown.GetPopulation(desc.toTown))
	local descMinPop = min(AITown.GetPopulation(desc.fromTown), AITown.GetPopulation(desc.toTown))
	
	local thisProfitability = (thisMaxPop + (thisMinPop * thisMinPop)) * (this.rawIncome / this.distance);
	local descProfitability = (descMaxPop + (descMinPop * descMinPop)) * (desc.rawIncome / desc.distance);

	if(thisProfitability > descProfitability) return -1;
	return 1;
}
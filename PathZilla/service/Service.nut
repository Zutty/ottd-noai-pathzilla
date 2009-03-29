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
 * Service.nut
 * 
 * A bus service between two towns.
 * 
 * Author:  George Weller (Zutty)
 * Created: 18/06/2008
 * Version: 1.1
 */

class Service {
	// Serialization constants
	CLASS_NAME = "Service";
	SRLZ_FROM_TOWN = 0;
	SRLZ_TO_TOWN = 1;
	SRLZ_CARGO = 2;
	SRLZ_ROAD_TYPE = 5;
	SRLZ_ENGINE = 3;
	SRLZ_GROUP = 4;
	SRLZ_COVERAGE_TARGET = 6;
	
	schemaId = null;
	targets = null;
	cargo = 0;
	transportType = null;
	subType = null;
	engine = null;
	profitability = 0;
	vehicles = null;
	group = null;
	distance = 0;
	rawIncome = 0;
	coverageTarget = 0;
	
	constructor(schemaId, targets, cargo, transportType, subType, engine, distance, rawIncome, coverageTarget) {
		this.schemaId = schemaId;
		this.targets = targets;
		this.cargo = cargo;
		this.transportType = transportType;
		this.subType = subType;
		this.engine = engine;
		this.distance = distance;
		this.rawIncome = rawIncome;
		this.coverageTarget = coverageTarget;
	}
}

function Service::Create() {
	this.vehicles = AIList();
	this.group = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
	AIGroup.SetName(this.group, trnc(this.targets[0].GetName() + " to " + this.targets[1].GetName()));
}

/*
 * Get the schema id
 */
function Service::GetSchemaId() {
	return this.schemaId;
}

/*
 * Get the targets this service visits.
 */
function Service::GetTargets() {
	return this.targets;
}

/*
 * Get the cargo this service carries.
 */
function Service::GetCargo() {
	return this.cargo;
}

/*
 * Get the transport type this service uses.
 */
function Service::GetTransportType() {
	return this.transportType;
}

/*
 * Get the sub-type this service uses.
 */
function Service::GetSubType() {
	return this.subType;
}

/*
 * Get the engine that this service uses
 */
function Service::GetEngine() {
	return this.engine;
}

/*
 * Set the engine that this service uses
 */
function Service::SetEngine(e) {
	return this.engine = e;
}

/*
 * Get the graph path this this service would run along.
 */
function Service::GetDistance() {
	return this.distance;
}

/*
 * Get the estimated income for the proposed service.
 */
function Service::GetRawIncome() {
	return this.rawIncome;
}

/*
 * Get the town coverage target percentage
 */
function Service::GetCoverageTarget() {
	return this.coverageTarget;
}

/*
 * Check if the service visits a target with specified Id.
 */
function Service::GoesTo(tgt) {
	foreach(target in this.targets) {
		if(target.GetId() == tgt.GetId()) return true;
	}
	return false;
}

/*
 * Check if the service visits all in a list of targets
 */
function Service::GoesToAll(targets) {
	foreach(target in targets) {
		if(!this.GoesTo(target)) return false;
	}
	return true;
}

/*
 * Checks that all targets in this service are still valid.
 */
function Service::IsValid() {
	foreach(target in targets) {
		if(!target.IsValid()) return false;
	}
	return true;
}

/*
 * Add a vehicle to the service
 */
function Service::AddVehicle(vehicleId) {
	this.vehicles.AddItem(vehicleId, 0);
	AIGroup.MoveVehicle(this.group, vehicleId);
}

/*
 * Get the vehicles that are currently operating this service.
 */
function Service::GetVehicles() {
	return this.vehicles;
}

/*
 * Get the number of vehicles that are currently operating this service.
 */
function Service::GetActualFleetSize() {
	return (this.vehicles != null) ? this.vehicles.Count() : 0;
}

/*
 * Get a string representation of this service.
 */
function Service::_tostring() {
	local strType = "";
	if(transportType == AITile.TRANSPORT_ROAD) {
		strType = (subType == AIRoad.ROADTYPE_ROAD) ? "road" : "tram";
	} else if(transportType == AITile.TRANSPORT_AIR) {
		strType = "air";
	}

	local str = "";
	if(this.targets.len() == 2) {
		str = AICargo.GetCargoLabel(this.cargo) + " from " + this.targets[0].GetName() + " to " + this.targets[1].GetName() + " by " + strType;
	}
	return str;
}

/*
 * Saves data to a table.
 */
function Service::Serialize() {
	local data = {};
	//data[SRLZ_FROM_TOWN] <- this.fromTown;
	//data[SRLZ_TO_TOWN] <- this.toTown;
	//data[SRLZ_CARGO] <- this.cargo;
	//data[SRLZ_ROAD_TYPE] <- this.roadType;
	//data[SRLZ_ENGINE] <- this.engine;
	//data[SRLZ_GROUP] <- this.group;
	//data[SRLZ_COVERAGE_TARGET] <- this.coverageTarget;
	return data;
}

/*
 * Loads data from a table.
 */
function Service::Unserialize(data) {
	//this.fromTown = data[SRLZ_FROM_TOWN];
	//this.toTown = data[SRLZ_TO_TOWN];
	//this.cargo = data[SRLZ_CARGO];
	//this.roadType = data[SRLZ_ROAD_TYPE];
	//this.engine = data[SRLZ_ENGINE];
	//this.vehicles = AIList();
	//this.group = data[SRLZ_GROUP];
	//this.coverageTarget = data[SRLZ_COVERAGE_TARGET];
}

/*
 * Compare this service to another. This function returns 0 (i.e. equal) for 
 * services that go to/from the same towns, and otherwise orders services by
 * profitability. 
 */
function Service::_cmp(svc) {
	local same = this.cargo == svc.cargo;
	same = same && this.transportType == svc.transportType;
	same = same && this.subType == svc.subType;
	if(same) {
		foreach(target in this.targets) {
			same = same && svc.GoesTo(target);
		}
	}
	if(same) return 0; 
	
	local tProfit = this.rawIncome / this.distance;
	local sProfit = svc.rawIncome / svc.distance;
	
	local tMaxPop = 0;
	local tMinPop = 10000000;
	local tAllTowns = true;
	local sMaxPop = 0;
	local sMinPop = 10000000;
	local sAllTowns = true;
	
	foreach(target in this.targets) {
		if(target.GetType() == Target.TYPE_TOWN) {
			tMaxPop = max(tMaxPop, AITown.GetPopulation(target.GetId()));
			tMinPop = min(tMinPop, AITown.GetPopulation(target.GetId()));
		} else {
			tAllTowns = false;
		}
	}
	foreach(target in svc.targets) {
		if(target.GetType() == Target.TYPE_TOWN) {
			sMaxPop = max(sMaxPop, AITown.GetPopulation(target.GetId()));
			sMinPop = min(sMinPop, AITown.GetPopulation(target.GetId()));
		} else {
			sAllTowns = false;
		}
	}

	// If both services are for towns only then weight them by population(-ish)
	if(tAllTowns && sAllTowns) {
		tProfit *= (tMaxPop + (tMinPop * tMinPop));
		sProfit *= (sMaxPop + (sMinPop * sMinPop));
	}

	if(tProfit > sProfit) return -1;
	return 1;
}
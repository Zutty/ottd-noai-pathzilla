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
	SRLZ_SCHEMA_ID = 0;
	SRLZ_TARGETS = 1;
	SRLZ_CARGO = 2;
	SRLZ_TRANSPORT_TYPE = 3;
	SRLZ_SUB_TYPE = 4;
	SRLZ_ENGINE = 5;
	SRLZ_PROFITABILITY = 6;
	SRLZ_GROUP = 7;
	SRLZ_DISTANCE = 8;
	SRLZ_RAW_INCOME = 9;
	SRLZ_COVERAGE_TARGET = 10;
	
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
	// Create a group for the vehicles
	this.vehicles = AIList();
	this.group = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
	
	// Name the group
	local last = this.targets.len() - 1;
	local fstr = chopstr(this.targets[0].GetName(), 7);
	local tstr = chopstr(this.targets[last].GetName(), 7);
	local strName = ::pz.namingScheme.NameCargo(this.cargo) + " " + fstr + " to " + tstr;
	AIGroup.SetName(this.group, trnc(strName));
}

/*
 * Get the schema id
 */
function Service::GetSchemaId() {
	return this.schemaId;
}

/*
 * Get the ids of the targets this service visits.
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
function Service::GoesToAll(tgts) {
	foreach(tgt in tgts) {
		if(!this.GoesTo(tgt)) return false;
	}
	return true;
}

/*
 * Checks that all targets in this service are still valid.
 */
function Service::IsValid() {
	foreach(target in this.targets) {
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
 * Check if the service turned an overall profit last year
 */
function Service::IsProfitable() {
	local vlist = this.vehicles;
	vlist.Valuate(AIVehicle.GetProfitLastYear);
	local total = ListSum(vlist);
	return (total >= PathZilla.SERVICE_PROFIT_THRESHOLD);
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

	local last = this.targets.len() - 1;
	local strTgts = this.targets[0].GetName() + " to " + this.targets[last].GetName();

	local str = "";
	if(this.targets.len() == 2) {
		str = ::pz.namingScheme.NameCargo(this.cargo) + " from " + strTgts + " by " + strType;
	}
	return str;
}

/*
 * Saves data to a table.
 */
function Service::Serialize() {
	local data = {};
	
	data[SRLZ_SCHEMA_ID] <- this.schemaId;
	data[SRLZ_TARGETS] <- this.targets;
	data[SRLZ_CARGO] <- this.cargo;
	data[SRLZ_TRANSPORT_TYPE] <- this.transportType;
	data[SRLZ_SUB_TYPE] <- this.subType;
	data[SRLZ_ENGINE] <- this.engine;
	data[SRLZ_PROFITABILITY] <- this.profitability;
	data[SRLZ_GROUP] <- this.group;
	data[SRLZ_DISTANCE] <- this.distance;
	data[SRLZ_RAW_INCOME] <- this.rawIncome;
	data[SRLZ_COVERAGE_TARGET] <- this.coverageTarget;
	
	return data;
}

/*
 * Loads data from a table.
 */
function Service::Unserialize(data) {
	this.schemaId = data[SRLZ_SCHEMA_ID];
	this.targets = data[SRLZ_TARGETS];
	this.cargo = data[SRLZ_CARGO];
	this.transportType = data[SRLZ_TRANSPORT_TYPE];
	this.subType = data[SRLZ_SUB_TYPE];
	this.engine = data[SRLZ_ENGINE];
	this.profitability = data[SRLZ_PROFITABILITY];
	this.group = data[SRLZ_GROUP];
	this.distance = data[SRLZ_DISTANCE];
	this.rawIncome = data[SRLZ_RAW_INCOME];
	this.coverageTarget = data[SRLZ_COVERAGE_TARGET];
	this.vehicles = AIList();
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
	
	foreach(target in this.GetTargets()) {
		if(target.GetType() == Target.TYPE_TOWN) {
			tMaxPop = max(tMaxPop, AITown.GetPopulation(target.GetId()));
			tMinPop = min(tMinPop, AITown.GetPopulation(target.GetId()));
		} else {
			tAllTowns = false;
		}
	}
	foreach(target in svc.GetTargets()) {
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
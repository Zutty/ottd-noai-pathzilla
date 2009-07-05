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
 * Target.nut
 * 
 * An entity that can form part of a service, currently either a town or an
 * industry.
 * 
 * Author:  George Weller (Zutty)
 * Created: 30/01/2008
 * Version: 1.0
 */

class Target {
	// Serialization constants
	CLASS_NAME = "Target";
	SRLZ_TYPE = 0;
	SRLZ_ID = 1;
	SRLZ_TILE = 2;

	// Other constants
	TYPE_TOWN = 1;
	TYPE_INDUSTRY = 2;
	TILE_UNFIXED = -4194305; // 2048^2 + 1
	
	type = null;
	id = null;
	tile = null;
	
	constructor(type, id) {
		this.type = type;
		this.id = id;
		
		if(type == Target.TYPE_TOWN) {
			this.tile = AITown.GetLocation(id);
		} else if(type == Target.TYPE_INDUSTRY) {
			this.tile = TILE_UNFIXED;
		}
	}
}

/*
 * Get the tile at to which all links should be made. This tile is guaranteed
 * to the buildable.
 */
function Target::GetTile() {
	return abs(this.tile);
}

/*
 * Returns true if the position of the buildable tile has been fixed yet.
 */
function Target::IsTileFixed() {
	return (this.tile > 0);
}

/*
 * Check if the position has not yet been fixed.
 */
function Target::IsTileUnfixed() {
	return (this.tile == Target.TILE_UNFIXED);
}

/*
 * Check if the fixed tile can be refixed.
 */
function Target::IsTileSemiFixed() {
	return (this.tile < 0 && this.tile != Target.TILE_UNFIXED);
}

/*
 * Fix the seed tile to be a specified tile.
 */
function Target::FixTile(f) {
	if(this.tile < 0) this.tile = f;
}

/*
 * Fix the seed tile in a way that can be reapplied.
 */
function Target::SemiFixTile(f) {
	if(this.tile == Target.TILE_UNFIXED) this.tile = -f;
}

/*
 * Get the rough location of this target. This tile should NOT be used for
 * construction, only for planning.
 */
function Target::GetLocation() {
	local tile = -1;
	
	if(!this.IsValid()) return tile;
	
	if(this.type == Target.TYPE_TOWN) {
		tile = AITown.GetLocation(this.id);
	} else if(this.type == Target.TYPE_INDUSTRY) {
		tile = AIIndustry.GetLocation(this.id);
	}
	return tile;
}

/*
 * Returns this target as a vertex that preserves the underlying state.
 */
function Target::GetVertex() {
	local tile = this.GetLocation();
	return Vertex(AIMap.GetTileX(tile), AIMap.GetTileY(tile), this._hashkey());
}

/*
 * Get the type of this target.
 */
function Target::GetType() {
	return this.type;
}

/*
 * Returns true if this target ponts to a town.
 */
function Target::IsTown() {
	return (this.type == Target.TYPE_TOWN);
}

/*
 * Check if the target is still valid.
 */
function Target::IsValid() {
	if(this.type == Target.TYPE_TOWN) return AITown.IsValidTown(this.id);
	return AIIndustry.IsValidIndustry(this.id);
}

/*
 * Get the underlying Id of the town or industry this target points to.
 */
function Target::GetId() {
	return this.id;
}

/*
 * Checks if the target produces the specified cargo.
 */
function Target::ProducesCargo(cargo) {
	// Pre-condition - Check that the target is still valid
	if(!this.IsValid()) return false;
	
	// If the target is a town check each tile in its influence for production
	if(this.type == Target.TYPE_TOWN) {
		if(AICargo.GetTownEffect(cargo) == AICargo.TE_NONE) return false;
		
		local searchRadius = min(AIMap.DistanceFromEdge(this.tile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(this.tile - offset, this.tile + offset);
		tileList.Valuate(function(tile, id) {
			return AITown.IsWithinTownInfluence(id, tile);
		}, this.id);
		tileList.KeepValue(1);
		tileList.Valuate(function(tile, cargo) {
			return AITile.GetCargoProduction(tile, cargo, 1, 1, 0);
		}, cargo);

		return ListSum(tileList) > 0;
	}

	// Otherwise check the list of cargos for the appropriate industry type
	local indType = AIIndustry.GetIndustryType(this.id);
	if(!AIIndustryType.IsValidIndustryType(indType)) return false;
	return AIIndustryType.GetProducedCargo(indType).HasItem(cargo);
}

/*
 * Checks if the target accepts the specified cargo.
 */
function Target::AcceptsCargo(cargo) {
	// Pre-condition - Check that the target is still valid
	if(!this.IsValid()) return false;

	// If the target is a town check each tile in its influence for acceptance
	if(this.type == Target.TYPE_TOWN) {
		if(AICargo.GetTownEffect(cargo) == AICargo.TE_NONE) return false;

		local searchRadius = min(AIMap.DistanceFromEdge(this.tile) - 1, PathZilla.MAX_TOWN_RADIUS);
		local offset = AIMap.GetTileIndex(searchRadius, searchRadius);
		local tileList = AITileList();
		tileList.AddRectangle(this.tile - offset, this.tile + offset);
		tileList.Valuate(function(tile, id) {
			return AITown.IsWithinTownInfluence(id, tile);
		}, this.id);
		tileList.KeepValue(1);
		tileList.Valuate(function(tile, cargo) {
			return AITile.GetCargoAcceptance(tile, cargo, 1, 1, 0);
		}, cargo);
		
		return ListSum(tileList) > 0;
	}
	
	// Otherwise check the list of cargos for the appropriate industry type
	local indType = AIIndustry.GetIndustryType(this.id);
	if(!AIIndustryType.IsValidIndustryType(indType)) return false;
	return AIIndustryType.GetAcceptedCargo(indType).HasItem(cargo);
}

/*
 * Get the name of the underlying target from the API.
 */
function Target::GetName() {
	local name = "Unknown";

	if(!this.IsValid()) return name;
	
	if(type == Target.TYPE_TOWN) {
		name = AITown.GetName(this.id);
	} else if(type == Target.TYPE_INDUSTRY) {
		name = AIIndustry.GetName(this.id);
	}
	
	return name;
}

/*
 * Get a unique key for this instance.
 */
function Target::_hashkey() {
	return this.GetLocation();
}

/*
 * Saves data to a table.
 */
function Target::Serialize() {
	local data = {};

	data[SRLZ_TYPE] <- this.type;
	data[SRLZ_ID] <- this.id;
	data[SRLZ_TILE] <- this.tile;
	
	return data;
}

/*
 * Loads data from a table.
 */
function Target::Unserialize(data) {
	this.type = data[SRLZ_TYPE];
	this.id = data[SRLZ_ID];
	this.tile = data[SRLZ_TILE];
}

/*
 * A static method to be used to sort Targets by their profit making potential.
 */
function Target::SortByPotential(homeTown, cargo) {
	return function (a,b):(homeTown, cargo) {
		local aval = 0;
		local bval = 0;
		
		if(a.type == b.type) {
			if(a.type == ::Target.TYPE_TOWN) {
				aval = (a.id == homeTown) ? 1000000 : ::AITown.GetPopulation.call(a, a.id);
				bval = (b.id == homeTown) ? 1000000 : ::AITown.GetPopulation.call(b, b.id);
			} else {
				aval = ::AIIndustry.GetLastMonthProduction.call(a, a.id, cargo);
				bval = ::AIIndustry.GetLastMonthProduction.call(b, b.id, cargo);
			}
		} else {
			// TODO - Heterogenous services
		}
		
		if(aval < bval) return 1;
		else if(aval > bval) return -1;
		return 0;
	}
}
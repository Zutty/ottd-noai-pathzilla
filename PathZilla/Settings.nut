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
 * Settings.nut
 * 
 * Handles all settings.
 * 
 * Author:  George Weller (Zutty)
 * Created: 05/04/2009
 * Version: 1.0
 */

class Settings {
}

/*
 * Get the level of latency.
 */
function Settings::GetLatency() {
	return (5 - PathZilla.GetSetting("latency"));
}

/*
 * Get whether or not the AI should play aggressively.
 */
function Settings::IsAggressive() {
	return (PathZilla.GetSetting("aggressive") == 1);
}

/*
 * Get whether industrial cargo should be routed through towns.
 */
function Settings::RouteCargoThroughTowns() {
	return (PathZilla.GetSetting("rt_cargo_towns") == 1);
}


/*
 * Get whether industrial cargo should be routed through towns.
 */
function Settings::EnableCountryLanes() {
	return (PathZilla.GetSetting("country_lanes") == 1);
}
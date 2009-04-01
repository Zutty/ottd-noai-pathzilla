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
 * info.nut
 * 
 * The basic descriptor for the PathZilla AI.
 * 
 * Author:  George Weller (Zutty)
 * Created: 27/05/2008
 * Version: 1.1
 */

class PathZilla extends AIInfo {
	function GetAuthor()      { return "George Weller"; }
	function GetName()        { return "PathZilla"; }
	function GetDescription() { return "A networking AI. The focus of this AI is on high level planning and neat, realistic construction. Supports buses/trams and mail trucks only."; }
	function GetVersion()     { return 5; }
	function GetDate()        { return "2009-01-24"; }
	function CreateInstance() { return "PathZilla"; }
	function GetShortName()   { return "PZLA"; }
	function GetSettings() {
		AddSetting({name = "latency", description = "Planning Speed - Lower value makes AI faster", min_value = 0, max_value = 5, easy_value = 4, medium_value = 2, hard_value = 0, custom_value = 1, flags = 0});
		AddSetting({name = "aggressive", description = "Aggressive - Value 1 makes AI build near competitor's stations", min_value = 0, max_value = 1, easy_value = 0, medium_value = 0, hard_value = 1, custom_value = 1, flags = 0});
		AddSetting({name = "traffic", description = "Traffic level - Higher value makes AI build more road vehicles", min_value = 1, max_value = 4, easy_value = 1, medium_value = 2, hard_value = 3, custom_value = 3, flags = 0});
		AddSetting({name = "rt_cargo_towns", description = "Route all cargo through towns", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
	}
	function CanLoadFromVersion(version) {
		return (version == 5);
	}
}

RegisterAI(PathZilla());
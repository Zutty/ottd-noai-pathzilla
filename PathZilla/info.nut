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
 * Version: 1.0
 */

class PathZilla extends AIInfo {
	function GetAuthor()      { return "Zutty"; }
	function GetName()        { return "PathZilla"; }
	function GetDescription() { return "A very basic road building AI"; }
	function GetVersion()     { return 1; }
	function GetDate()        { return "2008-07-27"; }
	function CreateInstance() { return "PathZilla"; }
}

RegisterAI(PathZilla());
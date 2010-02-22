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
 * English.nut
 * 
 * A naming scheme to generate generic English-language names.
 * 
 * Author:  George Weller (Zutty)
 * Created: 22/02/2010
 * Version: 1.0
 */
 
class English extends AbstractEnglish {
	constructor() {
		::AbstractEnglish.constructor();
		this.patterns = [
			// President name based
			Pattern("%PRES_SURNAME ?Transport ?Inc", Pattern.COND_ALWAYS), 
			Pattern("%PRES_ACRONYM ?Transport ?Inc", Pattern.COND_THREE_INITIALS),
			Pattern("%PRES_ACRONYM Transport ?Inc", Pattern.COND_ALWAYS),
			Pattern("%HOME_NAME_SHORT %PRES_SURNAME ?Inc", Pattern.COND_SHORT_NAME),
			Pattern("%PRES_NAME and Associates", Pattern.COND_ALWAYS), 
			Pattern("%PRES_SURNAME and Associates ?Inc", Pattern.COND_ALWAYS),
		];
		this.synsets = {
			Transport = ["Travel", "Distribution", "Logistics", "Express", "Connect", "International"]
		};
	}
}
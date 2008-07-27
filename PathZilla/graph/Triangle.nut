/*
 *	Copyright © 2008 George Weller
 *	Some code adapted from C++ example Copyright © 2005, Sjaak Priester, Amsterdam.
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
 * Triangle.nut
 * 
 * A triangle in a graph, made up of three vertices.
 * 
 * Author:  George Weller (Zutty)
 * Created: 03/06/2008
 * Version: 1.1
 */

class Triangle {
	a = null;
	b = null;
	c = null;
	u = null;
	r = 0;
	
	constructor(a, b, c) {
		this.a = a;
		this.b = b;
		this.c = c;
		
		this.GetCircumCircle();
	}
}

/*
 * Get the triangle's circumscribed circle. This is defined by the unique 
 * circle that fits on all three vertices of the triangle.
 *
 * To account for the limitations in integer mathematics, some calculations 
 * include a large multiplication factor to prevent underruns.
 *
 * Adapted from C++ example Copyright © 2005, Sjaak Priester, Amsterdam.
 */
function Triangle::GetCircumCircle() {
	//AILog.Info("      Scribing circle ("+this.a+", "+this.b+", "+this.c+")");
	
	local aX = this.a.x;
	local aY = this.a.y;

	local bX = this.b.x;
	local bY = this.b.y;

	local cX = this.c.x;
	local cY = this.c.y;

	local abY = bY - aY;
	local cbY = cY - bY;
	
	local uX = 0;
	local uY = 0;

	if (abY == 0) {
		if (cbY == 0) { // All three vertices are on one horizontal line.
			//AILog.Info("      Block 1...");
			if (bX > aX) {
				if (cX > bX) bX = cX;
			} else {
				if (cX < aX) aX = cX;
			}
			uX = (aX + bX) / 2;
			uY = aY;
		} else { // A and B are on one horizontal line.
			//AILog.Info("      Block 2...");
			local factor = 100;

			local m1 = - ((cX - bX)*factor / cbY);

			local mx1 = (bX + cX) / 2;
			local my1 = (bY + cY) / 2;

			uX = (aX + bX) / 2;
			uY = (m1 * (uX - mx1))/factor + my1;
		}
	} else if (cbY == 0) { // B and C are on one horizontal line.
		//AILog.Info("      Block 3...");
		local factor = 100;

		local m0 = - ((bX - aX)*factor / abY);

		local mx0 = (aX + bX) / 2;
		local my0 = (aY + bY) / 2;

		uX = (bX + cX) / 2;
		uY = (m0 * (uX - mx0))/factor + my0;
	} else { // 'Common' cases, no multiple vertices are on one horizontal line.
		//AILog.Info("      Block 4...");
		local factor = 100;
		
		local m0 = -((bX - aX)*factor / abY);
		local m1 = -((cX - bX)*factor / cbY);

		local mx0 = (aX + bX)*factor / 2;
		local my0 = (aY + bY)*factor / 2;

		local mx1 = (bX + cX)*factor / 2;
		local my1 = (bY + cY)*factor / 2;

		local denom = (m0 - m1);
		denom = (denom == 0) ? 1 : denom;
		uX = ((m0 * mx0/factor) - (m1 * mx1/factor) + my1 - my0) / denom; // Possible divide by zero
		//uY = m0 * (uX - mx0) + my0;
		uY = (m0 * uX - (m0 * mx0/factor) + my0) / factor;
	}
	
	this.u = Vertex(uX, uY);

	local dx = aX - uX;
	local dy = aY - uY;

	this.r = sqrt(dx * dx + dy * dy); // the radius of the circumcircle
}
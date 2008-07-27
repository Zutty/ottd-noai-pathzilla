PathZilla - © George Weller 2008
================================
Version 1, 27/07/2008 - tested against r13837-noai


PathZilla is a road networking AI. The focus of this AI is on high level 
planning and neat road construction.


Features
--------
Network planning using Delaunay triangles
Custom A* pathfinder builds bridges and tunnels
Builds multiple bus stops per town
Supports NewGRF vehicles (tested with Zephyris' GRVTS v1.3 and George's Long Vehicles v4)
Manages loan repayments and estimates construction costs
Supports passengers only

To Do
-----
Support for other cargo types and industries
Expand and upgrade busy stations
Maintain fleet sizes (# of vehicles) for existing services
Upgrade and replace old vehicles
Better end-game handling (e.g. don't burn through 500 vehicles within 5 years)
Support settings and save/load
Better handling of construction errors and race conditions
Handle poor company rating gracefully
Better loan management for expensive construction
Build bridges over rail, canals, rivers, dips in terrain, etc...
Improve efficiency and code re-use

Wish List
---------
On the fly terraforming 
Build 2-lane highways (once one-way road support is introduced)
Re-model poorly laid out towns
Build prettier and more realistic roads

Known Issues
------------
Bug in pathfinder sometimes causes roads not to be connected


If you have any questions or comments you can find me on tt-forums.net or you
can email me at george.weller@gmail.com
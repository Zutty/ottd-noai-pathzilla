PathZilla - © George Weller 2008
================================
Version 3 (r60), 16/08/2008 - tested against r14025-noai


PathZilla is a road networking AI. The focus of this AI is on high level 
planning and neat road construction.


Features
--------
	* Network planning using graph theory
	* Uses two tiers of pathfinding to improve road re-use
	* Custom A* pathfinder builds bridges and tunnels
	* Builds multiple bus stops per town
	* Supports NewGRF vehicles (tested with Zephyris' GRVTS v1.3 and George's 
	  Long Vehicles v4)
	* Manages loan repayments and estimates construction costs
	* Supports save/load and difficulty settings
	* Supports passengers only

Changelog
---------
v3 - 16/08/2008
	* Added save/load support
	* Introduced size limit for service planning data sets, to reduce memory 
	  usage and save file size
	* Added support for AI difficulty settings, which scale work intervals and
	  aggression
	* Added a 'aggressive' setting. When PathZilla is not aggressive it will 
	  try to avoid building stations near to competitors
	* Fixed bug: Do not try to implement any more services when the vehicle 
	  limit has been reached
v2 - 11/08/2008
	* Vastly improved performance by optimising graph algorithms
	* Introduced limit on number of targets (towns) that will be included in  
	  the master graph, to make very large maps (2048x2048) playable
	* Changed service selection routine to process one town at a time, further
	  improving performance
	* No longer allow use of articulated vehicles (temporary fix)
	* Fixed bug: Do not try to build bus stops adjacent to competitor's  
	  stations or on their property
	* Fixed bug: Do not try to build any bus stops if the local authority 
	  rating is too low
	* Fixed bug: Added check to ensure that the entrance road to a depot has 
	  been built
	* Fixed various other bugs
	* Changed license to GPL v2
v1.1 - 29/07/2008
	* Changed require() statements to use cross-platform slashes
	* Reduced work intervals to make AI more aggressive

Known Issues
------------
	* Bug in pathfinder sometimes causes roads not to be connected
	* Has a tendency to "wipe-out" towns when the game runs multiple instances
	  of PathZilla, if 'aggressive' is set on
	* Does not include airports in competitor check for aggression setting 

To Do
-----
	* Add proper support for DTRSs and ARVs
	* Support for other cargo types and industries
	* Add support for ECS Vectors and PBI (not tested)
	* Add support for tram lines 
	* Expand and upgrade busy stations
	* Maintain fleet sizes (# of vehicles) for existing services
	* Upgrade and replace old vehicles
	* Better end-game handling (e.g. don't burn through 500 vehicles within 5 years)
	* Better handling of construction errors and race conditions
	* Better loan management for expensive construction
	* Build bridges over rail, canals, rivers, dips in terrain, etc...
	* Improve code re-use

Wish List
---------
	* On the fly terraforming 
	* Build 2-lane highways (once one-way road support is introduced)
	* Re-model poorly laid out towns
	* Build prettier and more realistic roads

If you have any questions or comments you can email me at 
george.weller@gmail.com or visit one of the following pages...

TT-Forums Thread - http://www.tt-forums.net/viewtopic.php?f=65&t=38645
Google Code Site - http://code.google.com/p/ottd-noai-pathzilla/
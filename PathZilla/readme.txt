PathZilla - © George Weller 2009
================================
Version 5 (r154), 24/01/2009 - tested against r15235


PathZilla is a networking AI. The focus of this AI is on high level planning 
and neat, realistic construction.

To get the best results from PathZilla you are *strongly* advised to activate 
the advanced setting "Stations" > "Allow drive-through road stops on town owned
 roads". PathZilla will still function correctly but will need to perform more 
 demolition in towns.


Features
--------
	* High-level network planning using graph theory
	* Uses two tiers of pathfinding to improve line re-use
	* Aesthetic pathfinding builds tram lines alongside roads and honours town 
	  grid layouts where applicable
	* Full support for articulated vehicles and trams, where available
	* Builds "green belt" around towns to improve local authority rating
	* Supports NewGRF vehicles (tested with Zephyris' eGRVTS, George's Long 
	  Vehicles v4, and PikkaBird's HOVS)
	* Builds multiple road stations per town and maintains fleet sizes
	* Supports save/load and difficulty settings
	* Supports passengers and mail

Changelog
---------
v5 - 24/01/2009
	* Changed to library pathfinder (with modifications)
	* Updated to latest API changes
	* Build depots in towns rather than in the middle of roads
	* Split different road types where possible to reduce congestion
	* Honour 2x2/3x3 town grid layouts where possible
	* Re-wrote station placement to be more flexible
	* Maintain fleet sizes based on waiting cargo
	* Enable bribing of town authority
	* Build trees around a town to improve local authority rating
	* Re-attempt pathfinding if construction fails
	* Don't build tunnels if funds are too low
	* Fixed bug: First order was not updated
	* Fixed bug: Don't try to compute shortest paths if there are less than two nodes
	* Fixed bug: Crash when adding vehicles to service after load
v4 - 01/10/2008
	* Improved DTRS support and enabled ARVs where possible
	* Added support for trams
	* Added generic cargo support for towns only (i.e. mail)
	* Improved vehicle selection criteria. Gives more variety with large sets 
	  like eGRVTS
	* Changed fleet size and property management to improve profitability at 
	  early dates (pre-1950)
	* Efficiency improvements on busy maps
	* Fixed bug: Only connect to an existing road when pathfinding if a 
	  connection can be made to its neighbours
	* Fixed bug: Roads can now cross without joining
	* Fixed bug: Calculate combined station coverage over a single town 
	  correctly
	* Fixed bug: Don't crash if there are fewer than three towns
	* Fixed other, minor bugs
v3 - 16/08/2008
	* Added save/load support
	* Introduced size limit for service planning data sets, to reduce memory 
	  usage and save file size
	* Added support for AI difficulty settings, which scale work intervals and
	  aggression
	* Added an 'aggressive' setting. When PathZilla is not aggressive it will 
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
	* Has a tendency to "wipe-out" towns when the game runs multiple instances
	  of PathZilla, if 'aggressive' is set on
	* Does not include airports in competitor check for aggression setting 

To Do
-----
	* Support for other industries
	* Add support for ECS Vectors and PBI (not tested)
	* Expand and upgrade busy stations
	* Upgrade and replace old vehicles

Wish List
---------
	* Rail, aircraft, and ship support
	* On the fly terraforming 
	* Build 2-lane highways (once one-way road support is introduced)
	* Re-model poorly laid out towns

If you have any questions or comments you can email me at 
george.weller@gmail.com or visit one of the following pages...

TT-Forums Thread - http://www.tt-forums.net/viewtopic.php?f=65&t=38645
Google Code Site - http://code.google.com/p/ottd-noai-pathzilla/
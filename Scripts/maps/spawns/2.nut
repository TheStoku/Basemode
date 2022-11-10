class ::CSpawnData
{
	Name = "Docks";
	Author = "Stoku & Xenon";	
	Spawn = ::Vector( 1296.79, -991.055, 14.8785 );
	Spawn_Angle = 245.0;

	function CreateVehicles()
	{
		// Coach
		::CreateVehicle( 127, Vector( 1291.5, -972.3, 14.97 ), 227.057, 5, 6 );
		
		// Banshee
		::CreateVehicle( 119, Vector( 1290.62, -976.813, 14.879 ), 227.307, -1, -1 );
		::CreateVehicle( 119, Vector( 1282.6, -969.4, 14.47 ), 227.307, -1, -1 );
		
		// infernus
		::CreateVehicle( 101, Vector( 1286.87, -980.74, 14.8762 ), 227.307, -1, -1 );
		::CreateVehicle( 101, Vector( 1278.7, -973.3, 14.53 ), 227.307, -1, -1 );
		
		// Cheetah
		::CreateVehicle( 105, Vector( 1283.25, -983.94, 14.8751 ), 227.307, -1, -1 );
		::CreateVehicle( 105, Vector( 1275.4, -976.9, 14.5 ), 227.307, -1, -1 );
		
		// Sentinel XS / Mafia
		::CreateVehicle( 134, Vector( 1279.61, -987.475, 14.8741 ), 227.307, -1, -1 );
		::CreateVehicle( 134, Vector( 1272, -980.4, 14.69 ), 227.307, -1, -1 );

		// Dodo
		::CreateVehicle( 126, Vector( 1314.49, -986.137, 14.8833 ), 185.381, -1, -1 );
		::CreateVehicle( 126, Vector( 1308.08, -978.316, 14.8818 ), 186.76, -1, -1 );

		// Rumpo
		::CreateVehicle( 139, Vector( 1286.61, -999.15, 14.8777 ), 315.769, -1, -1 );

		return 1;
	}
}
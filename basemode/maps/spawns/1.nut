class ::CSpawnData
{
	Name = "Callahan Bridge";
	Author = "Stoku";	
	Spawn = ::Vector( 152.04, -946.30, 26.01 );
	Spawn_Angle = 270.29;

	function CreateVehicles()
	{
		// Stretch
		::CreateVehicle( 99, Vector( 103.05, -947.0, 26.16 ), 270.0, 0, 0 );
		::CreateVehicle( 99, Vector( 88.82, -947.0, 26.16 ), 270.0, 1, 1 );
		
		// Securicar
		::CreateVehicle( 118, Vector( 192.31, -976.90, 26.16 ), 1.58336, -1, -1 );
		
		// Coach
		::CreateVehicle( 127, Vector( 125.74, -1001.20, 26.16 ), 270.0, 5, 6 );

		// Parking
		::CreateVehicle( 119, Vector( 175.0, -955.60, 26.21 ), 0.0, 0, 1 );
		::CreateVehicle( 105, Vector( 170.0, -955.60, 26.21 ), 0.0, 0, 0 );
		::CreateVehicle( 105, Vector( 165.0, -955.60, 26.21 ), 0.0, 7, 7 );
		::CreateVehicle( 119, Vector( 160.0, -955.60, 26.21 ), 0.0, 7, 1 );
		
		::CreateVehicle( 139, Vector( 201.68, -996.20, 26.09 ), 90.8183, -1, -1 );
	
		// Dodo
		::CreateVehicle( 126, Vector( 146.79, -932.00, 26.17 ), 180.312, -1, -1 );
		
		return 1;
	}
}
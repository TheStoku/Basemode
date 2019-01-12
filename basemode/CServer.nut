Players <- {};
TeamMembers <- {};
SpawnState <- {};

g_Blip <- CreateBlip( BLIP_NONE, Vector( -1009.0, -164.0, 34.5 ));
g_Blip.Colour = 2;

g_Marker <- CreateSphere( Vector( -1009.0, -164.0, 34.5 ), 1.0 );
g_Marker.Type = MARKER_TYPE_PLAYER ;

local lobby_red = Vector( 165.10, -1003.50, 29.53 );
local lobby_red_angle = 270.0;

local lobby_blue =  Vector( 165.74, -990.81, 29.53 );
local lobby_blue_angle = 176.229;

g_iDefendingTeam <- 0;

class CSettings
{
	VoteTime = 15;		// seconds
	//CountdownTime = 5;
	
	ColtAmmo = 12*8;
	UZIAmmo = 25*6;
	ShotgunAmmo = 25;
	AKAmmo = 30*9;
	M16Ammo = 60*4;
	RifleAmmo = 25;
	MolotovAmmo = 2;
	GrenadeAmmo = 2;
	
	TEAM1_HEX_COLOR = "[#ff0000]";	// red
	TEAM2_HEX_COLOR = "[#0000ff]";	// blue
	SPECT_HEX_COLOR = "[#ffff00]";	// yellow
	
	function GetAmmoFromWeaponID( iWeaponID )
	{
		switch ( iWeaponID )
		{
			// Colt45
			case 2:
				return ColtAmmo;
			// UZI
			case 3:
				return UZIAmmo;
			// Shotgun
			case 4:
				return ShotgunAmmo;
			// AK47
			case 5:
				return AKAmmo;
			// M16
			case 6:
				return M16Ammo;
			// Rifle
			case 7:
				return RifleAmmo;
			// Molotov
			case 10:
				return MolotovAmmo;
			// Grenade
			case 11:
				return GrenadeAmmo;
		}
	}
	
	function GetWeaponNameFromID( iWeaponID )
	{
		switch ( iWeaponID )
		{
			case 0:
				return "Fist";
			case 1:
				return "Baseball Bat";
			case 2:
				return "Colt";
			case 3:
				return "UZI";
			case 4:
				return "Shotgun";
			case 5:
				return "AK47";
			case 6:
				return "M16";
			case 7:
				return "Sniper Rifle";
			case 8:
				return "Rocket Launcher";
			case 9:
				return "Flamethrower";
			case 10:
				return "Molotov";
			case 11:
				return "Grenade";
			case 12:
				return "Detonator";
		}
	}
	
	function GetTeamColor( iTeamID )
	{
		if ( iTeamID == 0 ) return TEAM1_HEX_COLOR;
		else if ( iTeamID == 1 )  return TEAM2_HEX_COLOR;
		else if ( iTeamID == 2 )  return SPECT_HEX_COLOR;
	}
	
	function UpdateClientSettings( pPlayer )
	{
		CLIENT_UpdateTeamNames( pPlayer );
		CLIENT_UpdateScores( pPlayer, false );
		CLIENT_UpdateSettings( pPlayer );
	}
}

class CVoteManager
{
	IsVotingInProgress = false;
	CurrentVoteTime = 0;
	Base = 0;
	Yes = 0;
	No = 0;
	
	function VoteStart( pPlayer, iBaseID )
	{
		if ( IsVotingInProgress ) Message( "[#00FF00]*** The previous vote isn't finished" );
		else if ( !iBaseID ) Message( "[#ff0000][Syntax] [#ffffff]/votebase <id>" );
		else
		{
			Message( "[#00FF00]*** Vote started by " + pPlayer.Name + " base " + iBaseID );
			
			Yes = 0;
			No = 0;
			Base = iBaseID;
			CurrentVoteTime = pSettings.VoteTime;
			
			foreach( iPlayerID in Players )
			{
				local pPlayer = FindPlayer( iPlayerID );

				if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "StartVote", iBaseID, pSettings.VoteTime );
			}
			
			// set timer
			g_Timer.Start();
			IsVotingInProgress = true;
		}
	}
	function VoteEnd()
	{
		g_Timer.Stop();
		IsVotingInProgress = false;

		if ( Yes > No )
		{
			Message( "*** Voting finished! (Yes: " + Yes + "/No: " + No + ")" );
			if (( pPlayerManager.GetTeamPlayersCount( 0 ) == 0 ) || ( pPlayerManager.GetTeamPlayersCount( 1 ) == 0 ))
			{
				Message( "*** But not enough players :(" );
				
				foreach( iPlayerID in Players )
				{
					local pPlayer = FindPlayer( iPlayerID );

					if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "EndVote" );
				}
			}
			else pGame.Start( "base", Base );
		}
		else
		{
			Message( "*** Vote failed (Not enough votes)" );
			IsVotingInProgress = false;
			
			foreach( iPlayerID in Players )
			{
				local pPlayer = FindPlayer( iPlayerID );

				if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "EndVote" );
			}
		}
	}
	function Vote( pPlayer, bBoolean )
	{
		if ( bBoolean ) Yes++;
		else No++;
	}
	function UpdateVotes()
	{
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateVotes", Base, CurrentVoteTime, Yes, No );
		}
	}
}

class CPlayerManager
{
	RedMembers = 0;
	BlueMembers = 0;
	RedPlayers = 0;
	BluePlayers = 0;
	SpawnedRedPlayers = 0;
	SpawnedBluePlayers = 0;
	Team1Score = 0;
	Team2Score = 0;
	Team1Name = "RED";
	Team2Name = "BLUE";
	
	function Add( pPlayer )
	{
		if ( !Players.rawin( pPlayer.Name ) ) Players.rawset( pPlayer.Name, pPlayer.ID );
	}
	function AddToRound( pPlayer )
	{
		pPlayerManager.SetTeam( pPlayer );
		pPlayerManager.Add( pPlayer );
		
		pPlayer.Immune = false;
		//pPlayer.Marker = false;
		pPlayer.Health = 100;
		
		pSettings.UpdateClientSettings( pPlayer );
		
		CallClientFunc( pPlayer, "basemode/client.nut", "onBaseStart", pBase.RoundTime, g_Marker.ID );
			
		if ( !pGame.IsArena )
		{
			if ( pPlayer.Team == g_iDefendingTeam )
			{
				pPlayer.Pos = Vector( pBase.Spawn_X, pBase.Spawn_Y, pBase.Spawn_Z );
				pPlayer.Angle = pBase.Spawn_Angle;
			}
			else
			{
				pPlayer.Pos = Vector( pSpawn.Spawn_X, pSpawn.Spawn_Y, pSpawn.Spawn_Z );
				pPlayer.Angle = pSpawn.Spawn_Angle;
			}
		}
		else
		{
			if ( pPlayer.Team == g_iDefendingTeam )
			{
				pPlayer.Pos = Vector( pArena.Red_Spawn_X, pArena.Red_Spawn_Y, pArena.Red_Spawn_Z );
				pPlayer.Angle = pArena.Red_Spawn_Angle;
			}
			else
			{
				pPlayer.Pos = Vector( pArena.Blue_Spawn_X, pArena.Blue_Spawn_Y, pArena.Blue_Spawn_Z );
				pPlayer.Angle = pArena.Blue_Spawn_Angle;
			}
		}
			
		pPlayerManager.CountMembers();
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer )
			{
				CLIENT_UpdateTeamNames( pPlayer );				
			}
		}
	}
	function DeleteFromRound( pPlayer )
	{
		if ( pPlayer )
		{
			if ( pPlayer.Spawned )
			{
				if ( pPlayer.Vehicle ) pPlayer.RemoveFromVehicle();			
				pPlayer.ClearWeapons();
				pPlayer.Immune = true;
				pPlayer.Health = 100;
				pPlayer.Frozen = false;
				//pPlayer.RestoreCamera();
				
				if ( pPlayer.Team == 0 )
				{
					pPlayer.Pos = lobby_red;
					pPlayer.Angle = lobby_red_angle;
				}
				else if ( pPlayer.Team == 1 )
				{
					pPlayer.Pos = lobby_blue;
					pPlayer.Angle = lobby_blue_angle;
				}
				else
				{
					pPlayer.Pos = lobby_spectator;
					pPlayer.Angle = lobby_spectator_angle;
				}
			
				pPlayerManager.DeleteTeam( pPlayer );
			}
			
			CallClientFunc( pPlayer, "basemode/client.nut", "onBaseEnd", pPlayerManager.Team1Score, pPlayerManager.Team2Score );
		}
	}
	function Login( pPlayer, iLevel )
	{
		if ( !pPlayer ) return 0;
	
		if ( !iLevel )
		{
			adminList.rawdelete( pPlayer.Name );
		}
		else
		{
			adminList.rawset( pPlayer.Name, pPlayer.ID );
		}

		// Store admins LUID, IP, etc, INI DOESNT WORK ANYMORE
		//WriteIniString( "Scripts/basemode/admins.ini", pPlayer.LUID, "Name", pPlayer.Name );
		//WriteIniString( "Scripts/basemode/admins.ini", pPlayer.LUID, "IP", pPlayer.IP );
		//WriteIniInteger( "Scripts/basemode/admins.ini", pPlayer.LUID, "Level", iLevel );
	}
	function IsLoggedIn( pPlayer )
	{
		if ( !pPlayer ) return 0;
		if ( !adminList.rawin( pPlayer.Name ) ) return 0;
		else return 1;
	}
	function Delete( pPlayer )
	{
		Players.rawdelete( pPlayer.Name );
	}
	function GetTeamFullName( iTeamID )
	{
		if ( iTeamID == 0 )
		{
			if ( g_iDefendingTeam == 0 ) return "Defence | " + Team1Name;
			else return "Attack | " + Team1Name;
		}
		else if ( iTeamID == 1 )
		{
			if ( g_iDefendingTeam == 1 ) return "Defence | " + Team2Name;
			else return "Attack | " + Team2Name;
		}
		else return "Spectator";
	}
	function GetTeamName( iTeamID )
	{
		if ( iTeamID == 0 ) return Team1Name;
		else if ( iTeamID == 1 ) return Team2Name;
		else return "Spectator";
	}
	function SetTeamName( iTeamID, szName )
	{
		if ( szName )
		{
			if ( iTeamID == 1 ) pPlayerManager.Team1Name = szName;
			else pPlayerManager.Team2Name = szName;
			
			foreach( iPlayerID in Players )
			{
				local pPlayer = FindPlayer( iPlayerID );

				if ( pPlayer ) CLIENT_UpdateTeamNames( pPlayer );
			}
		}
	}
	function SetTeam( pPlayer )
	{
		TeamMembers.rawset( pPlayer.Name, pPlayer.Team );
	}
	function DeleteTeam( pPlayer )
	{
		if ( pGame.Taker == pPlayer.Name )
		{
			pGame.Taker = null;
			g_CaptureTimer.Stop();
		}
		
		if ( pPlayerManager.GetTeam( pPlayer ) == 0 ) RedMembers--;
		else if ( pPlayerManager.GetTeam( pPlayer ) == 1 ) BlueMembers--;
		
		TeamMembers.rawdelete( pPlayer.Name );
	}
	function GetTeam( pPlayer )
	{
		if ( TeamMembers.rawin( pPlayer.Name ) ) return TeamMembers.rawget( pPlayer.Name );
		else return 3;
	}
	function SwitchTeams()
	{
		// if pGame.Started
		if ( g_iDefendingTeam == 0 ) g_iDefendingTeam = 1;
		else g_iDefendingTeam = 0;
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer ) CLIENT_UpdateTeamNames( pPlayer );
		}
	}
	function CountMembers()
	{
		RedMembers = 0;
		BlueMembers = 0;
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer )
			{
				if ( pPlayerManager.GetTeam( pPlayer ) == 0 ) RedMembers++;
				else if ( pPlayerManager.GetTeam( pPlayer ) == 1 ) BlueMembers++;
			}
		}
		return 1;
	}
	function CountPlayers()
	{
		RedPlayers = 0;
		BluePlayers = 0;
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer )
			{
				if ( pPlayer.Team == 0 ) RedPlayers++;
				else if ( pPlayer.Team == 1 ) BluePlayers++;
			}
		}
		return 1;
	}
	function GetTeamPlayersCount( iTeamID )
	{
		if ( iTeamID == 0 ) return RedPlayers;
		else if ( iTeamID == 1 ) return BluePlayers;
		else return 0;
	}
	function GetTeamMembersCount( iTeamID )
	{
		if ( iTeamID == 0 ) return RedMembers;
		else if ( iTeamID == 1 ) return BlueMembers;
		else return 0;
	}
	function CountSpawnedPlayers()
	{
		SpawnedRedPlayers = 0;
		SpawnedBluePlayers = 0;
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer )
			{
				if (( pPlayer.Team == 0 ) && ( pPlayer.Spawned )) SpawnedRedPlayers++;
				else if (( pPlayer.Team == 1 ) && ( pPlayer.Spawned )) SpawnedBluePlayers++;
			}
		}
		return 1;
	}
	function GetSpawnedPlayersCount( iTeamID )
	{
		pPlayerManager.CountSpawnedPlayers();
		
		if ( iTeamID == 0 ) return SpawnedRedPlayers;
		else if ( iTeamID == 1 ) return SpawnedBluePlayers;
		else return 0;
	}
	function CheckWinner()
	{
		if ( !pGame.IsRoundInProgress ) return 0;
		
		if (( RedMembers == 0 ) && ( BlueMembers == 0 ))
		{
			pGame.End();
			Message( "[#00FF00]*** This round was a draw!" );
			//BigMessage( "This round was a draw!", 5000, 1 );
		}
		else if (( RedMembers == 0 ) || ( BlueMembers == 0 ))
		{			
			if ( RedMembers == 0 )
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (killed all enemies)" );
				//BigMessage( "~r~" + pPlayerManager.Team2Name + " team wins!", 5000, 1 );
				Team2Score++;
			}
			else
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (killed all enemies)" );
				//BigMessage( "~b~" + pPlayerManager.Team1Name + " team wins!", 5000, 1 );
				Team1Score++;
			}
			
			pGame.End();
		}
		else if ( pBase.RoundTime == 0 )
		{
			if ( pGame.IsArena ) Message( "[#00FF00]*** This round was a draw! (timeout)" );
			else if ( g_iDefendingTeam == 1 )
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (timeout)" );
				//BigMessage( "~r~" + pPlayerManager.Team2Name + " team wins!", 5000, 1 );
				Team2Score++;
			}
			else
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (timeout)" );
				//BigMessage( "~b~" + pPlayerManager.Team1Name + " team wins!", 5000, 1 );
				Team1Score++;
			}
			
			pGame.End();
		}
		else if ( pGame.CaptureTime == 15 )
		{			
			if ( g_iDefendingTeam == 1 )
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (captured the base)" );
				//BigMessage( "~b~" + pPlayerManager.Team1Name + " team wins!", 5000, 1 );
				Team1Score++;
			}
			else
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (captured the base)" );
				//BigMessage( "~r~" + pPlayerManager.Team2Name + " team wins!", 5000, 1 );
				Team2Score++;
			}
			
			pGame.End();
		}
		
		return 1;
	}
}

class CBase
{
	Name = null;
	Author = null;
	RoundTime = null;
	SpawnID = null;
	Weather = null;
	Hour = null;
	
	Spawn_X = 0.0;
	Spawn_Y = 0.0;
	Spawn_Z = 0.0;
	Spawn_Angle = 0.0;
	
	Marker_X = 0.0;
	Marker_Y = 0.0;
	Marker_Z = 0.0;
	
	function LoadData( iBaseID )
	{
		try
		{
			dofile( SCRIPT_DIR + "maps/bases/" + iBaseID + ".nut" );
		}
		catch( error )
		{
			::Message( "[#ff0000][Error] [#ffffff]This base does not exist: " + iBaseID );
			print( error );
			return 0;
		}

		::pBaseData <- CBaseData();
		
		Name = ::pBaseData.Name;
		Author = ::pBaseData.Author;
		RoundTime = ::pBaseData.RoundTime * 60 + 6;
		SpawnID = ::pBaseData.SpawnID;
		Weather = ::pBaseData.Weather;
		Hour = ::pBaseData.Hour;
			
		Spawn_X = ::pBaseData.Spawn.x;
		Spawn_Y = ::pBaseData.Spawn.y;
		Spawn_Z = ::pBaseData.Spawn.z;
		Spawn_Angle = ::pBaseData.Spawn_Angle;
		
		Marker_X = ::pBaseData.Marker.x;
		Marker_Y = ::pBaseData.Marker.y;
		Marker_Z = ::pBaseData.Marker.z;
		
		::SetServerRule( "Base", Name );
		
		return 1;
	}
}

class CArena
{
	Distance = 0.0;
	Red_Spawn_X = 0.0;
	Red_Spawn_Y = 0.0;
	Red_Spawn_Z = 0.0;
	Red_Spawn_Angle = 0.0;
	
	Blue_Spawn_X = 0.0;
	Blue_Spawn_Y = 0.0;
	Blue_Spawn_Z = 0.0;
	Blue_Spawn_Angle = 0.0;
	
	function LoadData( iArenaID )
	{	
		try
		{
			dofile( SCRIPT_DIR + "maps/arenas/" + iArenaID + ".nut" );
		}
		catch( error )
		{
			::Message( "[#ff0000][Error] [#ffffff]This arena does not exist: " + iArenaID );
			print( error );
			return 0;
		}

		::pArenaData <- CArenaData();
		
		pBase.Name = ::pArenaData.Name;
		pBase.Author = ::pArenaData.Author;
		pBase.RoundTime = ::pArenaData.RoundTime * 60 + 6;
		pBase.Weather = ::pArenaData.Weather;
		pBase.Hour = ::pArenaData.Hour;
		Distance = ::pArenaData.Distance;
			
		Red_Spawn_X = ::pArenaData.RedSpawn.x;
		Red_Spawn_Y = ::pArenaData.RedSpawn.y;
		Red_Spawn_Z = ::pArenaData.RedSpawn.z;
		Red_Spawn_Angle = ::pArenaData.RedSpawn_Angle;
		
		Blue_Spawn_X = ::pArenaData.BlueSpawn.x;
		Blue_Spawn_Y = ::pArenaData.BlueSpawn.y;
		Blue_Spawn_Z = ::pArenaData.BlueSpawn.z;
		Blue_Spawn_Angle = ::pArenaData.BlueSpawn_Angle;
		
		pBase.Marker_X = ::pArenaData.Marker.x;
		pBase.Marker_Y = ::pArenaData.Marker.y;
		pBase.Marker_Z = ::pArenaData.Marker.z;
		
		if ( GAMEMODE_NAME_INFO ) ::SetGameModeName ( "[Arena: " + pBase.Name + "] " + GAMEMODE_NAME );
		//::SetWorldBounds( Bound_Max_X, Bound_Min_X, Bound_Max_Y, Bound_Min_Y );
		
		return 1;
	}
}

class CSpawn
{
	Name = null;
	Author = null;
	
	Spawn_X = 0.0;
	Spawn_Y = 0.0;
	Spawn_Z = 0.0;
	Spawn_Angle = 0.0;
	
	function LoadData()
	{
		try
		{
			dofile( SCRIPT_DIR + "maps/spawns/" + pBase.SpawnID + ".nut" );
		}
		catch( error )
		{
			::Message( "[#ff0000][Error] [#ffffff]Cannot load spawn data" );
			print( error );
			return 0;
		}

		::pSpawnData <- CSpawnData();
		
		Name = pSpawnData.Name;
		Author = pSpawnData.Author;
			
		Spawn_X = pSpawnData.Spawn.x;
		Spawn_Y = pSpawnData.Spawn.y;
		Spawn_Z = pSpawnData.Spawn.z;
		Spawn_Angle = pSpawnData.Spawn_Angle;
		
		//pSpawnData.CreateVehicles()
		if ( pSpawnData.CreateVehicles() ) pSpawn.PrepareVehicles();
		
		return 1;
	}
	function PrepareVehicles()
	{
		local iVehicleCount = GetVehicleCount();
		
		for( local iVehicleID = 0; iVehicleID < iVehicleCount; iVehicleID++ )
		{
			local pVehicle = ::FindVehicle( iVehicleID );	
			if ( pVehicle )
			{
				pVehicle.RespawnTime = pBase.RoundTime;
				pVehicle.IdleRespawnTime = pBase.RoundTime;
				pVehicle.OneTime = false;
			}
		}
	}
}

class CGameLogic
{
	CaptureTime = 0;
	Taker = null;
	IsRoundInProgress = false;
	IsArena = false;
	
	function Start( szType, iBaseID )
	{
		if ( IsRoundInProgress ) Message( "*** The round is in progress" );
		else
		{
			CleanMap();
		
			if ( szType == "base" )
			{
				if (( pBase.LoadData( iBaseID ) ) && ( pSpawn.LoadData( )))
				{
					Message( "[#00FF00]*** Starting base " + pBase.Name + " - " + ::GetDistrictName( pBase.Marker_X, pBase.Marker_Y ) + " (ID: " + iBaseID + ")" );
									
					IsRoundInProgress = true;
					IsArena = false;
					//pSettings.CountdownTime = 5;
					g_Timer.Start();
					
					g_Blip.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
					g_Marker.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
					SetWeather( pBase.Weather.tointeger() );
					SetTime( pBase.Hour.tointeger(), 00 );
					//SetTimeRate( 0 );
					
					foreach( iPlayerID in Players )
					{
						local pPlayer = FindPlayer( iPlayerID );
						
						if (( pPlayer ) && ( pPlayer.Spawned ) && ( pPlayer.Team <= 1 )) pPlayerManager.AddToRound( pPlayer );
					}
					return 1;
				}
			}
			else if ( szType == "arena" )
			{
				if ( pArena.LoadData( iBaseID )) 
				{
					Message( "[#00FF00]*** Starting arena " + pBase.Name + " - " + ::GetDistrictName( pBase.Marker_X, pBase.Marker_Y ) + " (ID: " + iBaseID + ")" );
					
					IsRoundInProgress = true;
					IsArena = true;
					//pSettings.CountdownTime = 5;
					g_Timer.Start();
					
					g_Blip.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
					g_Marker.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
					
					SetWeather( pBase.Weather.tointeger() );
					SetTime( pBase.Hour.tointeger(), 00 );
					
					foreach( iPlayerID in Players )
					{
						local pPlayer = FindPlayer( iPlayerID );
						
						if (( pPlayer ) && ( pPlayer.Spawned ) && ( pPlayer.Team <= 1 ))
						{
							pPlayerManager.AddToRound( pPlayer );
						}
					}
					return 1;
				}
			}
			else return 0;
		}
	}
	
	function End()
	{
		if ( !IsRoundInProgress ) return 0;
		::SetServerRule( "Base", "Main Lobby" );
		::SetServerRule( "Time left", "0:00" );
		pPlayerManager.SwitchTeams();
		IsRoundInProgress = false;
		IsArena = false;
		Taker = null;
		CaptureTime = 0;
		iRoundStartTime = 20;
		
		if ( ROUNDSTART_TYPE != 0 ) g_Timer.Stop();
		g_CaptureTimer.Stop();
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );
			pPlayerManager.DeleteFromRound( pPlayer );
		}
		
		CleanMap();
		
		return 1;
	}
	function CleanMap()
	{
		local iVehicleCount = GetVehicleCount();
		
		for( local iVehicleID = 0; iVehicleID < iVehicleCount; iVehicleID++ )
		{
			local pVehicle = ::FindVehicle( iVehicleID );	
			if ( pVehicle )	pVehicle.Remove();
		}
	}
}

function CLIENT_UpdateScores( pPlayer, bAll )
{
	if ( bAll )
	{
		foreach( iPlayerID in Players )
		{
			pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateScores", pPlayerManager.Team1Score, pPlayerManager.Team2Score );
		}
	}
	else CallClientFunc( pPlayer, "basemode/client.nut", "UpdateScores", pPlayerManager.Team1Score, pPlayerManager.Team2Score );
}

function CLIENT_UpdateTeamNames( pPlayer )
{
	local szTeam1 = pPlayerManager.GetTeamFullName( 0 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 0 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 0 );
	local szTeam2 = pPlayerManager.GetTeamFullName( 1 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 1 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 1 );
	
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateTeamNames", szTeam1, szTeam2 );
}

function CLIENT_UpdateSpawnSelection( pPlayer, szName )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "SetSpawnClass", szName );
}

function CLIENT_UpdateSettings( pPlayer )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateSettings", ColtAmmo, UZIAmmo, ShotgunAmmo, AKAmmo, M16Ammo, RifleAmmo, MolotovAmmo, GrenadeAmmo, GetMaxPlayers() );
}
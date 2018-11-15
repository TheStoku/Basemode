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
g_iRoundStartType <- 0;		// 0-start random base, 1-vote, 2-admin controlled

class CSettings
{
	VoteTime = 15;		// seconds
	ColtAmmo = 12*8;
	UZIAmmo = 25*6;
	ShotgunAmmo = 25;
	AKAmmo = 30*9;
	M16Ammo = 60*4;
	RifleAmmo = 25;
	MolotovAmmo = 2;
	GrenadeAmmo = 2;
	TEAM1_HEX_COLOR = "[#FF0000]";	// red
	TEAM2_HEX_COLOR = "[#0000FF]";	// blue
	
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
	}
	
	function UpdateClientSettings( pPlayer )
	{
		CLIENT_UpdateTeamNames( pPlayer );
		CLIENT_UpdateScores( pPlayer );
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
			Message( "*** Vote started by " + pPlayer.Name + " for base " + iBaseID );
			
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
			else pGame.Start( Base );
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
		
		pPlayer.Marker = false;
		pSettings.UpdateClientSettings( pPlayer );
	}
	function AddToRound( pPlayer )
	{
		pPlayerManager.SetTeam( pPlayer );
		pPlayerManager.Add( pPlayer );
		pPlayer.Immune = false;
		pPlayer.Health = 100;
		
		pSettings.UpdateClientSettings( pPlayer );
		CallClientFunc( pPlayer, "basemode/client.nut", "onBaseStart", pBase.RoundTime, g_Marker.ID );
			
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
			if ( g_iDefendingTeam == 1 )
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
	
	Spawn_X = null;
	Spawn_Y = null;
	Spawn_Z = null;
	Spawn_Angle = null;
	
	Marker_X = null;
	Marker_Y = null;
	Marker_Z = null;
	
	function LoadData( iBaseID )
	{
		local xmlBase = XmlDocument( "Scripts/basemode/maps/bases/" + iBaseID + ".xml" );
		
		if ( xmlBase.LoadFile() )
		{
			Name = xmlBase.FirstChild( "Name" ).Text;
			Author = xmlBase.FirstChild( "Author" ).Text;
			RoundTime = xmlBase.FirstChild( "RoundTime" ).Text.tointeger() * 60 + 6;
			SpawnID = xmlBase.FirstChild( "Spawn" ).Text;
			Weather = xmlBase.FirstChild( "Weather" ).Text;
			Hour = xmlBase.FirstChild( "Hour" ).Text;
			
			::SetServerRule( "Base", Name );
			
			local rootSpawn = xmlBase.FirstChild( "Spawns" );
			
			if ( rootSpawn )
			{
				local node = rootSpawn.FirstChild( "player" );
				
				Spawn_X = node.GetAttribute( "x" ).tofloat();
				Spawn_Y = node.GetAttribute( "y" ).tofloat();
				Spawn_Z = node.GetAttribute( "z" ).tofloat();
				Spawn_Angle = node.GetAttribute( "angle" ).tofloat();
				
				node = node.NextSibling( "marker" );
				Marker_X = node.GetAttribute( "x" ).tofloat();
				Marker_Y = node.GetAttribute( "y" ).tofloat();
				Marker_Z = node.GetAttribute( "z" ).tofloat();
				
				return 1;
			}
			else
			{
				Message( "[#ff0000][Error] [#ffffff]Cannot load spawn data" );
				print( "[Error] Cannot load spawn data" );
				
				return 0;
			}
		}
		else
		{
			Message( "[#ff0000][Error] [#ffffff]This base does not exist" );
			print( "[Error] This base does not exist" );
			
			return 0;
		}
	}
}

class CSpawn
{
	Name = null;
	Author = null;
	
	Spawn_X = null;
	Spawn_Y = null;
	Spawn_Z = null;
	Spawn_Angle = null;
	
	function LoadData()
	{
		local xmlSpawn = XmlDocument( "Scripts/basemode/maps/spawns/" + pBase.SpawnID + ".xml" );
		
		if ( xmlSpawn.LoadFile() )
		{
			Name = xmlSpawn.FirstChild( "Name" ).Text;
			Author = xmlSpawn.FirstChild( "Author" ).Text;
						
			local rootSpawn = xmlSpawn.FirstChild( "Spawns" );
			
			if ( rootSpawn )
			{
				local node = rootSpawn.FirstChild( "player" );
				
				Spawn_X = node.GetAttribute( "x" ).tofloat();
				Spawn_Y = node.GetAttribute( "y" ).tofloat();
				Spawn_Z = node.GetAttribute( "z" ).tofloat();
				Spawn_Angle = node.GetAttribute( "angle" ).tofloat();
				
				node = node.NextSibling( "vehicle" );
				
				do
				{	
					local pVehicle, iModelID, fX, fY, fZ, fAngle, iColor1, iColor2;
					
					iModelID = node.GetAttribute( "id" ).tointeger();
					fX = node.GetAttribute( "x" ).tofloat();
					fY = node.GetAttribute( "y" ).tofloat();
					fZ = node.GetAttribute( "z" ).tofloat();
					fAngle = node.GetAttribute( "angle" ).tofloat();
					iColor1 =  node.GetAttribute( "colour1" ).tointeger();
					iColor2 =  node.GetAttribute( "colour2" ).tointeger();
					node = node.NextSibling( "vehicle" );
					
					pVehicle = CreateVehicle( iModelID, Vector( fX, fY, fZ ), fAngle, iColor1, iColor2 );
					pVehicle.RespawnTime = pBase.RoundTime;
					pVehicle.IdleRespawnTime = pBase.RoundTime;
					pVehicle.OneTime = false;
				} while( node )
				
				return 1;
			}
			else
			{
				Message( "[#ff0000][Error] [#ffffff]Cannot load spawn data" );
				print( "[Error] Cannot load spawn data" );
				
				return 0;
			}
		}
		else
		{
			Message( "[#ff0000][Error] [#ffffff]Cannot load spawn data" );
			print( "[Error] Cannot load spawn data" );
			
			return 0;
		}
	}
}

class CGameLogic
{
	CaptureTime = 0;
	Taker = null;
	IsRoundInProgress = false;
	
	function Start( iBaseID )
	{
		if ( IsRoundInProgress ) Message( "*** The round is in progress" );
		else
		{
			CleanMap();
		
			if (( pBase.LoadData( iBaseID ) ) && ( pSpawn.LoadData( )))
			{
				Message( "*** Starting base " + pBase.Name + " - " + ::GetDistrictName( pBase.Marker_X, pBase.Marker_Y ) + " (ID: " + iBaseID + ")" );
								
				IsRoundInProgress = true;
				g_Timer.Start();
				
				g_Blip.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
				g_Marker.Pos = Vector( pBase.Marker_X, pBase.Marker_Y, pBase.Marker_Z );
				SetWeather( pBase.Weather.tointeger() );
				SetTime( pBase.Hour.tointeger(), 00 );
				
				foreach( iPlayerID in Players )
				{
					local pPlayer = FindPlayer( iPlayerID );
					
					if (( pPlayer ) && ( pPlayer.Spawned ) && ( pPlayer.Team <= 1 ) && ( pPlayer.Health > 0 ))
					{
						pPlayerManager.SetTeam( pPlayer );
						pPlayer.Immune = false;
						pPlayer.Health = 100;
						
						CallClientFunc( pPlayer, "basemode/client.nut", "onBaseStart", pBase.RoundTime, g_Marker.ID );
						
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
		Taker = null;
		CaptureTime = 0;
		iRoundStartTime = 20;
		
		if ( g_iRoundStartType != 0 ) g_Timer.Stop();
		g_CaptureTimer.Stop();
		
		foreach( iPlayerID in Players )
		{
			local pPlayer = FindPlayer( iPlayerID );
			
			if ( pPlayer )
			{
				if ( pPlayer.Spawned )
				{
					if ( pPlayer.Vehicle ) pPlayer.RemoveFromVehicle();
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
					
					pPlayer.ClearWeapons();
					pPlayer.Immune = true;
					pPlayer.Health = 100;
					pPlayerManager.DeleteTeam( pPlayer );
				}
				CallClientFunc( pPlayer, "basemode/client.nut", "onBaseEnd", pPlayerManager.Team1Score, pPlayerManager.Team2Score );
			}
		}
		
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

function CLIENT_UpdateScores( pPlayer )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateScores", pPlayerManager.Team1Score, pPlayerManager.Team2Score );
}

function CLIENT_UpdateTeamNames( pPlayer )
{
	local szTeam1 = pPlayerManager.GetTeamFullName( 0 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 0 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 0 );
	local szTeam2 = pPlayerManager.GetTeamFullName( 1 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 1 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 1 );
	
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateTeamNames", szTeam1, szTeam2 );
}

function CLIENT_UpdateSettings( pPlayer )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateSettings", ColtAmmo, UZIAmmo, ShotgunAmmo, AKAmmo, M16Ammo, RifleAmmo, MolotovAmmo, GrenadeAmmo, GetMaxPlayers() );
}
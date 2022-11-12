Players <- {};
TeamMembers <- {};
SpawnState <- {};

g_Blip <- CreateBlip( BLIP_NONE, Vector( -1009.0, -164.0, 34.5 ));
g_Blip.Colour = 2;

g_Marker <- CreateSphere( Vector( -1009.0, -164.0, 34.5 ), 1.0 );
g_Marker.Type = MARKER_TYPE_PLAYER ;

g_iDefendingTeam <- 0;
g_iLastPlayedBase <- null;

class CPlayerClass
{
	Instance = null;
	Key = null;
	LastMessage = null;
	LastMessageTime = null;
	Repeats = null;
	LoggedIn = null;
	lastspawn=null;
	
	// Stats
	DBID = null;
	Nick = null;
	LUID = null;
	Password = null;
	IP = null;
	AdminLevel = 0;
	Warnings = 0;
	Joins = 1;
	Kills = 0;
	Deaths = 0;
	Wins = 0;
	Loses = 0;
	Captures = 0;
	LastSeen = 0;
	Registered = null;
	
	constructor( pPlayer )
	{
		Instance = pPlayer;
		Key = GetTickCount();
		LastMessage = "";
		LastMessageTime = 0;
		Repeats = 0;
		LoggedIn = false;
		lastspawn=0;
		
		DBID = 0;
		Nick = pPlayer.Name;
		LUID = pPlayer.LUID;
		Password = "";
		IP = pPlayer.IP;
		AdminLevel = 0;
		Warnings = 0;
		Joins = 1;
		Kills = 0;
		Deaths = 0;
		Wins = 0;
		Loses = 0;
		Captures = 0;
		LastSeen = "";
		Registered = "";
		
		pPlayer.Marker = false;
	}
	function Join()
	{
		if ( !Autologin() ) CallClientFunc( this.Instance, "basemode/client.nut", "ShowRegistrationWindow" );
	}
	function IsRegistered()
	{
		if ( this.LoggedIn ) return 1;
		else
		{
			if ( pDatabase.IsPlayerRegisteredQuery( this.Instance )) return 1;
			else return 0;
		}
	}
	function Autologin()
	{
		if ( !this.LoggedIn )
		{
			if ( pDatabase.IsPlayerRegisteredQuery( this.Instance ) )
			{
				if ( !this.LoggedIn ) { MessagePlayer( "This account is registered. Use /login <password> command.", this.Instance ); return 1; }
				else
				{
					//LoadData
					pDatabase.LoadPlayerData( this.Instance );
					this.LoggedIn = true;
					this.Joins++;
					::MessagePlayer("[#00ff00]Your account has been loaded successfully.", this.Instance );
					if ( this.Password.len() == 0 )
					{
						::MessagePlayer("[#ff0000]You don't have password protection.", this.Instance );
						::MessagePlayer("[#ff0000]Use [#ffff00]/protect <password>[#ff0000] command.", this.Instance );
					}
					return 1;
				}
			}
			else return 0;
		}
	}
	function Login( szPass )
	{
		if ( CPlayer[ this.Instance.ID ].LoggedIn )  MessagePlayer( "[#00ff00]You are already logged in!", this.Instance );
		else if ( !szPass ) MessagePlayer( "[#ff0000][Syntax] [#ffffff] /login <password>", this.Instance );
		else if ( pDatabase.CheckPassword( this.Instance, szPass ) )
		{
			//LoadData
			pDatabase.LoadPlayerData( this.Instance );
			this.LoggedIn = true;
			this.Joins++;
			MessagePlayer( "You have been logged in successfully!", this.Instance );
		}
		else
		{
			if ( !loginAttempts.rawin( this.Instance.Name ) ) loginAttempts.rawset( this.Instance.Name, 0 );
			local iAttempts = loginAttempts.rawget( this.Instance.Name );

			iAttempts++;
			loginAttempts.rawset( this.Instance.Name, iAttempts );

			MessagePlayer( "[#ff0000][Basemode] [#ffffff]Login failed (Attempts " + loginAttempts.rawget( this.Instance.Name ).tostring() + "/" + PLAYER_LOGIN_ATTEMPTS + ").", this.Instance );
			
			if ( iAttempts == PLAYER_LOGIN_ATTEMPTS )
			{
				MessagePlayer( "[#ff0000][Basemode] [#ffffff] Login attempts limit reached. Banning...", this.Instance );
				BanLUID ( this.Instance.LUID );
				BanIP ( this.Instance.IP );
			}
		}
	}
	function Register()
	{
		pDatabase.RegisterQuery( this.Instance );
		//pDatabase.SavePlayerData( this.Instance );
		
		MessagePlayer( "Your account has been created!", this.Instance );
		MessagePlayer("[#ff0000]You don't have password protection.", this.Instance );
		MessagePlayer("[#ff0000]Use [#ffff00]/protect <password>[#ff0000] command.", this.Instance );
	}
	function ShowRegisteredMessage()
	{
		MessagePlayer( "Message 1", this.Instance );
		MessagePlayer( "Message 2", this.Instance );
	}
	function DetectSpam( szMessage )
	{
		if ( !CHAT_FLOOD_WARNINGS ) return;
		if ( CPlayer[ this.Instance.ID ].Warnings == CHAT_FLOOD_WARNINGS )
		{
			MessagePlayer( "[#ff0000][Anti-spam] [#ffffff]You have reached warn level, relax :)", this.Instance );
			MessagePlayer( "[#ff0000][Anti-spam] [#ffffff]Warn level will decrease after every round.", this.Instance );
			MessagePlayer( pSettings.GetTeamColor( this.Instance.Team ) + this.Instance.Name + "[#ffffff]: " + szMessage, this.Instance );
			return 0;
		}
		if ( szMessage == CPlayer[ this.Instance.ID ].LastMessage )
		{
			CPlayer[ this.Instance.ID ].Repeats++;
			
			if ( GetTickCount() - CPlayer[ this.Instance.ID ].LastMessageTime < CHAT_REPEAT_INTERVAL )
			{
				CPlayer[ this.Instance.ID ].Warnings++;
				MessagePlayer( "[#ff0000][Anti-spam] [#00ff00]Please don't repeat yourself! Warns: " + CPlayer[ this.Instance.ID ].Warnings + "/" + CHAT_FLOOD_WARNINGS, this.Instance );
			}
			else if ( CPlayer[ this.Instance.ID ].Repeats > CHAT_REPEAT_ALLOWED )
			{
				CPlayer[ this.Instance.ID ].Warnings++;
				MessagePlayer( "[#ff0000][Anti-spam] [#00ff00]Please don't repeat yourself! Warns: " + CPlayer[ this.Instance.ID ].Warnings + "/" + CHAT_FLOOD_WARNINGS, this.Instance );
			}
		}
		else if ( GetTickCount() - CPlayer[ this.Instance.ID ].LastMessageTime < CHAT_FLOOD_INTERVAL )
		{
			CPlayer[ this.Instance.ID ].Warnings++;
			
			MessagePlayer( "[#ff0000][Anti-spam] [#ffffff]You have been warned for spamming.", this.Instance );
			MessagePlayer( "[#ff0000][Anti-spam] [#ffffff]Warns: " + CPlayer[ this.Instance.ID ].Warnings + "/" + CHAT_FLOOD_WARNINGS, this.Instance );
			MessagePlayer( "[#ff0000][Anti-spam] [#ffffff]If you don't stop, you'll get muted.", this.Instance );
		}
		
		CPlayer[ this.Instance.ID ].LastMessage = szMessage;
		CPlayer[ this.Instance.ID ].LastMessageTime = GetTickCount();

		if ( CPlayer[ this.Instance.ID ].Warnings < CHAT_FLOOD_WARNINGS )
		{
			if ( this.Repeats > 0 ) this.Repeats--;
			return 1;
		}
	}
	function IsMuted()
	{
		if ( this.Warnings == 10 ) return 1;
		else return false;
	}
	function DecreaseWarns()
	{
		if ( this.Warnings > 0 )
		{
			if ( this.Warnings == CHAT_FLOOD_WARNINGS ) MessagePlayer( "[#ff0000][Anti-spam] [#00ff00]You have been unmuted, but please dont spam again! :)", this.Instance );
			
			this.Warnings--;
			MessagePlayer( "[#ff0000][Anti-spam] [#00ff00]Your warning level has decreased - " + this.Warnings + "/" + CHAT_FLOOD_WARNINGS, this.Instance );
		}
	}
	function Unmute()
	{
		LastMessage = "";
		LastMessageTime = 0;
		Repeats = 0;
		Warnings = 0;
		
		MessagePlayer( "[#ff0000][Anti-spam] [#00ff00]You have been unmuted, but please dont spam again! :)", this.Instance );
	}
	function Spawn()
	{
		if ( !this.Instance.Spawned ) return 0;
		if ( TEAM_BALANCE_DIFFERENCE ) pPlayerManager.CheckBalance( this.Instance );
		this.Instance.Immune = true;
		pPlayerManager.CountPlayers();
		CLIENT_UpdateSpawnSelection( this.Instance, "" );
		
		CLIENT_UpdateTeamNames( null, true );
		
		::CloseSSVBridge();
		::SetSSVBridgeLock( true );
		for( local iGarageID = 0; iGarageID <= 26; iGarageID++ )
		{
			::OpenGarage( iGarageID );
		}
		
		this.Instance.ClearWeapons();
		this.Instance.Pos = lobby_spawn_pos[this.Instance.Team];
		this.Instance.Angle = lobby_spawn_angle[this.Instance.Team];
		
		Message( "[#ffffff]*** " + pSettings.GetTeamColor( this.Instance.Team ) + this.Instance.Name + "[#ffffff] has joined the " + pSettings.GetTeamColor( this.Instance.Team ) + pPlayerManager.GetTeamName( this.Instance.Team ) + "[#ffffff] team!" );
		if ( this.Instance.Team == 0 || 1 ) MessagePlayer( "[#ffffff]*** [#ffff00]Your team stats: [Members: " + pPlayerManager.GetTeamPlayersCount( this.Instance.Team ) + " | Wins: " + pPlayerManager.GetTeamWins( this.Instance.Team ) + " | Loses: " + pPlayerManager.GetTeamLoses( this.Instance.Team ) + "]", this.Instance );
		
		return 1;
	}
	function SwitchTeam()
	{
		if ( pGame.IsRoundInProgress ) { MessagePlayer( "[#ff0000][Error] [#00ff00]You cant change your team while round is in progress.", this.Instance ); return 0; }
		else if ( !this.Instance.Spawned ) { MessagePlayer( "[#ff0000][Error] [#00ff00]You must be spawned first.", this.Instance ); return 0; }
		
		this.Instance.Colour = this.Instance.Team;
		
		if ( this.Instance.Team == 0 ) this.Instance.Team = 1;
		else if ( this.Instance.Team == 1 ) this.Instance.Team = 0;
		
		pPlayerManager.CountPlayers();
		
		local pSpawnClass = ::FindSpawnClass( this.Instance.Team );
		this.Instance.Skin = pSpawnClass.Skin;
		this.Instance.Pos = lobby_spawn_pos[this.Instance.Team];
		this.Instance.Angle = lobby_spawn_angle[this.Instance.Team];
		
		CLIENT_UpdateTeamNames( null, true );
	
		return 1;
	}
	function Ban()
	{
		//BanLUID( ::this.Instance.LUID );
		//BanPlayer( ::this.Instance, BANTYPE_IP );
		//BanPlayer( ::this.Instance, BANTYPE_NAME );
	}
	function CheckKey( iKey )
	{
		if (( !iKey ) || ( iKey != this.Key ))
		{
			this.Ban();
			Message( "[#00ff00]Banning " + this.Instance.Name + " (exploit attempt)" );
		}
		else return 1;
	}
}



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
	BaseballBat = true;
	
	TEAM1_HEX_COLOR = "[#ff0000]";	// red
	TEAM2_HEX_COLOR = "[#0000ff]";	// blue
	SPECT_HEX_COLOR = "[#ffff00]";	// yellow
	
	function GetAmmoFromWeaponID( iWeaponID )
	{
		switch ( iWeaponID )
		{
			case 1:
				return BaseballBat;
			case 2:
				return ColtAmmo;
			case 3:
				return UZIAmmo;
			case 4:
				return ShotgunAmmo;
			case 5:
				return AKAmmo;
			case 6:
				return M16Ammo;
			case 7:
				return RifleAmmo;
			case 10:
				return MolotovAmmo;
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
		else return "[#ffffff]";
	}
	
	function UpdateClientSettings( pPlayer )
	{
		CLIENT_UpdateTeamNames( pPlayer, false );
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

class CTeamClass
{
	Players = null;
	Alive = null;
	Spawned = null;
	Score = null;
	Name = null;
	Color = null;
	IsSpectator = null;
	
	constructor( szName, bIsSpectator )
	{
		Players = 0;
		Alive = 0;
		Spawned = 0;
		Score = 0;
		Name = szName;
		Color = RGB( 0, 0, 0 );
		IsSpectator = bIsSpectator;
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
	}
	function AddToRound( pPlayer )
	{
		if ( !pPlayer.Spawned ) return 0;
		pPlayerManager.SetTeam( pPlayer );
		pPlayerManager.Add( pPlayer );
		
		pPlayer.Immune = false;
		//pPlayer.Marker = false;
		pPlayer.Health = 100;
		
		pSettings.UpdateClientSettings( pPlayer );
		
		local isAttacker = false;
			
		if ( !pGame.IsArena )
		{
			if ( pPlayer.Team == g_iDefendingTeam )
			{
				pPlayer.Pos = Vector( pBase.Spawn_X, pBase.Spawn_Y, pBase.Spawn_Z );
				pPlayer.Angle = pBase.Spawn_Angle;
				isAttacker = false;
			}
			else
			{
				pPlayer.Pos = Vector( pSpawn.Spawn_X, pSpawn.Spawn_Y, pSpawn.Spawn_Z );
				pPlayer.Angle = pSpawn.Spawn_Angle;
				isAttacker = true;
			}
		}
		else
		{
			if ( pPlayer.Team == g_iDefendingTeam )
			{
				pPlayer.Pos = Vector( pArena.Red_Spawn_X, pArena.Red_Spawn_Y, pArena.Red_Spawn_Z );
				pPlayer.Angle = pArena.Red_Spawn_Angle;
				isAttacker = false;
			}
			else
			{
				pPlayer.Pos = Vector( pArena.Blue_Spawn_X, pArena.Blue_Spawn_Y, pArena.Blue_Spawn_Z );
				pPlayer.Angle = pArena.Blue_Spawn_Angle;
				isAttacker = false;
			}
		}
		
		CallClientFunc( pPlayer, "basemode/client.nut", "onBaseStart", pBase.RoundTime, g_Marker.ID, isAttacker );
		
		pPlayerManager.CountMembers();
		
		CLIENT_UpdateTeamNames( null, true );
	}
	function DeleteFromRound( pPlayer )
	{
		if ( pPlayer && pPlayer.Spawned )
		{
			if ( pPlayer.Vehicle ) pPlayer.RemoveFromVehicle();			
			pPlayer.ClearWeapons();
			pPlayer.Immune = true;
			pPlayer.Health = 100;
			pPlayer.Frozen = false;
			//pPlayer.RestoreCamera();
			pPlayer.Pos = lobby_spawn_pos[pPlayer.Team];
			pPlayer.Angle = lobby_spawn_angle[pPlayer.Team];
		
			pPlayerManager.DeleteTeam( pPlayer );
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
	function GetTeamWins( iTeamID )
	{
		if ( iTeamID == 0 ) return Team1Score;
		else if ( iTeamID == 1 ) return Team2Score;
		else return 0;
	}
	function GetTeamLoses( iTeamID )
	{
		if ( iTeamID == 0 ) return Team2Score;
		else if ( iTeamID == 1 ) return Team1Score;
		else return 0;
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
			
			CLIENT_UpdateTeamNames( null, true );
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
		
		CLIENT_UpdateTeamNames( null, true );
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
	function CheckBalance( pPlayer )
	{
		if ( pPlayerManager.GetTeamPlayersCount( 0 ) != pPlayerManager.GetTeamPlayersCount( 1 ))
		{
			local iOpponentTeam;
			if ( pPlayer.Team == 0 ) iOpponentTeam = 1;
			else if ( pPlayer.Team == 1 ) iOpponentTeam = 0;
			
			local 	iDifference,
					iAllies = pPlayerManager.GetTeamPlayersCount( pPlayer.Team ),
					iOpponents = pPlayerManager.GetTeamPlayersCount( iOpponentTeam );
				
			if ( iAllies > iOpponents ) iDifference = iAllies - iOpponents;
			else if ( iAllies < iOpponents ) iDifference = iOpponents - iAllies;

			//local iDifference = pPlayerManager.GetTeamPlayersCount( iAllies ) - pPlayerManager.GetTeamPlayersCount( iOpponentTeam );
			if ( iDifference >= TEAM_BALANCE_DIFFERENCE )
			{
				CPlayer[ pPlayer.ID ].SwitchTeam();
				MessagePlayer( "[#ff0000]There are too many players in selected team.", pPlayer );
				Message( "[#00ff00]Team balancer has moved " + pPlayer.Name + " to " + pPlayerManager.GetTeamName( pPlayer.Team ) + " team." );
			}
			else return 1;
		}
		else return 1;
	}
	function CheckWinner()
	{
		if ( !pGame.IsRoundInProgress ) return 0;
		
		if (( RedMembers == 0 ) && ( BlueMembers == 0 ))
		{
			pGame.End( 255 );
			Message( "[#00FF00]*** This round was a draw!" );
			if (USE_ECHO) decho(3,"***This round was a draw!***");
		}
		else if (( RedMembers == 0 ) || ( BlueMembers == 0 ))
		{			
			if ( RedMembers == 0 )
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (killed all enemies)" );
				Team2Score++;
				if (USE_ECHO) decho(3,"***" + pPlayerManager.Team2Name + " team wins! (killed all enemies)***");
				pGame.End( 1 );
			}
			else
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (killed all enemies)" );
				Team1Score++;
				if (USE_ECHO) decho(3,"***" + pPlayerManager.Team1Name + " team wins! (killed all enemies)***");
				pGame.End( 0 );
			}
		}
		else if ( pBase.RoundTime == 0 )
		{
			if ( pGame.IsArena ) Message( "[#00FF00]*** This round was a draw! (timeout)" );
			else if ( g_iDefendingTeam == 1 )
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (timeout)" );
				Team2Score++;
			}
			else
			{
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (timeout)" );
				Team1Score++;
			}
			
			pGame.End( 0 );
		}
		else if ( pGame.CaptureTime == 15 )
		{			
			if ( g_iDefendingTeam == 1 )
			{
				local pTaker = FindPlayer( pGame.Taker );
				Message( "[#00FF00]*** " + pPlayerManager.Team1Name + " team wins! (captured the base-" + pTaker.Name + ")" );
				CPlayer[ pTaker.ID ].Captures++;
				Team1Score++;
				if (USE_ECHO) decho(3,"***" + pPlayerManager.Team1Name + " team wins! (captured the base)***");
				pGame.End( 0 );
			}
			else
			{
				local pTaker = FindPlayer( pGame.Taker );
				Message( "[#00FF00]*** " + pPlayerManager.Team2Name + " team wins! (captured the base-" + pTaker.Name + ")" );
				CPlayer[ pTaker.ID ].Captures++;
				Team2Score++;
				if (USE_ECHO) decho(3,"***" + pPlayerManager.Team2Name + " team wins! (captured the base)***");
				pGame.End( 1 );
			}
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
		::OpenSSVBridge();
		
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
		
		//::SetGameModeName ( "[Arena: " + pBase.Name + "]" );
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
					if (USE_ECHO) decho(3,"***Starting base " + pBase.Name + " - " + ::GetDistrictName( pBase.Marker_X, pBase.Marker_Y ) + " (ID: " + iBaseID + ")***");
					
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
	
	function End( iWinnerTeam )
	{
		if ( !IsRoundInProgress ) return 0;
		::SetServerRule( "Base", "Main Lobby" );
		::SetServerRule( "Time left", "0:00" );
		SetWeather( LOBBY_WEATHER );
		if ( LOBBY_HOUR == -1 ) SetTime( date().hour, date().min );
		else SetTime( LOBBY_HOUR, 00 );
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
			local isWinner = false;
			
			CPlayer[ pPlayer.ID ].DecreaseWarns();
			
			if ( iWinnerTeam != 255 )
			{
				if ( pPlayer.Team == iWinnerTeam ) isWinner = true;
				if ( isWinner ) CPlayer[ pPlayer.ID ].Wins++;
				else CPlayer[ pPlayer.ID ].Loses++;
			}
			
			CallClientFunc( pPlayer, "basemode/client.nut", "onBaseEnd", pPlayerManager.Team1Score, pPlayerManager.Team2Score, pPlayer.Spawned, isWinner );
			
			pPlayerManager.DeleteFromRound( pPlayer );
		}
		
		pPlayerManager.SwitchTeams();
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

function CLIENT_UpdateCaptureTime( pPlayer )
{
	if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateCaptureTime", pGame.CaptureTime );
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

function CLIENT_UpdateTeamNames( pPlayer, bAll )
{
	local szTeam1 = pPlayerManager.GetTeamFullName( 0 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 0 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 0 );
	local szTeam2 = pPlayerManager.GetTeamFullName( 1 ) + " | Members: " + pPlayerManager.GetTeamPlayersCount( 1 ) + " | Alive: " + pPlayerManager.GetTeamMembersCount( 1 );
	
	if ( bAll )
	{
		foreach( iPlayerID in Players )
		{
			pPlayer = FindPlayer( iPlayerID );

			if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateTeamNames", szTeam1, szTeam2 );
		}
	}
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateTeamNames", szTeam1, szTeam2 );
}

function CLIENT_UpdateSpawnSelection( pPlayer, szName )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "SetSpawnClass", szName );
}

function CLIENT_UpdateSettings( pPlayer )
{
	CallClientFunc( pPlayer, "basemode/client.nut", "UpdateSettings", ColtAmmo, UZIAmmo, ShotgunAmmo, AKAmmo, M16Ammo, RifleAmmo, MolotovAmmo, GrenadeAmmo, BaseballBat, GetMaxPlayers(), AFK_SLAP_TIME, CPlayer[ pPlayer.ID ].AdminLevel, CPlayer[ pPlayer.ID ].Key );
}
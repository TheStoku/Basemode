/* ############################################################## */
/* #			BaseMode v1.0-RC2 by Stoku					# */
/* #					Have fun!								# */
/* ############################################################## */

local LOGIN_COMMAND			= "bmlogin"	// login command, leave it empty to disable this type of logging in
local ADMIN_PASSWORD		= "pass";	// admin password, empty also disables logging in with command.
local ADMIN_LEVEL			= 1;		// level to grant after /bmlogin
local ADMIN_LOGIN_ATTEMPTS	= 3;		// login attempts before ban
local PUNISHMENT_METHOD		= 0;		// type of punishment on key mismatch (0=kick, 1=ban)
local LUID_AUTOLOGIN		= true;		// enable/disable LUID autologin

local SCRIPT_VERSION			= "1.0-RC2";
local SCRIPT_AUTHOR				= "Stoku";

local NUMBER_OF_BASES			= 19;	// number of bases for autoplay system. Atm. 1-19.

g_Timer <- null;
g_CaptureTimer <- null;

function onScriptLoad()
{
	print( "" );
	print( "---------- Welcome to Base Mode v" + SCRIPT_VERSION + " -----------" );
	print( "" );
	
	Load();	// load settings/scripts
	
	print( "" );
	print( "-----------------------------------------------" );
	
	return 1;
}

function Load()
{
	// Register client functions
	RegisterRemoteFunc( "GiveWeapons" );
	RegisterRemoteFunc( "Vote" );
	RegisterRemoteFunc( "onM16PlayerKill" );
	RegisterRemoteFunc( "onM16VehicleShot" );
	RegisterRemoteFunc( "onPlayerRequestClass" );
	RegisterRemoteFunc( "SendTeamMessage" );

	// Load necessary files
	LoadModule( "lu_ini" );
	dofile( "Scripts/basemode/CServer.nut" );
	
	// Configure game settings
	EnableTrains( false );
	SetSSVBridgeLock( true );
	CloseSSVBridge( );
	SetWeatherLock( true );
	SetFriendlyFire( true );
	
	for( local iGarageID = 1; iGarageID <= 26; iGarageID++ )
	{
		OpenGarage( iGarageID );
	}
	
	// Configure server settings
	SetGamemodeName( "BaseMode (AAD)" );
	SetServerRule( "Basemode", SCRIPT_VERSION );
	SetServerRule( "Base", "Main Lobby" );
	SetServerRule( "Time left", "0:00" );
	
	// Globals
	pSettings <- CSettings();
	pPlayerManager <- CPlayerManager();
	pBase <- CBase();
	pSpawn <- CSpawn();
	pGame <- CGameLogic();
	pVoteManager <- CVoteManager();
	g_iDefendingTeam = 0;
	iRoundStartTime <- 20;
	loginAttempts <- {};
	adminList <- {};
	
	g_Timer = NewTimer( "TimeProcess", 1000, 0 );
	if ( g_iRoundStartType != 0 ) g_Timer.Stop();
	
	g_CaptureTimer = NewTimer( "CaptureTimeProcess", 1000, 0 );
	g_CaptureTimer.Stop();
	
	print( "Script has been loaded successfully!" );
}

function GiveWeapons( pPlayer, iPrimaryWeapon, iSecondaryWeapon, iAdditionalWeapon )
{
	pPlayer.ClearWeapons();
	pPlayer.SetWeapon( iAdditionalWeapon, pSettings.GetAmmoFromWeaponID( iAdditionalWeapon ));
	pPlayer.SetWeapon( iPrimaryWeapon, pSettings.GetAmmoFromWeaponID( iPrimaryWeapon ));
	pPlayer.SetWeapon( iSecondaryWeapon, pSettings.GetAmmoFromWeaponID( iSecondaryWeapon ));
}

function Vote( pPlayer, bBoolean )
{
	pVoteManager.Vote( pPlayer, bBoolean );
}

function FormatTime( iSecconds )
{
	local iMins = 0;
	local iSecs = 0;
	
	iMins = iSecconds / 60;
	iSecs = iSecconds - ( iMins * 60 );
	
	if ( iSecs < 10 ) return iMins + ":0" + iSecs;
	return iMins + ":" + iSecs;
}

function TimeProcess()
{
	if ( pGame.IsRoundInProgress )
	{
		if ( pBase.RoundTime > 0 ) pBase.RoundTime--;
		else pPlayerManager.CheckWinner();
		
		SetServerRule( "Time left", FormatTime( pBase.RoundTime ));
	}
	else if ( pVoteManager.IsVotingInProgress )
	{
		if ( pVoteManager.CurrentVoteTime > 0 )
		{
			pVoteManager.CurrentVoteTime--;
			pVoteManager.UpdateVotes();
		}
		else pVoteManager.VoteEnd();
	}
	else if ( g_iRoundStartType == 0 )
	{
		if (( pPlayerManager.RedPlayers > 0 ) && ( pPlayerManager.BluePlayers > 0 ))
		{
			if ( iRoundStartTime > 0 )
			{
				SmallMessage( "                                                                                  ~l~" + iRoundStartTime, 995, 0 );
				iRoundStartTime--;
			}
			else
			{
				iRoundStartTime = 20;
				//start random base
				pGame.Start( rand() % ( 1 - NUMBER_OF_BASES ));
			}
		}
		else
		{
			SmallMessage( "                                                        ~l~Waiting for players...", 850, 0 );
			iRoundStartTime = 20;
		}
	}
}

function CaptureTimeProcess()
{
	if ( !pGame.Taker ) pGame.CaptureTime = 0;
	else if (( pGame.IsRoundInProgress ) && ( pGame.CaptureTime < 15 )) pGame.CaptureTime++;
	else pPlayerManager.CheckWinner();
	
	foreach( iPlayerID in Players )
	{
		local pPlayer = FindPlayer( iPlayerID );

		if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateCaptureTime", pGame.CaptureTime );
	}
}

function CheckModerator( pModerator )
{
	return pPlayerManager.IsLoggedIn( pModerator );
}

function onPlayerJoin( pPlayer )
{
	pPlayerManager.Add( pPlayer );
	
	if ( LUID_AUTOLOGIN )
	{
		local iLevel = ReadIniInteger( "Scripts/basemode/admins.ini", pPlayer.LUID, "Level" );
		if ( iLevel > 0 ) pPlayerManager.Login( pPlayer );
	}

	MessagePlayer( "*** BaseMode v" + SCRIPT_VERSION + " is running ***", pPlayer, Colour( 0, 150, 0 ));
	if ( g_iRoundStartType == 0 ) MessagePlayer( "The server is script controlled. The base will start automatically.", pPlayer, Colour( 150, 150, 0 ));
	else if ( g_iRoundStartType == 1 ) MessagePlayer( "The server is vote controlled. Use /votebase to start voting!", pPlayer, Colour( 150, 150, 0 ));
	else if ( g_iRoundStartType == 2 ) MessagePlayer( "The server is admin controlled. Bases are started by admin.", pPlayer, Colour( 150, 150, 0 ));
	MessagePlayer( "If you need more info, use /help.", pPlayer, Colour( 150, 150, 0 ));
	
	return 1;
}

function onPlayerPart( pPlayer, iReasonID )
{
	pPlayerManager.Delete( pPlayer );
	pPlayerManager.DeleteTeam( pPlayer );
	pPlayerManager.CheckWinner();
	pPlayerManager.CountPlayers();
	
	if ( pPlayerManager.IsLoggedIn( pPlayer ) ) adminList.rawdelete( pPlayer.Name );
	
	return 0;
}

function onPlayerSpawn( pPlayer, pSpawn )
{
	pPlayer.Immune = true;
	pPlayerManager.CountPlayers();
	
	if ( pPlayer.Team == 0 ) Message( "*** " + pPlayer.Name + " has joined the " + pPlayerManager.Team1Name + " team!", Colour( 100, 200, 100 ));
	else if ( pPlayer.Team == 1 ) Message( "*** " + pPlayer.Name + " has joined the " + pPlayerManager.Team2Name + " team!", Colour( 100, 200, 100 ));
	
	return 1;
}

function onPlayerDeath( pPlayer, iReason )
{
	if ( iReason == WEP_VEHICLE ) Message( "* " + pPlayer.Name + " died (Vehicle).", 255, 255, 0 );
	else if ( iReason == WEP_EXPLOSION ) Message( "* " + pPlayer.Name + " died (Explosion).", 255, 255, 0 );
	else if ( iReason == WEP_DROWNED ) Message( "* " + pPlayer.Name + " drowned.", 255, 255, 0 );
	else if ( iReason == WEP_FALL ) Message( "* " + pPlayer.Name + " died (Fall).", 255, 255, 0 );
	
	pPlayerManager.DeleteTeam( pPlayer );
	pPlayerManager.CheckWinner();
}

function onPlayerKill( pKiller, pPlayer, iWeapon, iBodyPart )
{
	Message( "* " + pSettings.GetTeamColor( pKiller.Team ) + pKiller.Name + " [#ffff00]killed " + pSettings.GetTeamColor( pPlayer.Team ) + pPlayer.Name + " [#ffff00]with [#00ff00]" + GetWeaponName( iWeapon ) + "." );
	pKiller.Score++;
	
	pPlayerManager.DeleteTeam( pPlayer );
	pPlayerManager.CheckWinner();
}

function onM16VehicleShot( pPlayer, pVehicle, iWeapon )
{
	pVehicle.Health -= 20;
}

function onM16PlayerKill( pKiller, pPlayer )
{
	pPlayer.Health = 1;
}

function onPlayerRequestClass( pPlayer, iTeamID )
{
	if ( !pPlayer.Spawned )
	{
		pPlayer.SetAnim( 7 );
		SmallMessage( pPlayer, "~y~" + pPlayerManager.GetTeamPlayersCount( iTeamID ) + " Players", 5000, 1 );
	}
}

function onPlayerEnteringVehicle( pPlayer, pVehicle, iDoor )
{
	if ( pPlayer.Team == g_iDefendingTeam ) return 0;
	else return 1;
}

function onPlayerEnterSphere( pPlayer, pSphere )
{
	if ( pPlayer.Team != g_iDefendingTeam )
	{
		pGame.Taker = pPlayer.Name;
		g_CaptureTimer.Start();
	}
}

function onPlayerExitSphere( pPlayer, pSphere )
{
	g_CaptureTimer.Stop();
	pGame.Taker = null;
	pGame.CaptureTime = 0;
	
	foreach( iPlayerID in Players )
	{
		pPlayer = FindPlayer( iPlayerID );

		if ( pPlayer ) CallClientFunc( pPlayer, "basemode/client.nut", "UpdateCaptureTime", pGame.CaptureTime );
	}
}

function onPlayerCommand( pPlayer, szCommand, szText )
{
	if ( szCommand == LOGIN_COMMAND && LOGIN_COMMAND.len() > 0 && ADMIN_PASSWORD.len() > 0 )
	{
		//if (( LOGIN_COMMAND.len() > 0 ) && ( ADMIN_PASSWORD.len() > 0 ))
		//{
				if ( pPlayerManager.IsLoggedIn( pPlayer ))
				{
					MessagePlayer( "You are already logged on.", pPlayer, Colour( 0, 255, 0 ) );
					return 1;
				}
				
				if ( szText == ADMIN_PASSWORD )
				{
					MessagePlayer( "[BM] Password accepted!", pPlayer, Colour( 0, 255, 0 ) );
					pPlayerManager.Login( pPlayer, ADMIN_LEVEL );
				}
				else
				{
					if ( !loginAttempts.rawin( pPlayer.Name ) ) loginAttempts.rawset( pPlayer.Name, 0 );
					local iAttempts = loginAttempts.rawget( pPlayer.Name );

					iAttempts++;
					loginAttempts.rawset( pPlayer.Name, iAttempts );

					MessagePlayer( "Login failed (Attempts " + loginAttempts.rawget( pPlayer.Name ).tostring() + "/" + ADMIN_LOGIN_ATTEMPTS + ").", pPlayer, Colour( 255, 0, 0 ) );
					
					if ( iAttempts == ADMIN_LOGIN_ATTEMPTS )
					{
						BanLUID ( pPlayer.LUID );
						BanIP ( pPlayer.IP );
					}
				}
		//}
	}
	if ( szCommand == "help" )
	{
		MessagePlayer( "*** BaseMode - Help ***", pPlayer, Colour( 0, 150, 0 ));
		
		if ( g_iRoundStartType == 0 ) MessagePlayer( "The server is script controlled. The base will start automatically.", pPlayer, Colour( 150, 150, 0 ));
		else if ( g_iRoundStartType == 1 )
		{
			MessagePlayer( "The server is vote controlled. Use /votebase to start voting!", pPlayer, Colour( 150, 150, 0 ));
			MessagePlayer( " /votebase - start voting", pPlayer, Colour( 150, 150, 0 ));
		}
		else if ( g_iRoundStartType == 2 )
		{
			MessagePlayer( "The server is admin controlled. Bases are started by admin.", pPlayer, Colour( 150, 150, 0 ));
			MessagePlayer( " /base <ID> - starts round", pPlayer, Colour( 150, 150, 0 ));
			MessagePlayer( " /end - ends round", pPlayer, Colour( 150, 150, 0 ));
		}
		
		MessagePlayer( " /t1name or /t2name <TEXT> - changes team name", pPlayer, Colour( 150, 150, 0 ));
		MessagePlayer( " /switch - switch teams", pPlayer, Colour( 150, 150, 0 ));
		MessagePlayer( " /resetscore - reset score", pPlayer, Colour( 150, 150, 0 ));
		MessagePlayer( " /info", pPlayer, Colour( 150, 150, 0 ));
	}
	else if ( szCommand == "info" )
	{
		MessagePlayer( "BaseMode v" + SCRIPT_VERSION, pPlayer, Colour( 0, 150, 0 ));
		MessagePlayer( pPlayerManager.GetTeamFullName( 0 ) + " - score: " + pPlayerManager.Team1Score, pPlayer, Colour( 0, 150, 0 ));
		MessagePlayer( pPlayerManager.GetTeamFullName( 1 ) + " - score: " + pPlayerManager.Team2Score, pPlayer, Colour( 0, 150, 0 ));
	}
	else if ( szCommand == "kill" )
	{
		Message( pPlayer.Name + " killed himself." );
		pPlayer.Health = 0;
	}
	else if ( szCommand == "votebase" )
	{
		if ( g_iRoundStartType == 1 ) pVoteManager.VoteStart( pPlayer, szText );
		else return 1;
	}
	else if ( szCommand == "t" )
	{
		if ( !szText ) return 0;
		else SendTeamMessage( pPlayer, szText );
	}
	else if ( szCommand == "base" )
	{
		if ( CheckModerator( pPlayer ))	pGame.Start( szText );
	}
	else if ( szCommand == "end" )
	{
		if ( CheckModerator( pPlayer ))	pGame.End();
	}
	else if ( szCommand == "switch" )
	{
		if ( CheckModerator( pPlayer )) pPlayerManager.SwitchTeams();
	}
	else if ( szCommand == "t1name" )
	{
		if ( CheckModerator( pPlayer ))
		{
			if ( szText.len() == 0 ) MessagePlayer( " [SYNTAX] /t1name <text>", pPlayer, Colour( 255, 0, 0 ));
			else pPlayerManager.SetTeamName( 1, szText );
		}
	}
	else if ( szCommand == "t2name" )
	{
		if ( CheckModerator( pPlayer ))
		{
			if ( szText.len() == 0 ) MessagePlayer( " [SYNTAX] /t2name <text>", pPlayer, Colour( 255, 0, 0 ));
			else pPlayerManager.SetTeamName( 2, szText );
		}
	}
	else if ( szCommand == "resetscore" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		pPlayerManager.Team1Score = 0;
		pPlayerManager.Team2Score = 0;
	}
	else if ( szCommand == "kill" )
	{
		pPlayer.Health = 1;
		Message( pPlayer.Name + " killed himself." );
	}
	else if ( szCommand == "anim" )
	{
		if ( szText ) pPlayer.SetAnim( szText.tointeger() );
	}
	else if ( szCommand == "color" )
	{
		//Message( pSettings.GetTeamColor( 0 ) + "asd" );

		//Message( pSettings.GetTeamColor( pKiller.Team ) + pKiller.Name + " [#ffffff] killed " + pSettings.GetTeamColor( pPlayer.Team ) + pPlayer.Name + " [#ffffff]with " + pSettings.GetWeaponNameFromID( iWeapon ));
		
	}
		else if ( szCommand == "kick" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) {MessagePlayer("[#ff0000]Invalid Usage. /kick TargetID",pPlayer); return 0; }
		local targetplr = FindPlayer( szText.tointeger() )
		if ( !targetplr ) 
		{
			MessagePlayer ( "[#ff0000]Error: Player not found.", pPlayer );
			return 0;
		}
		if ( targetplr )
		{
			KickPlayer ( targetplr );
			Message("[#ff0000]Administrator "+pPlayer+" has kicked "+targetplr);
		}
	}
	else if ( szCommand == "ban" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) { MessagePlayer("[#ff0000]Invalid Usage. /ban TargetID",pPlayer); return 0; }
		local targetplr = FindPlayer( szText.tointeger() )
		if ( !targetplr ) 
		{
			MessagePlayer ( "[#ff0000]Error: Player not found.", pPlayer );
			return 0;
		}
		if ( targetplr )
		{
			BanPlayer ( targetplr , BANTYPE_LUID );
			Message("[#ff0000]Administrator "+pPlayer+" has banned "+targetplr);
		}
}
	else if ( szCommand == "air" )
	{
		pPlayer.Pos = Vector( -1503.10, -977.10, 11.37 );
		pPlayer.Angle = 272.5;
	}
	else if ( szCommand == "shake" ) ShakeCamera( pPlayer, szText.tointeger() );
	else if ( szCommand == "tele" ) pPlayer.Pos = Vector( 166.56, -938.70, 26.01 );
	else if ( szCommand == "pos" )
	{
		print( pPlayer.Pos + " angle: " + pPlayer.Angle );
	}
	else if ( szCommand == "weather" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		SetWeather( szText.tointeger() );
	}
	else if ( szCommand == "hour" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		SetTime( szText.tointeger(), 0 );
	}
	else if ( szCommand == "del" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		pPlayerManager.DeleteTeam( pPlayer );
	}
	else if ( szCommand == "add" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		
		local pAddedPlayer = FindPlayer( szText );
		if ( pAddedPlayer )
		{
			pPlayerManager.SetTeam( pAddedPlayer );
			pPlayerManager.Add( pAddedPlayer );
		}
	}
	else if ( szCommand == "settype" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( szText == "auto" ) g_iRoundStartType = 0;
		else if ( szText == "vote" ) g_iRoundStartType = 1;
		else if ( szText == "manual" ) g_iRoundStartType = 2;
		else g_iRoundStartType = szText.tointeger();
	}
	
	else if ( szCommand == "player" )
	{
		print( "<player x=\"" + pPlayer.Pos.x + "\" y=\"" + pPlayer.Pos.y + "\" z=\"" + pPlayer.Pos.z + "\" angle=\"" + pPlayer.Angle + "\"/>" );
	}
	
	else if ( szCommand == "marker" )
	{
		print( "<marker x=\"" + pPlayer.Pos.x + "\" y=\"" + pPlayer.Pos.y + "\" z=\"" + pPlayer.Pos.z + "\"/>" );
	}
	else if ( szCommand == "vehicle" )
	{
		print( "<vehicle id=\"" + szText + "\"x=\"" + pPlayer.Vehicle.Pos.x + "\" y=\"" + pPlayer.Vehicle.Pos.y + "\" z=\"" + pPlayer.Vehicle.Pos.z + " angle=\"" + pPlayer.Vehicle.Angle + "\"" + " colour1=\"0" + "\"" + " colour2=\"0" + "\"" + "/>" );
	}
	
	else if ( szCommand == "cv" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		CreateVehicle( szText.tointeger(), pPlayer.Pos, pPlayer.Angle, -1, -1 );
	}
	
	else if ( szCommand == "setpass" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) SetPassword( "" );
		else SetPassword( szText );
	}
	
	return 1;
}

function SendTeamMessage( pPlayer, szMessage )
{
	if ( !pPlayer.Spawned ) return 0;
	
	foreach( iPlayerID in Players )
	{
		local pTeamPlayer = FindPlayer( iPlayerID );
		if (( pTeamPlayer.Team == pPlayer.Team ) && ( pTeamPlayer.Spawned )) MessagePlayer( pSettings.GetTeamColor( pPlayer.Team ) + "* [TEAM] " + pPlayer.Name + ": [#ffffff]" + szMessage, pTeamPlayer);
	}
}

function onConsoleInput( szCommand, szText )
{
	if ( szCommand == "apu" )
	{
	}
	else if ( szCommand == "switch" ) pPlayerManager.SwitchTeams();
	else if ( szCommand == "team1" ) pPlayerManager.SetTeamName( 1, szText );
	else if ( szCommand == "team2" ) pPlayerManager.SetTeamName( 2, szText );
	else if ( szCommand == "ignore" )
	{
		local pPlr = FindPlayer( szText );
		
		pPlayer.SetIgnored( pPlr, true );
	}
}
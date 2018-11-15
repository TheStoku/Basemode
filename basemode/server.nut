/* ############################################################## */
/* #			BaseMode v1.0-RC3 by Stoku						# */
/* #					Have fun!								# */
/* ############################################################## */

local SCRIPT_VERSION			= "1.0-RC3";
local SCRIPT_AUTHOR				= "Stoku";

SCRIPT_DIR						<- "Scripts/basemode/";

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
	dofile( SCRIPT_DIR + "config.nut" );
	dofile( SCRIPT_DIR + "CServer.nut" );
	
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
		if (( pPlayerManager.GetSpawnedPlayersCount( 0 ) == 0 ) || ( pPlayerManager.GetSpawnedPlayersCount( 1 ) == 0 ))
		{
			SmallMessage( "                                                        ~l~Waiting for players...", 850, 0 );
			iRoundStartTime = 20;
		}
		else
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

	MessagePlayer( "[#FFFF00]*** Basemode v" + SCRIPT_VERSION + " is running ***", pPlayer );
	if ( g_iRoundStartType == 0 ) MessagePlayer( "[#FFFF00]The server is script controlled. The base will start automatically.", pPlayer );
	else if ( g_iRoundStartType == 1 ) MessagePlayer( "[#FFFF00]The server is vote controlled. Use [#00FF00]/votebase [#FFFF00]to start voting!", pPlayer );
	else if ( g_iRoundStartType == 2 ) MessagePlayer( "[#FFFF00]The server is admin controlled. Bases are started by admin.", pPlayer );
	MessagePlayer( "[#FFFF00]If you need more info, use [#00FF00]/help", pPlayer );
	
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
	
	foreach( iPlayerID in Players )
	{
		local pPlayer = FindPlayer( iPlayerID );

		if ( pPlayer )
		{
			CLIENT_UpdateTeamNames( pPlayer );				
		}
	}
	
	if ( pPlayer.Team == 0 )
	{
		Message( "[#FF0000]" + pPlayer.Name + "[#FFFFFF] has joined the [#FF0000]" + pPlayerManager.Team1Name + "[#FFFFFF] team! [#FFFFFF]| [#FFFF00]Members: " + pPlayerManager.GetTeamPlayersCount( 0 ) + " Wins: " + pPlayerManager.Team1Score + " Loses: " + pPlayerManager.Team2Score );
	}
	else if ( pPlayer.Team == 1 )
	{
		Message( "[#0000FF]" + pPlayer.Name + "[#FFFFFF] has joined the [#0000FF]" + pPlayerManager.Team2Name + "[#FFFFFF] team! [#FFFFFF]| [#FFFF00]Members: " + pPlayerManager.GetTeamPlayersCount( 1 ) + " Wins: " + pPlayerManager.Team2Score + " Loses: " + pPlayerManager.Team1Score );
	}
	
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
	
	foreach( iPlayerID in Players )
	{
		local pPlayer = FindPlayer( iPlayerID );

		if ( pPlayer )
		{
			CLIENT_UpdateTeamNames( pPlayer );				
		}
	}
}

function onPlayerKill( pKiller, pPlayer, iWeapon, iBodyPart )
{
	Message( "* " + pSettings.GetTeamColor( pKiller.Team ) + pKiller.Name + " [#ffff00]killed " + pSettings.GetTeamColor( pPlayer.Team ) + pPlayer.Name + " [#ffff00]with [#00ff00]" + GetWeaponName( iWeapon ) + "." );
	pKiller.Score++;
	
	pPlayerManager.DeleteTeam( pPlayer );
	pPlayerManager.CheckWinner();
	
	foreach( iPlayerID in Players )
	{
		local pPlayer = FindPlayer( iPlayerID );

		if ( pPlayer )
		{
			CLIENT_UpdateTeamNames( pPlayer );				
		}
	}
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
		MessagePlayer( "[#FFFFFF]Current select: " + pSettings.GetTeamColor( iTeamID ) + pPlayerManager.GetTeamFullName( iTeamID ) + " [#FFFF00]| Members: " + pPlayerManager.GetTeamPlayersCount( iTeamID ), pPlayer );
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
		if ( pPlayerManager.IsLoggedIn( pPlayer ))
		{
			MessagePlayer( "[#00FF00][Basemode] [#FFFFFF]You are already logged in.", pPlayer );
			return 1;
		}
		
		if ( szText == ADMIN_PASSWORD )
		{
			MessagePlayer( "[#00FF00][Basemode] [#FFFFFF]Password accepted!", pPlayer );
			pPlayerManager.Login( pPlayer, ADMIN_LEVEL );
		}
		else
		{
			if ( !loginAttempts.rawin( pPlayer.Name ) ) loginAttempts.rawset( pPlayer.Name, 0 );
			local iAttempts = loginAttempts.rawget( pPlayer.Name );

			iAttempts++;
			loginAttempts.rawset( pPlayer.Name, iAttempts );

			MessagePlayer( "[#FF0000][Basemode] [#FFFFFF]Login failed (Attempts " + loginAttempts.rawget( pPlayer.Name ).tostring() + "/" + ADMIN_LOGIN_ATTEMPTS + ").", pPlayer );
			
			if ( iAttempts == ADMIN_LOGIN_ATTEMPTS )
			{
				MessagePlayer( "[#FF0000][Basemode] [#FFFFFF] Login attempts limit reached. Banning..." );
				BanLUID ( pPlayer.LUID );
				BanIP ( pPlayer.IP );
			}
		}
	}
	
	if ( szCommand == "eject" )
	{
		pPlayer.RemoveFromVehicle();
	}
	else if ( szCommand == "help" )
	{
		MessagePlayer( "[#FFFFFF]*********** Basemode - Help ***********" pPlayer );
		
		if ( g_iRoundStartType == 0 ) MessagePlayer( "[#FFFFFF]The server is script controlled. The bases will start automatically.", pPlayer );
		else if ( g_iRoundStartType == 1 )
		{
			MessagePlayer( "[#FFFFFF]The server is vote controlled. Use /votebase <ID> to start voting!", pPlayer );
			MessagePlayer( "[#FFFF00] /votebase <ID> [#FFFFFF] - start voting", pPlayer );
		}
		else if ( g_iRoundStartType == 2 )
		{
			MessagePlayer( "[#FFFFFF]The server is admin controlled. Bases are started by admin.", pPlayer );
			if ( CheckModerator( pPlayer ))
			{
				MessagePlayer( "[#FFFF00] /base <ID>[#FFFFFF] - starts round", pPlayer );
				MessagePlayer( "[#FFFF00] /end [#FFFFFF] - ends round", pPlayer );
			}
		}
		
		if ( CheckModerator( pPlayer ))
		{
			MessagePlayer( "[#FFFF00] /t1name or /t2name <TEXT> [#FFFFFF] - change team name", pPlayer );
			MessagePlayer( "[#FFFF00] /switch [#FFFFFF] - switch teams", pPlayer );
			MessagePlayer( "[#FFFF00] /resetscore [#FFFFFF] - reset score", pPlayer );
		}
		
		MessagePlayer( "[#FFFF00] /eject [#FFFFFF] - exit bugged vehicle.", pPlayer );
		MessagePlayer( "[#FFFF00] /fix1 or /fix2 [#FFFFFF] - fix bugged GUI (cursor not showing/hiding)", pPlayer );
		MessagePlayer( "[#FFFF00] /info [#FFFFFF] - print script informations", pPlayer );
		MessagePlayer( "[#FFFF00] /t <message> or 'Y' key[#FFFFFF] - teamchat", pPlayer );
	}
	else if ( szCommand == "info" )
	{
		MessagePlayer( "[#FFFFFF]*********** Basemode - Info ***********" pPlayer );
		MessagePlayer( "[#FFFFFF]Basemode v" + SCRIPT_VERSION + " by Stoku", pPlayer );
		MessagePlayer( "[#FFFFFF] Team 1: [#FF0000] " + pPlayerManager.GetTeamFullName( 0 ) + " - score: " + pPlayerManager.Team1Score, pPlayer );
		MessagePlayer( "[#FFFFFF] Team 2: [#0000FF] " + pPlayerManager.GetTeamFullName( 1 ) + " - score: " + pPlayerManager.Team2Score, pPlayer );
	}
	else if ( szCommand == "kill" )
	{
		if (( iRoundStartTime < 3 ) && ( g_iRoundStartType == 0 )) MessagePlayer( "*** You can't use kill when it's less than 3 seconds before base start.", pPlayer );
		else 
		{
			Message( pPlayer.Name + " killed himself." );
			pPlayer.Health = 0;
			pPlayerManager.DeleteTeam( pPlayer );
			pPlayerManager.CountPlayers();
			pPlayerManager.CheckWinner();
		}
	}
	else if ( szCommand == "t" )
	{
		if ( !szText ) return 0;
		else SendTeamMessage( pPlayer, szText );
	}
	else if ( szCommand == "votebase" )
	{
		if ( g_iRoundStartType != 1 ) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/votebase <id>.", pPlayer );
			return 0;
		}
		else
		{
			pVoteManager.VoteStart( pPlayer, szText );
			return 1;
		}
	}
	
	
	// ################ Admin commands ########################
	else if ( szCommand == "add" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/add <player>.", pPlayer );
			return 0;
		}
		local pAddedPlayer = FindPlayer( szText );
		if ( pAddedPlayer )
		{
			pPlayerManager.AddToRound( pAddedPlayer );
			Message( "[#00ff00]Administrator " + pPlayer + " has added " + pAddedPlayer + " to the round." );
		}
	}
	else if ( szCommand == "ban" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) { MessagePlayer("[#ff0000][Syntax] [#ffffff]/ban TargetID",pPlayer ); return 0; }
		local pTargetPlayer = FindPlayer( szText.tointeger() )
		if ( !pTargetPlayer ) 
		{
			MessagePlayer ( "[#ff0000]Error: Player not found.", pPlayer );
			return 0;
		}
		if ( pTargetPlayer )
		{
			BanPlayer ( pTargetPlayer , BANTYPE_LUID );
			Message( "[#00ff00]Administrator " + pPlayer + " has banned " + pTargetPlayer );
		}
	}
	else if ( szCommand == "base" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/base <id>.", pPlayer );
			return 0;
		}
		pGame.Start( szText );
	}
	else if ( szCommand == "cv" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		CreateVehicle( szText.tointeger(), pPlayer.Pos, pPlayer.Angle, -1, -1 );
	}
	else if ( szCommand == "del" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		local pDeletedPlayer = FindPlayer( szText );
		if ( pDeletedPlayer )
		{
			pPlayerManager.DeleteTeam( pDeletedPlayer );
			Message( "[#00ff00]Administrator " + pPlayer + " has deleted " + pDeletedPlayer + " from the round." );
		}
	}
	else if ( szCommand == "end" )
	{
		if ( CheckModerator( pPlayer ))	pGame.End();
	}
	else if ( szCommand == "hour" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/hour <hour 00-24>.", pPlayer );
			return 0;
		}
		SetTime( szText.tointeger(), 0 );
		Message( "[#00ff00]Administrator " + pPlayer + " has changed time to " + szText + ":00." );
	}
	else if ( szCommand == "kick" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) { MessagePlayer("[#ff0000][Syntax] [#ffffff]/kick TargetID",pPlayer ); return 0; }
		local pTargetPlayer = FindPlayer( szText.tointeger() )
		if ( !pTargetPlayer ) 
		{
			MessagePlayer ( "[#ff0000]Error: Player not found.", pPlayer );
			return 0;
		}
		if ( pTargetPlayer )
		{
			KickPlayer ( pTargetPlayer );
			Message( "[#00ff00]Administrator " + pPlayer + " has kicked " + pTargetPlayer );
		}
	}
	else if ( szCommand == "resetscore" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		pPlayerManager.Team1Score = 0;
		pPlayerManager.Team2Score = 0;
		Message( "[#00ff00]Administrator " + pPlayer + " has reseted score." );
	}
	else if ( szCommand == "settype" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/settype auto|vote|manual or 0|1|2.", pPlayer );
			return 0;
		}
		if ( szText == "auto" ) 
		{
			g_iRoundStartType = 0;
			Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to auto." );
		}
		else if ( szText == "vote" )
		{
			g_iRoundStartType = 1;
			Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to vote started." );
		}
		else if ( szText == "manual" )
		{
			g_iRoundStartType = 2;
			Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to admin controlled." );
		}
		else
		{
			switch ( szText.tointeger() )
			{
				case 0:
					g_iRoundStartType = 0;
					Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to auto." );
					break;
				case 1:
					g_iRoundStartType = 1;
					Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to vote started." );
					break;
				case 2:
					g_iRoundStartType = 2;
					Message( "[#00ff00]Administrator " + pPlayer + " has changed round start type to admin controlled." );
					break;
			}
		}
	}
	else if ( szCommand == "setadminpass" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/setadminpass <password>.", pPlayer );
			return 0;
		}
		else ADMIN_PASSWORD = szText;
	}
	else if ( szCommand == "setpass" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText ) SetPassword( "" );
		else SetPassword( szText );
		Message( "[#00ff00]Administrator " + pPlayer + " has changed server password." );
	}
	else if ( szCommand == "switch" )
	{
		if ( CheckModerator( pPlayer )) pPlayerManager.SwitchTeams();
		Message( "[#00ff00]Administrator " + pPlayer + " has switched teams." );
	}
	else if ( szCommand == "t1name" )
	{
		if ( CheckModerator( pPlayer ))
		{
			if ( szText.len() == 0 ) MessagePlayer( "[#ff0000][Syntax] [#ffffff]/t1name <text>", pPlayer, Colour( 255, 0, 0 ));
			else
			{
				pPlayerManager.SetTeamName( 1, szText );
				Message( "[#00ff00]Administrator " + pPlayer + " has changed team 1 name to " + szText );
			}
		}
	}
	else if ( szCommand == "t2name" )
	{
		if ( CheckModerator( pPlayer ))
		{
			if ( szText.len() == 0 ) MessagePlayer( "[#ff0000][Syntax] [#ffffff]/t2name <text>", pPlayer, Colour( 255, 0, 0 ));
			else
			{
				pPlayerManager.SetTeamName( 2, szText );
				Message( "[#00ff00]Administrator " + pPlayer + " has changed team 2 name to " + szText );
			}
		}
	}
	else if ( szCommand == "weather" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( !szText )
		{
			MessagePlayer ( "[#ff0000][Syntax] [#ffffff]/weather <id>.", pPlayer );
			return 0;
		}
		SetWeather( szText.tointeger() );
		Message( "[#00ff00]Administrator " + pPlayer + " has changed weather to " + szText );
	}
	
	// ################ Debug commands #################
	else if ( szCommand == "anim" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		if ( szText ) pPlayer.SetAnim( szText.tointeger() );
	}
	else if ( szCommand == "air" )
	{
		if ( !CheckModerator( pPlayer )) return 0;
		pPlayer.Pos = Vector( -1503.10, -977.10, 11.37 );
		pPlayer.Angle = 272.5;
	}
	else if ( szCommand == "pos" )
	{
		print( pPlayer.Pos + " angle: " + pPlayer.Angle );
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
		print( "<vehicle id=\"" + szText + "\"x=\"" + pPlayer.Vehicle.Pos.x + "\" y=\"" + pPlayer.Vehicle.Pos.y + "\" z=\"" + pPlayer.Vehicle.Pos.z + "\"" +" angle=\"" + pPlayer.Vehicle.Angle + "\"" + " colour1=\"0" + "\"" + " colour2=\"0" + "\"" + "/>" );
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
// Start of basemode config
LOGIN_COMMAND				<- "admin";	// login command, leave it empty to disable this type of logging in
ADMIN_PASSWORD				<- "pass";	// admin password, empty also disables logging in with command.
ADMIN_LEVEL					<- 1;		// level to grant after /bmlogin
ADMIN_LOGIN_ATTEMPTS		<- 3;		// login attempts before ban
PLAYER_LOGIN_ATTEMPTS		<- 5;		// player login attempts
PUNISHMENT_METHOD			<- 0;		// type of punishment on key mismatch (0=kick, 1=ban)
NUMBER_OF_BASES				<- 30;		// number of bases for autoplay system. Atm. 1-19.
NUMBER_OF_ARENAS			<- 0;		// number of arenas for autoplay system.
ROUNDSTART_TYPE				<- 0;		// 0-start random base, 1-vote, 2-admin controlled
AUTOPLAY_ROUND_REPLAY		<- true;
AUTOPLAY_TYPE				<- "base";	// "base" or "arena"
AUTOPLAY_AWAIT_TIME			<- 20;
MAX_NICK_LENGHT				<- 23;
AFK_SLAP_TIME				<- 60*2;	// (s) 2mins. Set to null to disable anti-afk system.
CHAT_FLOOD_WARNINGS			<- 10;		// Warnings before mute. Set to null to disable anti-spam system.
CHAT_FLOOD_INTERVAL			<- 1000;	// (ms) 1 message per second.
CHAT_REPEAT_INTERVAL		<- 2000;	// (ms) 1 repeat per 2 seconds.
CHAT_REPEAT_ALLOWED			<- 3;		// How many repeats are allowed before warn.
TEAM_BALANCE_DIFFERENCE		<- null;	// Set null to disable team balancer.
USE_ACCOUNTS				<- false;
USE_ECHO                    <- false;   // Enable, if server is powered with Stoku's Discord echo.

// Lobby Settings 			- [ RED, BLUE ]
lobby_spawn_pos				<- [ Vector( 165.10, -1003.50, 29.53 ), Vector( 165.74, -990.81, 29.53 ) ];
lobby_spawn_angle			<- [ 270.0, 176.229 ];
LOBBY_WEATHER				<- 0;		// 0 - Sun | 1 - Cloud | 2 - Rain | 3 - Fog 
LOBBY_HOUR					<- -1;		// -1 sync with server time

// Server settings
SetServerName( "(Official) Liberty City Killers:Basemode " + SCRIPT_VERSION +" Server [lck.gta3.pl]" );
SetMaxPlayers( 32 );
//SetPort( 2301 );
SetPassword( "" );

// Game settings
CloseSSVBridge();
SetWeatherLock( true );
SetFriendlyFire( true );
EnableTrains( false );

for( local iGarageID = 0; iGarageID <= 26; iGarageID++ )
{
	OpenGarage( iGarageID );
}
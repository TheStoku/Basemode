// Start of basemode config
LOGIN_COMMAND				<- "admin";	// login command, leave it empty to disable this type of logging in
ADMIN_PASSWORD				<- "ludmila";	// admin password, empty also disables logging in with command.
ADMIN_LEVEL					<- 1;		// level to grant after /bmlogin
ADMIN_LOGIN_ATTEMPTS		<- 3;		// login attempts before ban
PUNISHMENT_METHOD			<- 0;		// type of punishment on key mismatch (0=kick, 1=ban)
LUID_AUTOLOGIN				<- true;	// enable/disable LUID autologin
NUMBER_OF_BASES				<- 19;		// number of bases for autoplay system. Atm. 1-23.
NUMBER_OF_ARENAS			<- 2;		// number of arenas for autoplay system. Atm. 1-2.
HEADSHOTS					<- false;	// enable/disable headshots (way of disabling by Xenon)
GAMEMODE_NAME_INFO			<- true;	// enable/disable printing current base in server gamemode name
SERVER_NAME					<- "Basemode 1.0 Server (Official) [LU-DM TEAM]"; // server name
BUILD_MODE					<- false;
ALLOW_SPECTATOR				<- true;
ROUNDSTART_TYPE				<- 0;		// 0-start random base, 1-vote, 2-admin controlled
AUTOPLAY_TYPE				<- "base";	// "base" or "arena"
AUTOPLAY_AWAIT_TIME			<- 20;
// end

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
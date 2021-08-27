using Toybox.Math;

// Mookup BLE delegate class, for debugging
// it returns random values
class emtbDelegateMookup
{
	var mainView;

	enum
	{
		State_Init,			// starting up
		State_Connecting,	// scanning, choosing & connecting to a bike
		State_Idle,			// reading data from our chosen bike
		State_Disconnected,	// we've disconnected (so will need to scan etc again)
	}
	
	var state = State_Init;

	var connectedMACArray = null;	// MAC address byte array of bike we are (successfully) connected to 

	var currentScanning = false;	// scanning turned on?	
	var wantScanning = false;		// do we want it on?

	var profileRegisterSuccessCount = 0;
	var isConnectingCount = 0;


	// start the process of scanning for a bike to connect to
	function startConnecting()
	{
		mainView.values[1] = -1;
    	mainView.values[3] = -1;
    	mainView.values[6] = -1;

		state = State_Connecting;
		
		connectedMACArray = null;

		wantScanning = true;

		writingNotifyMode = false;
		currentNotifyMode = false;
	}

	// have the profiles been registered successfully?
	function isRegistered()
	{
		profileRegisterSuccessCount++;
		return (profileRegisterSuccessCount>=3);
	}
	
	// in the process of scanning & choosing a bike?
	function isConnecting()
	{
		isConnectingCount++;
		return (isConnectingCount<=10);
	}
	
	var wantReadBattery = false;
	var waitingRead = false;
	
	// call this when you want a battery reading
	function requestReadBattery()
	{
		wantReadBattery = true;
	}
	
	var wantNotifyMode = false;			// want notifications on?
	var waitingWrite = false;			// waiting for the write action to complete (which turns on or off the notifications)
	var writingNotifyMode = false;		// the on/off state we are currently in the process of writing
	var currentNotifyMode = false;		// the current on/off state (that we know from completed writes) 
	
	// call this to turn on/off notifications for the mode/gear/other data blocks 
   	function requestNotifyMode(wantMode)
   	{
   		wantNotifyMode = wantMode;
   	}
   	
   	// initialize this delegate!
    function initialize(theView)
    {
        mainView = theView;
   		startConnecting();
    }
    
    // called from compute of mainView
    function compute()
    {
    	if(!isConnecting())
    	{
	    	mainView.values[1] = random(0, 100);
	    	mainView.values[3] = random(1, 3);
	    	mainView.values[6] = random(1, 5);
	    	mainView.values[7] = random(10, 60);
	    	mainView.values[8] = random(10, 20);
	    	mainView.values[9] = random(1, 30);
    	}
    	else
    	{
    		mainView.values[1] = -1;
	    	mainView.values[3] = -1;
	    	mainView.values[6] = -1;
	    	mainView.values[7] = -1;
	    	mainView.values[8] = -1;
	    	mainView.values[9] = -1;
    	}
    }

    function sameMACArray(a, b)	// pass in 2 byte arrays
	{
		return true;
	}

	function bleDisconnect()
    {
		return true;
    }

    function deleteScannedList()
	{
    	return true;
	}
}


const RAND_MAX = 0x7FFFFFF;
function random(n, m) {
    return Math.rand() % (m-n) + n;
} 

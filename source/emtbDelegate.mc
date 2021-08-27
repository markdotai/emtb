using Toybox.BluetoothLowEnergy as Ble;

// This is the BLE delegate class
// I've just added all my BLE related stuff to here too
class emtbDelegate extends Ble.BleDelegate
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

	// start the process of scanning for a bike to connect to
	function startConnecting()
	{
		mainView.values[1] = -1;
		mainView.values[3] = -1;
		mainView.values[6] = -1;
		mainView.values[7] = -1;
		mainView.values[8] = -1;
		mainView.values[9] = -1;

		state = State_Connecting;
		
		connectedMACArray = null;

		wantScanning = true;
		readMACScanResult = null;
		deleteScannedList();

		writingNotifyMode = false;
		currentNotifyMode = false;
	}

	// have the profiles been registered successfully?
	function isRegistered()
	{
		return (profileRegisterSuccessCount>=3);
	}
	
	// in the process of scanning & choosing a bike?
	function isConnecting()
	{
		return (state==State_Connecting);
	}
	
	// successfully connected to our chosen bike?
	function isConnected()
	{
		return (state==State_Idle);
	}
	
	// Can only read the MAC address after BLE pairing to a bike (which we do while scanning)
	// this function will start a read
	function startReadingMAC()
	{
		if (readMACScanResult!=null)
		{
			// we keep a count of how many times we've attempted to read the MAC, because it really can fail sometimes
			// just set an upper limit so don't get stuck here forever
			if (readMACCounter<readMACCounterMaxAllowed)
			{
				if (bleReadMAC())
				{
					// started reading the MAC address
					readMACCounter++;
				}
				else
				{
					readMACScanResult = null;
				}
			}
			else
			{
				readMACScanResult = null;
			}
		}
	}
	
	// Called after successfully reading a MAC address from the currently paired bike (during scanning)
	function completeReadMAC(readMACArray)
	{
		if (readMACScanResult!=null)
		{
			// You are the device I'm looking for ...
			var foundDevice = (!mainView.lastLock || mainView.lastMACArray==null || sameMACArray(mainView.lastMACArray, readMACArray));
			if (foundDevice)
			{
				// store the MAC address into the user settings for next time
				mainView.saveLastMACAddress(readMACArray);
								
				// can stop scanning
				wantScanning = false;
				Ble.setScanState(Ble.SCAN_STATE_OFF);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING				

				state = State_Idle;
				connectedMACArray = readMACArray;	// remember the MAC address of whatever we've connected to
			}
			else
			{
				failedReadMACScan();	// or you're not the device I'm looking for ...
			}
		}
	}
	
	function failedReadMACScan()
	{
		if (readMACScanResult!=null)
		{
			addToScannedList(readMACScanResult);	// remember this device has been scanned and not to try connecting to it again
			readMACScanResult = null;		// clear this so a new device can be tested

	    	// unpair & disconnect from this device so we can try connecting to another instead
			bleDisconnect();
		}
	}
	
	var readMACScanResult = null;			// this is the scan result that we are currently reading the MAC address of (to determine if it is the correct bike)
	var readMACCounter = 0;					// number of times we have started reading MAC for the current readMACScanResult
	const readMACCounterMaxAllowed = 5;		// number of times we have started reading MAC for the current readMACScanResult

	function sameMACArray(a, b)	// pass in 2 byte arrays
	{
		if (a==null || b==null || a.size()!=b.size())
		{
			return false;
		}
		
		for (var i=0; i<a.size(); i++)
		{
			if (a[i] != b[i])
			{
				return false;
			}
		}
		
		return true;
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

        BleDelegate.initialize();

   		bleInitProfiles();
   		
   		startConnecting();
    }
    
    // called from compute of mainView
    function compute()
    {
		if (wantScanning!=currentScanning)
		{
			Ble.setScanState(wantScanning ? Ble.SCAN_STATE_SCANNING : Ble.SCAN_STATE_OFF);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING
		}

    	switch (state)
    	{
			case State_Connecting:		// scanning & pairing until we connect to the bike
			{
				// waiting for onScanResults() to be called
				// and for it to decide to pair to something
				//
    			// Maybe if scanning takes too long, then cancel it and try again in "a while"?
    			// When View.onShow() is next called? (If user can switch between different pages ...)
				break;
			}
			
			case State_Idle:	// connected, so now reading data as needed
			{
				// if there is no longer a paired device or it is not connected
				// then we have disconnected ...		
				var d = Ble.getPairedDevices().next();	// get first device (since we only connect to one at a time)
				if (d==null || !d.isConnected())
				{
					bleDisconnect();
					state = State_Disconnected;
				}
				else if (!waitingRead && !waitingWrite)
				{
					// do a read or write to the BLE device if we need to and nothing else is active
					if (wantReadBattery)
					{
						if (bleReadBattery())
						{
							wantReadBattery = false;	// since we've started reading it
							waitingRead = true;
						}
						else
						{
				    		mainView.values[1] = -1;		// read wouldn't start for some reason ...
						}
					}
					else if (wantNotifyMode!=currentNotifyMode)
					{
						writingNotifyMode = wantNotifyMode;
	    				if (bleWriteNotifications(writingNotifyMode))
	    				{
	    					waitingWrite = true;
	    				}
					}
				}
				break;
			}
			
			case State_Disconnected:
			{				
    			startConnecting();		// start scanning to connect again
				break;
			}
    	}
    }
    
	// 2 service ids are advertised (by EW-EN100)
	var advertised1ServiceUuid = Ble.stringToUuid("000018ff-5348-494d-414e-4f5f424c4500");	// we don't use this service (no idea what the data is)
	// lightblue phone app says the following service uuid is being advertised
	// but CIQ doesn't list it in the returned scan results, only the one above
	//var advertised2ServiceUuid = Ble.stringToUuid("000018ef-5348-494d-414e-4f5f424c4500");	// this service we also use to get notifications for mode
	
	var batteryServiceUuid = Ble.stringToUuid("0000180f-0000-1000-8000-00805f9b34fb");
	var batteryCharacteristicUuid = Ble.stringToUuid("00002a19-0000-1000-8000-00805f9b34fb");
	
	var modeServiceUuid = Ble.stringToUuid("000018ef-5348-494d-414e-4f5f424c4500");		// also used in advertising
	var modeCharacteristicUuid = Ble.stringToUuid("00002ac1-5348-494d-414e-4f5f424c4500");
	
	var MACServiceUuid = Ble.stringToUuid("000018fe-1212-efde-1523-785feabcd123");
	var MACCharacteristicUuid = Ble.stringToUuid("00002ae3-1212-efde-1523-785feabcd123");

	var profileRegisterSuccessCount = 0;
	var profileRegisterFailCount = 0;

	// scanResult.getRawData() returns this:
	// [3, 25, 128, 4, 2, 1, 5, 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, 5, 255, 74, 4, 1, 0]
	// Raw advertising data format: https://www.silabs.com/community/wireless/bluetooth/knowledge-base.entry.html/2017/02/10/bluetooth_advertisin-hGsf
	// And the data types: https://www.bluetooth.com/specifications/assigned-numbers/generic-access-profile/
	//
	// So decoding gives:
	// 3, 25, 128, 4, (25=appearance) 0x8004
	// 2, 1, 5, (1=flags)
	// 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, (6=Incomplete List of 128-bit Service Class UUIDs)
	//     (This in hex is 00 45 4c 42 5f 4f 4e 41 4d 49 48 53 ff 18 00 00, which matches 000018ff-5348-494d-414e-4f5f424c4500)
	// 5, 255, 74, 4, 1, 0 (255=Manufacturer Specific Data) (74 04 == Shimano BLE company id, which in decimal is 1098)
	//
	// Note that scanResult.getManufacturerSpecificData(1098) returns [1, 0]

    // set up the ble profiles we will use (CIQ allows up to 3 luckily ...) 
    function bleInitProfiles()
    {
		// read - battery
		var profile = {
			:uuid => batteryServiceUuid,
			:characteristics => [
				{
					:uuid => batteryCharacteristicUuid,
				}
			]
		};
		
		// notifications - mode, gear
		// is speed, distance, range, cadence anywhere in the data?
		// get 3 notifications continuously:
		// 1 = 02 XX 00 00 00 00 CB 28 00 00 (XX=02 is mode)
		// 2 = 03 B6 5A 36 00 B6 5A 36 00 CC 00 AC 02 2F 00 47 00 60 00
		// 3 = 00 00 00 FF FF YY 0B 80 80 80 0C F0 10 FF FF 0A 00 (YY=03 is gear if remember correctly)
		// Mode is 00=off 01=eco 02=trail 03=boost 04=walk 
		var profile2 = {
			:uuid => modeServiceUuid,
			:characteristics => [
				{
					:uuid => modeCharacteristicUuid,
					:descriptors => [Ble.cccdUuid()]	// for requesting notifications set to [1,0]?
				}
			]
		};
		
		// light blue displays MAC address as: C3 FC 37 79 B7 C2
		// which happens to match this!:
		// 000018fe-1212-efde-1523-785feabcd123
		// 00002ae3-1212-efde-1523-785feabcd123
		// C2 b7 79 37 fc c3
		// read - mac address
		var profile3 = {
			:uuid => MACServiceUuid,
			:characteristics => [
				{
					:uuid => MACCharacteristicUuid,
				}
			]
		};

		try
		{
    		Ble.registerProfile(profile);
    		Ble.registerProfile(profile2);
    		Ble.registerProfile(profile3);
		}
		catch (e)
		{
		    //System.println("catch = " + e.getErrorMessage());
		    //mainView.displayString = "err";
		}
    }
    
    function bleDisconnect()
    {
		var d = Ble.getPairedDevices().next();	// get first device (since we only connect to one at a time)
		if (d!=null)
		{
			Ble.unpairDevice(d);
		}
    }
    
    // tells the BLE device if we want mode/gear notifications on or off 
    function bleWriteNotifications(wantOn)
    {
       	var startedWrite = false;
    
    	// get first device (since we only connect to one at a time) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(modeServiceUuid);
				if (ds!=null)
				{
					var dsc = ds.getCharacteristic(modeCharacteristicUuid);
					if (dsc!=null)
					{
						var cccd = dsc.getDescriptor(Ble.cccdUuid());
						cccd.requestWrite([(wantOn?0x01:0x00), 0x00]b);
						startedWrite = true;
					}
				}
			}
			catch (e)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			}
		}
		
		return startedWrite;
	}
	
    function bleReadBattery()
    {
    	var startedRead = false;
    
    	// don't know if we can just keep calling requestRead() as often as we like without waiting for onCharacteristicRead() in between
    	// but it seems to work ...
    	// ... or maybe it doesn't, as always get a crash trying to call requestRead() after power off bike
    	// After adding code to wait for the read to finish before starting a new one, then the crash doesn't happen. 
    
    	// get first device (since we only connect to one at a time) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(batteryServiceUuid);
				if (ds!=null)
				{
					var dsc = ds.getCharacteristic(batteryCharacteristicUuid);
					if (dsc!=null)
					{
						dsc.requestRead();	// had one exception from this when turned off bike, and now a symbol not found error 'Failed invoking <symbol>'
						startedRead = true;
					}
				}
			}
			catch (e)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			}
		}

		return startedRead;
    }
    
    function bleReadMAC()
    {
    	var startedRead = false;
    
    	// get first device (since we only connect to one at a time) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(MACServiceUuid);
				if (ds!=null)
				{
					var dsc = ds.getCharacteristic(MACCharacteristicUuid);
					if (dsc!=null)
					{
						dsc.requestRead();
						startedRead = true;
					}
				}
			}
			catch (e)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			}
		}

		return startedRead;
    }
    
	function onProfileRegister(uuid, status)
	{
    	//System.println("onProfileRegister status=" + status);
       	//mainView.displayString = "reg" + status;
       	
       	if (status==Ble.STATUS_SUCCESS)
       	{
       		profileRegisterSuccessCount += 1;
       	}
       	else
       	{
			profileRegisterFailCount += 1;
       	}
	}

    function onScanStateChange(scanState, status)
    {
    	//System.println("onScanStateChange scanState=" + scanState + " status=" + status);
    	currentScanning = (scanState==Ble.SCAN_STATE_SCANNING);
    
		readMACScanResult = null;		// make sure this is cleared whether starting or ending scanning
		deleteScannedList();
    }
        
    private function iterContains(iter, obj)
    {
        for (var uuid=iter.next(); uuid!=null; uuid=iter.next())
        {
            if (uuid.equals(obj))
            {
                return true;
            }
        }

        return false;
    }

    var scannedList = [];				// array of scan results that have been tested and deemed not worthy of connecting to
    const maxScannedListSize = 10;		// choose a max size just in case

	function addToScannedList(r)
	{
		// if reached max size of scan list remove the first (oldest) one
		if (scannedList.size()>=maxScannedListSize)
		{
			scannedList = scannedList.slice(1, maxScannedListSize);  
		}
	
		// add new scan result to end of our scan list
		scannedList.add(r);
	}
	
	function deleteScannedList()
	{
    	scannedList = new[0];	// new zero length array
	}
	
	// If a scan is running this will be called when new ScanResults are received
    function onScanResults(scanResults)
    {
    	//System.println("onScanResults");

		if (!wantScanning)
		{
			return;
		}

		var newList = [];	// build array of new (unknown) devices to connect to

    	for (;;)
    	{
    		var r = scanResults.next();
    		if (r==null)
    		{
    			break;
    		}

      		if (iterContains(r.getServiceUuids(), advertised1ServiceUuid))	// check the advertised uuids to see if right sort of device
      		{
      			// see if it is a device we haven't checked before
				var newResult = true;
				
				for (var i=0; i<scannedList.size(); i++)
				{
					if (r.isSameDevice(scannedList[i]))
					{
						scannedList[i] = r;		// update the scan info
						newResult = false;
						break;
					}
				}
				
				if (newResult)
				{
					newList.add(r);
				}
			}
		}
		
		if (readMACScanResult==null && newList.size()>0)	// not already checking the MAC address of a device
		{
			// find the new device which has the strongest signal
			var bestI = 0;
			var bestRssi = newList[0].getRssi();
			
	    	for (var i=1; i<newList.size(); i++)
	    	{
	    		var rssi = newList[i].getRssi();
	    		if (rssi>bestRssi)
	    		{
	   				bestI = i;
	   				bestRssi = rssi;
	   			}
	   		}

			// lets try pairing to this device so we can check its MAC address
			readMACScanResult = newList[bestI];
			readMACCounter = 0;
  			var d = Ble.pairDevice(readMACScanResult);
  			if (d!=null)
  			{
  				// it seems that sometimes after pairing onConnectedStateChanged() is not always called
  				// - checking isConnected() here immediately seems to avoid that case happening.
  				if (d.isConnected())
  				{
  					startReadingMAC();
  				}
  				
 				//mainView.displayString = "paired " + d.getName();
  			}
  			else
  			{
				readMACScanResult = null;
  			}
		}
    }

	// After pairing a device this will be called after the connection is made.
	// (But seemingly not sometimes ... maybe if still connected from previous run of datafield?)
	function onConnectedStateChanged(device, connectionState)
	{
		if (connectionState==Ble.CONNECTION_STATE_CONNECTED)
		{
			startReadingMAC();
		}
	}
	
	// After requesting a read operation on a characteristic using Characteristic.requestRead() this function will be called when the operation is completed.
	function onCharacteristicRead(characteristic, status, value)
	{
		if (characteristic.getUuid().equals(batteryCharacteristicUuid))
		{
			if (value!=null && value.size()>0)		// (had this return a zero length array once ...)
			{
				mainView.values[1] = value[0].toNumber();	// value is a byte array
			}
		}
		else if (characteristic.getUuid().equals(MACCharacteristicUuid))
		{
			if (status==Ble.STATUS_SUCCESS)
			{
				if (value!=null && value.size()>0)
				{
					completeReadMAC(value.reverse());	// reverse array order to properly match real MAC address as reported by phone
				}
				else
				{
					failedReadMACScan();
				}
			}
			else
			{
				startReadingMAC();	// try reading the MAC address again
			}
		}
		
		waitingRead = false;
	}

	// After requesting a write operation on a descriptor using Descriptor.requestWrite() this function will be called when the operation is completed.
	function onDescriptorWrite(descriptor, status)
	{ 
		var cd = descriptor.getCharacteristic();
		if (cd!=null && cd.getUuid().equals(modeCharacteristicUuid))
		{
			if (status==Ble.STATUS_SUCCESS)
			{
				currentNotifyMode = writingNotifyMode;
			}
		}
		
		waitingWrite = false;
	}

	// After enabling notifications or indications on a characteristic (by enabling the appropriate bit of the CCCD of the characteristic)
	// this function will be called after every change to the characteristic.
	function onCharacteristicChanged(characteristic, value)
	{
		if (characteristic.getUuid().equals(modeCharacteristicUuid))
		{
			if (value!=null)
			{
				// value is a byte array
				if (value.size()==10)	// we want the one which is 10 bytes long (out of the 3 that Shimano seem to spam ...)
				{
					// mode
					mainView.values[3] = value[1].toNumber();	// and it is the 2nd byte of the array
					// cadence
					mainView.values[7] = value[5].toNumber();
					// assistance level
					mainView.values[8] = value[4].toNumber();
					// speed
					mainView.values[9] = ((value[3] << 8) | value[2]).toFloat()/10;
				}
				else if (value.size()==17)
				{
					// gear
					mainView.values[6] = value[5].toNumber();
				}
			}
		}
	}
}

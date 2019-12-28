using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.BluetoothLowEnergy as Ble;
using Toybox.Application;
using Application.Properties as applicationProperties;
using Application.Storage as applicationStorage;

//class emtbView extends WatchUi.DataField
//DataField.initialize();
//
// This version is easier for testing/developing and for displaying (multiple) long strings
class baseView2 extends WatchUi.DataField
{
	var displayString = "";
	
    function initialize()
    {
        DataField.initialize();
    }

    function setLabelInInitialize(s)
    {
    	// do nothing - must be drawn by subclass
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc)
    {
		//var obscurityFlags = DataField.getObscurityFlags();
		//if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT))
		//{
		//}
		//else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT))
		//{
		//}
		//else
		//{
		//}

        return true;
    }

    function compute(info)
    {
    	// do nothing
   	}

    // Display the value you computed here. This will be called once a second when the data field is visible.
    function onUpdate(dc)
    {
        dc.setColor(Graphics.COLOR_TRANSPARENT, getBackgroundColor());
        dc.clear();

        dc.setColor((getBackgroundColor()==Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

		var s = Graphics.fitTextToArea(displayString, Graphics.FONT_SYSTEM_XTINY, 200, 240, true);
        dc.drawText(120, 120, Graphics.FONT_SYSTEM_XTINY, s, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

//
// or use
//

//class emtbView extends WatchUi.SimpleDataField
//SimpleDataField.initialize();
//label = "some string";
//
// get rid of onLayout() and onUpdate()
// and just return a value from compute() which will be displayed for us ... 
//
// This version is easier for releasing as don't need to worry about all display formats for all devices
class baseView extends WatchUi.SimpleDataField
{
	var displayString = "";
	
    function initialize()
    {
        SimpleDataField.initialize();

    	//label = "Wheee";		// seems this has to be set in initialize() and can't be changed later
    }
    
    function setLabelInInitialize(s)
    {
    	label = s;
    }

    function compute(info)
    {
    	return displayString;
   	}
}

class emtbView extends baseView
{
	var thisView;
	var bleHandler;
	
	var showBattery = true;
	var showMode = false;
	var lastLock = false;
	var lastMAC = "";

	var batteryValue = -1;
	var modeValue = -1;

	var modeNames = [
		"Off",
		"Eco",
		"Trail",
		"Boost",
		"Walk",
	];
	
	function propertiesGetBoolean(p)
	{
		var v = applicationProperties.getValue(p);
		if ((v == null) || !(v instanceof Boolean))
		{
			v = false;
		}
		return v;
	}
	
	function propertiesGetString(p)
	{	
		var v = applicationProperties.getValue(p);
		if (v == null)
		{
			v = "";
		}
		else if (!(v instanceof String))
		{
			v = v.toString();
		}
		return v;
	}

	function getSettings()
	{
    	showBattery = propertiesGetBoolean("ShowBattery");
    	showMode = propertiesGetBoolean("ShowMode");
    	
		lastLock = propertiesGetBoolean("LastLock");
		lastMAC = propertiesGetString("LastMAC");
		
		// if lastLock or lastMAC get changed dynamically while the field is running
		// then should really handle it in some way - but we don't for now!
	}

    function initialize()
    {
        baseView.initialize();
        
		// label can only be set in initialize so don't bother storing it
		setLabelInInitialize(propertiesGetString("Label"));

		getSettings();
    }

	// called by app when settings change
	function onSettingsChanged()
	{
		getSettings();
	
    	WatchUi.requestUpdate();   // update the view to reflect changes
	}

	function setSelf(theView)
	{
		thisView = theView;

        setupBle();
	}
	
	function setupBle()
	{
    	bleHandler = new emtbDelegate(thisView);
		Ble.setDelegate(bleHandler);
	}

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info)
    {
		bleHandler.compute();
		
		// create the string to display to user
   		displayString = "";

		// could show status of scanning & pairing if we wanted
		//if (bleHandler.state==bleHandler.bleState_Read)

    	if (showBattery)
    	{
    		displayString += ((batteryValue>=0) ? batteryValue.toNumber() : "--") + "%";
    	}
    
    	if (showMode)
   		{
   			if (displayString.length()>0)
   			{
   				displayString += " ";
   			}

			if (modeValue>=0 && modeValue<modeNames.size())
			{
    			displayString += modeNames[modeValue];
			}
			else
			{
    			displayString += "----";
			}
    	}
		       
		return baseView.compute(info);	// if a SimpleDataField then this will return the string/value to display
    }
}

class emtbDelegate extends Ble.BleDelegate
{
	var mainView;

	enum
	{
		bleState_Init = 0,
		bleState_Scan,
		bleState_Pair,
		bleState_Read,
		bleState_ReadWait,
		bleState_Disconnected,
	}
	
	var state = bleState_Init;
	
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
	
    function initialize(theView)
    {
        mainView = theView;

        BleDelegate.initialize();
    }
    
    // set up the ble profiles we will use (CIQ allows up to 3 luckily ...) 
    function bleInit()
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
		var profile2 = {
			:uuid => modeServiceUuid,
			:characteristics => [
				{
					:uuid => modeCharacteristicUuid,
					:descriptors => [Ble.cccdUuid()]	// for requesting notifications
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
		catch (e instanceof Lang.Exception)
		{
		    //System.println("catch = " + e.getErrorMessage());
		    //mainView.displayString = "err";
		}
    }
    
    function bleReadBattery()
    {
    	// don't know if we can just keep calling requestRead() as often as we like without waiting for onCharacteristicRead() in between
    	// but it seems to work ...
    	// ... or maybe it doesn't, as always get a crash trying to call requestRead() if power off bike
    	// After adding code to wait for the read to finish before starting a new one, then the crash doesn't happen. 
    
    	// get first device (since we only connect to one) and check it is connected
		var d = Ble.getPairedDevices().next();
		if (d!=null && d.isConnected())
		{
			try
			{
				var ds = d.getService(batteryServiceUuid);
				if (ds!=null && (ds has :getCharacteristic))
				{
					var dsc = ds.getCharacteristic(batteryCharacteristicUuid);
					if (dsc!=null && (dsc has :requestRead))
					{
						dsc.requestRead();	// had one exception from this when turned off bike, and now a symbol not found error 'Failed invoking <symbol>'
					}
				}
			}
			catch (e instanceof Lang.Exception)
			{
			    //System.println("catch = " + e.getErrorMessage());			    
			    mainView.batteryValue = -1;
			}
		}
    }
    
    // called from compute of mainView
    function compute()
    {
    	// "paired"?
    	// BLE get values
    	// BLE handle disconnected?
    
    	switch (state)
    	{
			case bleState_Init:
			{
        		bleInit();	// also works to call this directly at end of initialize()
        		
        		// and then start scanning
        		state = bleState_Scan;
        		Ble.setScanState(Ble.SCAN_STATE_SCANNING);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING
				break;
			}
			
			case bleState_Scan:
			{
				// waiting for onScanResults() to be called
				// and for it to decide to pair to something
				//
    			// if scanning takes too long, then cancel it and try again in "a while"?
    			// When View.onShow() is next called? (If user can switch between different pages ...)
    			mainView.batteryValue = 101;
				break;
			}
			
			case bleState_Pair:
			{
				// waiting for pair to complete and onConnectedStateChanged() to be called
				break;
			}
			
			case bleState_Read:
			{
				bleReadBattery();
				state = bleState_ReadWait;
				break;
			}
			
			case bleState_ReadWait:
			{
				break;
			}
			
			case bleState_Disconnected:
			{
				mainView.batteryValue = -1;
				mainView.modeValue = -1;
				
    			mainView.batteryValue = 104;
    			
    			state = bleState_Scan;	// start scanning again
				break;
			}
    	}
    }
    
	function onProfileRegister(uuid, status)
	{
    	//System.println("onProfileRegister status=" + status);
       	//mainView.displayString = "reg" + status;
	}

    function onScanStateChange(scanState, status)
    { 
    	//System.println("onScanStateChange scanState=" + scanState + " status=" + status);
    }
    
//    var rList = [];
    
    private function contains(iter, obj)
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

    function onScanResults(scanResults)
    {
    	//System.println("onScanResults");
    
    	for (;;)
    	{
    		var r = scanResults.next();
    		if (r==null)
    		{
    			break;
    		}

			// check the advertised uuids to see if right sort of device
      		if (contains(r.getServiceUuids(), advertised1ServiceUuid))
      		{
    			state = bleState_Pair;
    			mainView.batteryValue = 102;
    			
      			var d = Ble.pairDevice(r);
      			if (d!=null)
      			{
      				// it seems that sometimes after pairing onConnectedStateChanged() is not always called
      				// - checking isConnected() here immediately seems to avoid that case happening.
      				if (d.isConnected())
      				{
			 			state = bleState_Read;
			   			mainView.batteryValue = 113;
      				}
      				
     				//mainView.displayString = "paired " + d.getName();

	    			Ble.setScanState(Ble.SCAN_STATE_OFF);	// Ble.SCAN_STATE_OFF, Ble.SCAN_STATE_SCANNING
      			}
      			else
      			{
     				//mainView.displayString = "not";
    				state = bleState_Scan;
      			}
      			
      			break;
      		}
    	}
    	
//    	for (;;)
//    	{
//    		var r = scanResults.next();
//    		if (r==null)
//    		{
//    			break;
//    		}
//    		
//    		var rNew = true;
//    		for (var i=0; i<rList.size(); i++)
//    		{
//    			if (r.isSameDevice(rList[i]))
//    			{
//    				rList[i] = r;
//    				rNew = false;
//    				break;
//    			}
//    		}
//    		
//    		if (rNew)
//    		{
//    			rList.add(r);
//    		}
//       	}
//
//		var bestI = -1;
//		var bestRssi = -999;
//		
//    	for (var i=0; i<rList.size(); i++)
//    	{
//    		var rssi = rList[i].getRssi();
//    		if (bestI<0 || rssi>bestRssi)
//    		{
//   				bestI = i;
//   				bestRssi = rssi;
//   			}
//   		}
//
//		if (bestI>=0)
//		{
//			mainView.displayString = "" + rList.size() + " " + rList[bestI].getRssi();
//
//    		var s = rList[bestI].getDeviceName();
//    		if (s!=null)
//    		{
//    			mainView.displayString += s;
//    		}
//    		
////    		var iter = rList[bestI].getServiceUuids();
////    		if (iter!=null)
////    		{
////    			var u = iter.next();
////    			if (u!=null)
////    			{
////    				mainView.displayString += u.toString();
////    			}
////    		}    		
//    		
////    		//var data = rList[bestI].getManufacturerSpecificData(1098);		// [1, 0]
////    		var data = rList[bestI].getRawData();			// [3, 25, 128, 4, 2, 1, 5, 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, 5, 255, 74, 4, 1, 0]
////    														// 3, 25, 128, 4, (25=appearance) 0x8004
////    														// 2, 1, 5, (1=flags)
////    														// 17, 6, 0, 69, 76, 66, 95, 79, 78, 65, 77, 73, 72, 83, 255, 24, 0, 0, (6=Incomplete List of 128-bit Service Class UUIDs)
////    														// 5, 255, 74, 4, 1, 0 (255=Manufacturer Specific Data) (74 4 == Shimano)
////    		if (data!=null)
////    		{
////   				mainView.displayString += data.toString();
////    		}
//		}
//		else
//		{
//			mainView.displayString = "none";
//		}
    }

	function onConnectedStateChanged(device, connectionState)
	{
		if (connectionState==Ble.CONNECTION_STATE_CONNECTED)
		{
			state = bleState_Read;
   			mainView.batteryValue = 103;
		}
		else if (connectionState==Ble.CONNECTION_STATE_DISCONNECTED)
		{
			state = bleState_Disconnected;
		}
	}
	
	function onCharacteristicRead(characteristic, status, value)
	{
		if (characteristic.getUuid().equals(batteryCharacteristicUuid))
		{
			if (value!=null)
			{
				mainView.batteryValue = value[0].toNumber();
			}
		}
		
		if (state==bleState_ReadWait)
		{
			state = bleState_Read;
		} 
	}
}

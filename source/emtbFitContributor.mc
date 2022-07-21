using Toybox.FitContributor as Fit;
using Toybox.Lang;
using Toybox.WatchUi;


class emtbFitContributor {
	
	// Field ids
    private const FIELD_BATTERY = 0;
    private const FIELD_CADENCE = 1;
    private const FIELD_ASSISTANCE_LEVEL = 2;
    private const FIELD_CONSUMED_BATTERY = 3;

    private var _timerRunning as Boolean = false;
    private var _firstBatteryValue = -1;

    // FIT Contributions variables
    private var _batteryField;
    private var _cadenceField;
    private var _assistanceLevelField;
    private var _consumedBatteryField;

	//! Constructor
    //! @param dataField Data field to use to create fields
    public function initialize(emtbField as emtbView) {
    	System.println(emtbField.toString());

    	// Create the custom FIT data field we want to record
        _batteryField = emtbField.createField(
            WatchUi.loadResource(Rez.Strings.BatteryField),
            FIELD_BATTERY,
            Fit.DATA_TYPE_UINT8,
            {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>WatchUi.loadResource(Rez.Strings.BatteryUnitField)}
        );

        _cadenceField = emtbField.createField(
            WatchUi.loadResource(Rez.Strings.CadenceField),
            FIELD_CADENCE,
            Fit.DATA_TYPE_UINT8,
            {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>WatchUi.loadResource(Rez.Strings.CadenceUnitField)}
        );

        _assistanceLevelField = emtbField.createField(
            WatchUi.loadResource(Rez.Strings.AssistanceLevelField),
            FIELD_ASSISTANCE_LEVEL,
            Fit.DATA_TYPE_UINT8,
            {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>WatchUi.loadResource(Rez.Strings.AssistanceLevelUnitField)}
        );

        _consumedBatteryField = emtbField.createField(
            WatchUi.loadResource(Rez.Strings.ConsumedBatteryField),
            FIELD_CONSUMED_BATTERY,
            Fit.DATA_TYPE_UINT8,
            {:mesgType=>Fit.MESG_TYPE_SESSION, :units=>WatchUi.loadResource(Rez.Strings.BatteryUnitField)}
        );


        _batteryField.setData(0);
        _cadenceField.setData(0);
        _assistanceLevelField.setData(0);
        _consumedBatteryField.setData(0);
    }

    //! Update data and fields
    //! @param battery level, cadence and assistance value
    public function update(battery, cadence, assistanceLevel) as Void {
    	System.println("Updating fit...");

        if (_timerRunning) {
        	// Update fields
        	_batteryField.setData(battery);
        	_cadenceField.setData(cadence);
        	_assistanceLevelField.setData(assistanceLevel);

        	if (_firstBatteryValue == -1 && battery > 0)
    		{
    			_firstBatteryValue = battery;
    		}
    		
    		_consumedBatteryField.setData(_firstBatteryValue - battery);
        }
    }

    //! Set whether the timer is running
    //! @param state Whether the timer is running
    public function setTimerRunning(state as Boolean) as Void {
        _timerRunning = state;
    }
}
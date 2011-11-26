package com.github.ignition.location.tests;

import static junit.framework.Assert.assertEquals;
import static junit.framework.Assert.assertNotNull;
import static junit.framework.Assert.assertTrue;

import java.util.List;

import junit.framework.Assert;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;

import com.github.ignition.location.IgnitedLocationConstants;
import com.github.ignition.samples.IgnitedLocationSampleActivity;
import com.xtremelabs.robolectric.Robolectric;
import com.xtremelabs.robolectric.shadows.ShadowActivity;
import com.xtremelabs.robolectric.shadows.ShadowApplication;
import com.xtremelabs.robolectric.shadows.ShadowApplication.Wrapper;
import com.xtremelabs.robolectric.shadows.ShadowLocationManager;

@RunWith(LocationTestsRobolectricTestRunner.class)
public class IgnitedLocationManagerTest {
    private IgnitedLocationSampleActivity activity;
    private ShadowApplication shadowApp;
    private ShadowLocationManager shadowLocationManager;

    @Before
    public void setUp() throws Exception {
        activity = new IgnitedLocationSampleActivity();
        shadowApp = Robolectric.getShadowApplication();
        shadowLocationManager = Robolectric.shadowOf((LocationManager) activity
                .getSystemService(Context.LOCATION_SERVICE));
        Location lastKnownLocation = getLocation();
        shadowLocationManager.setProviderEnabled(LocationManager.GPS_PROVIDER, true);
        shadowLocationManager.setProviderEnabled(LocationManager.NETWORK_PROVIDER, true);
        shadowLocationManager.setLastKnownLocation(LocationManager.GPS_PROVIDER, lastKnownLocation);
        activity.onCreate(null);
    }

    @After
    public void tearDown() throws Exception {
        if (!activity.isFinishing()) {
            finish();
        }
    }

    private Location getLocation() {
        Location location = new Location(LocationManager.GPS_PROVIDER);
        location.setLatitude(1.0);
        location.setLongitude(1.0);
        return location;
    }

    private Location sendMockLocationBroadcast(String provider) {
        Intent intent = new Intent(IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_ACTION);
        Location location = new Location(provider);
        location.setLatitude(2.0);
        location.setLongitude(2.0);
        intent.putExtra(LocationManager.KEY_LOCATION_CHANGED, location);
        shadowApp.sendBroadcast(intent);

        return location;
    }

    @Test
    public void ignitedLocationIsCurrentLocation() {
        resume();

        assertEquals(getLocation(), activity.getCurrentLocation());
        Location newLocation = sendMockLocationBroadcast(LocationManager.GPS_PROVIDER);
        assertEquals(newLocation, activity.getCurrentLocation());
    }

    @Test
    public void activelyRequestLocationUpdatesOnResume() {
        resume();

        List<Wrapper> receivers = shadowApp.getRegisteredReceivers();
        assertNotNull(receivers);
        for (Wrapper receiver : receivers) {
            if (receiver.intentFilter.getAction(0).equals(IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_ACTION)) {
                break;
            }
            Assert.fail();
        }
    }

    // TODO: find a better way to test this. Now the activity must be resumed twice or an Exception
    // will be thrown because one of the receivers is not registered.
    @Test
    public void noReceiverRegisteredOnPause() throws Exception {
        resume();
        activity.onPause();

        ShadowActivity shadowActivity = Robolectric.shadowOf(activity);
        shadowActivity.assertNoBroadcastListenersRegistered();

        resume();
    }

    // @Test
    // public void testNoTaskRunningOnFinish() {
    // resume();
    // finish();
    // }

    @Test
    public void ignitedLocationSettingsAreSavedToPreferences() {
        resume();

        SharedPreferences pref = activity.getSharedPreferences(IgnitedLocationConstants.SHARED_PREFERENCE_FILE,
                Context.MODE_PRIVATE);
        boolean followLocationChanges = pref.getBoolean(IgnitedLocationConstants.SP_KEY_FOLLOW_LOCATION_CHANGES, true);
        boolean runOnce = pref.getBoolean(IgnitedLocationConstants.SP_KEY_RUN_ONCE, true);
        int locUpdatesDistDiff = pref.getInt(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_DISTANCE_DIFF,
                IgnitedLocationConstants.LOCATION_UPDATES_DISTANCE_DIFF);
        long locUpdatesInterval = pref.getLong(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_INTERVAL,
                IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_INTERVAL);
        int passiveLocUpdatesDistDiff = pref.getInt(
                IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF,
                IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF);
        long passiveLocUpdatesInterval = pref.getLong(
                IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_INTERVAL,
                IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_INTERVAL);

        assertTrue(followLocationChanges);
        assertTrue(runOnce);

        assertEquals(IgnitedLocationConstants.LOCATION_UPDATES_DISTANCE_DIFF, locUpdatesDistDiff);
        assertEquals(IgnitedLocationConstants.LOCATION_UPDATES_INTERVAL, locUpdatesInterval);
        assertEquals(IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF, passiveLocUpdatesDistDiff);
        assertEquals(IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_INTERVAL, passiveLocUpdatesInterval);
    }

    @Test
    public void shouldRegisterListenerIfBestProviderDisabled() {
        shadowLocationManager.setBestDisabledProvider(LocationManager.GPS_PROVIDER);
        shadowLocationManager.setProviderEnabled(LocationManager.GPS_PROVIDER, false);
        shadowLocationManager.setBestEnabledProvider(LocationManager.NETWORK_PROVIDER);

        resume();

        List<LocationListener> listeners = shadowLocationManager.getRequestLocationUpdateListeners();
        assertTrue(!listeners.isEmpty());
    }

    @Test
    public void shouldNotRegisterListenerIfBestProviderEnabled() {
        shadowLocationManager.setBestEnabledProvider(LocationManager.GPS_PROVIDER);
        shadowLocationManager.setBestDisabledProvider(LocationManager.GPS_PROVIDER);
        shadowLocationManager.setProviderEnabled(LocationManager.GPS_PROVIDER, true);

        resume();

        List<LocationListener> listeners = shadowLocationManager.getRequestLocationUpdateListeners();
        assertNotNull(listeners);
    }

    @Test
    public void shouldRegisterLocationProviderDisabledReceiver() {
        resume();

        List<Wrapper> receivers = shadowApp.getRegisteredReceivers();
        assertNotNull(receivers);
        for (Wrapper receiver : receivers) {
            if (receiver.intentFilter.getAction(0).equals(
                    IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_PROVIDER_DISABLED_ACTION)) {
                break;
            }
            Assert.fail("Provider Disabled Receiver not registered");
        }
    }

    // @Test
    // public void requestLocationUpdatesFromAnotherProviderIfCurrentOneIsDisabled() {
    // // TODO
    // }

    @Test
    public void shouldUpdateDataOnNewLocation() {
        resume();

        int countBefore = activity.getAdapter().getCount();
        sendMockLocationBroadcast(LocationManager.GPS_PROVIDER);
        int countAfter = activity.getAdapter().getCount();
        assertTrue(countAfter == ++countBefore);
    }

    private void finish() {
        activity.finish();
        activity.onPause();
        activity.onStop();
        activity.onDestroy();
    }

    private void resume() {
        activity.onStart();
        activity.onResume();
    }
}
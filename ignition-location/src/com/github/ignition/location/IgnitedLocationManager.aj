/*
 * Copyright 2011 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * This code has been modified by Stefano Dacchille.
 */

package com.github.ignition.location;

import org.aspectj.lang.annotation.SuppressAjWarnings;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.location.Criteria;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.AsyncTask;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;

import com.github.ignition.location.annotations.IgnitedLocation;
import com.github.ignition.location.annotations.IgnitedLocationActivity;
import com.github.ignition.location.receivers.IgnitedLocationChangedReceiver;
import com.github.ignition.location.receivers.IgnitedPassiveLocationChangedReceiver;
import com.github.ignition.location.tasks.IgnitedLastKnownLocationAsyncTask;
import com.github.ignition.location.templates.ILastLocationFinder;
import com.github.ignition.location.templates.LocationUpdateRequester;
import com.github.ignition.location.templates.OnIgnitedLocationChangedListener;
import com.github.ignition.location.utils.PlatformSpecificImplementationFactory;
import com.github.ignition.support.IgnitedDiagnostics;

@SuppressAjWarnings
public aspect IgnitedLocationManager {
    public static final String LOG_TAG = IgnitedLocationManager.class.getSimpleName();

    declare parents : (@IgnitedLocationActivity *) implements OnIgnitedLocationChangedListener;

    protected Criteria criteria;
    protected LocationUpdateRequester locationUpdateRequester;
    protected PendingIntent locationListenerPendingIntent, locationListenerPassivePendingIntent;
    protected LocationManager locationManager;
    protected IgnitedLocationListener bestInactiveLocationProviderListener;

    private Context context;
    private volatile Location currentLocation;
    private long locationUpdatesInterval, passiveLocationUpdatesInterval;
    private int locationUpdatesDistanceDiff, passiveLocationUpdatesDistanceDiff;
    private boolean refreshDataIfLocationChanges;
    private boolean locationUpdatesDisabled = true;

    private AsyncTask<Void, Void, Location> ignitedLastKnownLocationTask;
    private SharedPreferences prefs;
    private Handler handler;

    // Switch to another provider if gps doesn't return a location quickly enough.
    private Runnable removeGpsUpdates = new Runnable() {
        @Override
        public void run() {
            Log.d(LOG_TAG,
                    "It looks like GPS isn't working properly (maybe you're indoors or...?). Removing location updates from GPS.");

            Criteria criteria = new Criteria();
            criteria.setPowerRequirement(Criteria.POWER_LOW);
            criteria.setAccuracy(Criteria.NO_REQUIREMENT);

            requestLocationUpdates(context, criteria);
        }
    };

    /**
     * If the Location Provider we're using to receive location updates is disabled while the app is
     * running, this Receiver will be notified, allowing us to re-register our Location Receivers
     * using the best available Location Provider is still available.
     */
    protected BroadcastReceiver locProviderDisabledReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            boolean providerDisabled = !intent.getBooleanExtra(
                    LocationManager.KEY_PROVIDER_ENABLED, false);
            // Re-register the location listeners using the best available
            // Location Provider.
            if (providerDisabled) {
                requestLocationUpdates(context);
            }
        }
    };

    after(Context context, IgnitedLocationActivity ignitedAnnotation) : 
        execution(* Activity.onCreate(..)) && this(context)
        && @this(ignitedAnnotation) && within(@IgnitedLocationActivity *) {

        // Get a reference to the Context
        this.context = context;
        // Set pref file
        prefs = context.getSharedPreferences(IgnitedLocationConstants.SHARED_PREFERENCE_FILE,
                Context.MODE_PRIVATE);
        // Get references to the managers
        locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        handler = new Handler();

        criteria = buildCriteria();

        // Setup the location update Pending Intents
        Intent activeIntent = new Intent(IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_ACTION);
        locationListenerPendingIntent = PendingIntent.getBroadcast(context, 0, activeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT);

        Intent passiveIntent = new Intent(context, IgnitedPassiveLocationChangedReceiver.class);
        locationListenerPassivePendingIntent = PendingIntent.getBroadcast(context, 0,
                passiveIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        // Instantiate a Location Update Requester class based on the available
        // platform version. This will be used to request location updates.
        locationUpdateRequester = PlatformSpecificImplementationFactory
                .getLocationUpdateRequester(context);
    }

    private Criteria buildCriteria() {
        // Specify the Criteria to use when requesting location updates while
        // the application is Active
        Criteria criteria = new Criteria();

        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        Intent intent = context.registerReceiver(null, filter);
        double currentLevel = 100.0;
        if (intent != null) {
            currentLevel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        }

        // Use gps if it's enabled and if battery level is at least 15%
        boolean useGps = prefs.getBoolean(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_USE_GPS,
                IgnitedLocationConstants.USE_GPS)
                && currentLevel >= IgnitedLocationConstants.ACCEPTABLE_BATTERY_LEVEL_TO_USE_GPS;

        if (useGps) {
            criteria.setAccuracy(Criteria.ACCURACY_FINE);
            criteria.setPowerRequirement(Criteria.NO_REQUIREMENT);
        } else {
            criteria.setPowerRequirement(Criteria.POWER_LOW);
            criteria.setAccuracy(Criteria.NO_REQUIREMENT);
        }

        return criteria;
    }

    before(Context context, IgnitedLocationActivity ignitedAnnotation) : 
        execution(* Activity.onResume(..)) && this(context)
        && @this(ignitedAnnotation) && within(@IgnitedLocationActivity *) {
        // Get a reference to the Context if this context is null
        if (this.context == null) {
            this.context = context;
        }
        refreshDataIfLocationChanges = ignitedAnnotation.requestLocationUpdates();

        saveToPreferences(context, ignitedAnnotation);

        if (currentLocation == null) {
            Log.d(LOG_TAG, "Retrieving last known location...");
            // Get the last known location. This isn't directly affecting the UI, so put it on a
            // worker thread.
            ignitedLastKnownLocationTask = new IgnitedLastKnownLocationAsyncTask(
                    context.getApplicationContext(), locationUpdatesDistanceDiff,
                    locationUpdatesInterval);
            ignitedLastKnownLocationTask.execute();
        } else {
            requestLocationUpdates(context);
        }
    }

    /**
     * Save last settings to preferences.
     * 
     * @param context
     * @param locationAnnotation
     */
    private void saveToPreferences(Context context, IgnitedLocationActivity locationAnnotation) {
        locationUpdatesDistanceDiff = locationAnnotation.locationUpdatesDistanceDiff();
        locationUpdatesInterval = locationAnnotation.locationUpdatesInterval();
        passiveLocationUpdatesDistanceDiff = locationAnnotation
                .passiveLocationUpdatesDistanceDiff();
        passiveLocationUpdatesInterval = locationAnnotation.passiveLocationUpdatesInterval();
        boolean enablePassiveLocationUpdates = locationAnnotation.enablePassiveUpdates();
        boolean useGps = locationAnnotation.useGps();

        Editor editor = prefs.edit();
        editor.putBoolean(IgnitedLocationConstants.SP_KEY_FOLLOW_LOCATION_CHANGES,
                enablePassiveLocationUpdates);
        editor.putBoolean(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_USE_GPS, useGps);
        editor.putInt(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_DISTANCE_DIFF,
                locationUpdatesDistanceDiff);
        editor.putLong(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_INTERVAL,
                locationUpdatesInterval);
        editor.putInt(IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF,
                passiveLocationUpdatesDistanceDiff);
        editor.putLong(IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_INTERVAL,
                passiveLocationUpdatesInterval);
        editor.putBoolean(IgnitedLocationConstants.SP_KEY_RUN_ONCE, true);
        editor.commit();

    }

    after(Activity activity, IgnitedLocationActivity ignitedAnnotation) : execution(* Activity.onPause(..)) 
        && @this(ignitedAnnotation) && this(activity)
        && within(@IgnitedLocationActivity *) && if (ignitedAnnotation.requestLocationUpdates()) {

        boolean finishing = activity.isFinishing();
        disableLocationUpdates(context, finishing);

        handler.removeCallbacks(removeGpsUpdates);

        if (finishing) {
            context = null;
        }
    }

    // after() : execution(* Activity.onDestroy(..)) && @this(IgnitedLocationActivity)
    // && within(@IgnitedLocationActivity *) {
    // }

    Location around() : get(@IgnitedLocation Location *) {
        return currentLocation;
    }

    void around(Location freshLocation) : set(@IgnitedLocation Location *) && args(freshLocation) 
        && within(IgnitedPassiveLocationChangedReceiver) && !adviceexecution() {

        currentLocation = freshLocation;
        Log.d(LOG_TAG, "New location from " + currentLocation.getProvider() + " (lat, long): "
                + currentLocation.getLatitude() + ", " + currentLocation.getLongitude());
        if (context != null) {
            ((OnIgnitedLocationChangedListener) context).onIgnitedLocationChanged(currentLocation);
        }
    }

    void around(Location freshLocation) : set(@IgnitedLocation Location *) && args(freshLocation) 
        && (within(IgnitedLocationChangedReceiver) || within(com.github.ignition.location.utils.*)
                || within(IgnitedLastKnownLocationAsyncTask)) && !adviceexecution() {

        currentLocation = freshLocation;
        Log.d(LOG_TAG, "New location from " + currentLocation.getProvider() + " (lat, long): "
                + currentLocation.getLatitude() + ", " + currentLocation.getLongitude());
        if (context != null) {
            boolean keepRequestingLocationUpdates = ((OnIgnitedLocationChangedListener) context)
                    .onIgnitedLocationChanged(currentLocation);
            if (!keepRequestingLocationUpdates && !locationUpdatesDisabled) {
                locationUpdateRequester.removeLocationUpdates();
            } else if (refreshDataIfLocationChanges
                    && locationUpdatesDisabled
                    && !freshLocation.getExtras().containsKey(
                            ILastLocationFinder.LAST_LOCATION_TOO_OLD_EXTRA)) {
                // If we have requested location updates, turn them on here.
                requestLocationUpdates(context);
            }
        }

        // If gps is enabled location comes from gps, remove runnable that removes gps updates
        if (criteria.getAccuracy() == Criteria.ACCURACY_FINE
                && currentLocation.getProvider().equals(LocationManager.GPS_PROVIDER)) {
            handler.removeCallbacks(removeGpsUpdates);
        }
    }

    protected void requestLocationUpdates(Context context) {
        requestLocationUpdates(context, criteria);
    }

    /**
     * Start listening for location updates.
     */
    protected void requestLocationUpdates(Context context, Criteria criteria) {
        Log.d(LOG_TAG, "requesting location updates...");
        // Normal updates while activity is visible.
        locationUpdateRequester.requestLocationUpdates(locationUpdatesInterval,
                locationUpdatesDistanceDiff, criteria, locationListenerPendingIntent);

        // Register a receiver that listens for when the provider I'm using has
        // been disabled.
        IntentFilter intentFilter = new IntentFilter(
                IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_PROVIDER_DISABLED_ACTION);
        context.registerReceiver(locProviderDisabledReceiver, intentFilter);

        // Register a receiver that listens for when a better provider than I'm
        // using becomes available.
        String bestProvider = locationManager.getBestProvider(criteria, false);
        String bestAvailableProvider = locationManager.getBestProvider(criteria, true);
        if (bestProvider != null && !bestProvider.equals(bestAvailableProvider)) {
            bestInactiveLocationProviderListener = new IgnitedLocationListener(context);
            locationManager.requestLocationUpdates(bestProvider, 0, 0,
                    bestInactiveLocationProviderListener, context.getMainLooper());
        } else {
            // Post a runnable that will remove gps updates if no gps location is returned after 1
            // minute in order to avoid draining the battery.
            handler.postDelayed(removeGpsUpdates,
                    IgnitedLocationConstants.WAIT_FOR_GPS_FIX_INTERVAL);
        }

        locationManager.removeUpdates(locationListenerPassivePendingIntent);
        locationUpdatesDisabled = false;
    }

    /**
     * Stop listening for location updates
     * 
     * @param enablePassiveLocationUpdates
     */
    protected void disableLocationUpdates(Context context, boolean finishing) {
        if (locationUpdatesDisabled) {
            return;
        }

        Log.d(LOG_TAG, "...disabling location updates");

        context.unregisterReceiver(locProviderDisabledReceiver);
        locationUpdateRequester.removeLocationUpdates();
        if (bestInactiveLocationProviderListener != null) {
            locationManager.removeUpdates(bestInactiveLocationProviderListener);
        }

        if (finishing && ignitedLastKnownLocationTask != null) {
            ignitedLastKnownLocationTask.cancel(true);
        }
        if (IgnitedDiagnostics.SUPPORTS_FROYO && enablePassiveLocationUpdates) {
            // Passive location updates from 3rd party apps when the Activity isn't
            // visible. Only for Android 2.2+.
            locationUpdateRequester.requestPassiveLocationUpdates(passiveLocationUpdatesInterval,
                    passiveLocationUpdatesDistanceDiff, locationListenerPassivePendingIntent);
        }

        locationUpdatesDisabled = true;
    }
    }

    /**
     * If the best Location Provider (usually GPS) is not available when we request location
     * updates, this listener will be notified if / when it becomes available. It calls
     * requestLocationUpdates to re-register the location listeners using the better Location
     * Provider.
     */
    private class IgnitedLocationListener implements LocationListener {
        private Context context;

        public IgnitedLocationListener(Context appContext) {
            this.context = appContext;
        }

        @Override
        public void onLocationChanged(Location l) {
        }

        @Override
        public void onProviderDisabled(String provider) {
        }

        @Override
        public void onStatusChanged(String provider, int status, Bundle extras) {
        }

        @Override
        public void onProviderEnabled(String provider) {
            // Re-register the location listeners using the better Location
            // Provider.
            requestLocationUpdates(context);
        }
    }

}

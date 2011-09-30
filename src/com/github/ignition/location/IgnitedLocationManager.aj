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
import android.os.Bundle;
import android.util.Log;

import com.github.ignition.location.annotations.IgnitedLocation;
import com.github.ignition.location.annotations.IgnitedLocationActivity;
import com.github.ignition.location.receivers.IgnitedPassiveLocationChangedReceiver;
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
    protected ILastLocationFinder lastLocationFinder;
    protected LocationUpdateRequester locationUpdateRequester;
    protected PendingIntent locationListenerPendingIntent, locationListenerPassivePendingIntent;
    protected LocationManager locationManager;
    protected IgnitedLocationListener bestInactiveLocationProviderListener;

    private Context context;
    private volatile Location currentLocation;
    private long locationUpdateInterval;
    private int locationUpdateDistanceDiff;

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

    after(IgnitedLocationActivity ignitedAnnotation) : execution(* Activity.onCreate(..)) 
        && @this(ignitedAnnotation) && within(@IgnitedLocationActivity *) {

        // Get a reference to the Activity Context
        context = (Context) thisJoinPoint.getThis();

        // Get references to the managers
        locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        // Specify the Criteria to use when requesting location updates while
        // the application is Active
        criteria = new Criteria();
        if (ignitedAnnotation.useGps()) {
            criteria.setAccuracy(Criteria.ACCURACY_FINE);
        } else {
            criteria.setPowerRequirement(Criteria.POWER_LOW);
        }

        // Setup the location update Pending Intents
        Intent activeIntent = new Intent(IgnitedLocationConstants.ACTIVE_LOCATION_UPDATE_ACTION);
        locationListenerPendingIntent = PendingIntent.getBroadcast(context, 0, activeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT);

        Intent passiveIntent = new Intent(context, IgnitedPassiveLocationChangedReceiver.class);
        locationListenerPassivePendingIntent = PendingIntent.getBroadcast(context, 0,
                passiveIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        // Instantiate a LastLocationFinder class. This will be used to find the
        // last known location when the application starts.
        lastLocationFinder = PlatformSpecificImplementationFactory.getLastLocationFinder(context);

        // Instantiate a Location Update Requester class based on the available
        // platform version. This will be used to request location updates.
        locationUpdateRequester = PlatformSpecificImplementationFactory
                .getLocationUpdateRequester(context);
    }

    before(IgnitedLocationActivity ignitedAnnotation) : execution(* Activity.onResume(..)) && @this(ignitedAnnotation)
        && within(@IgnitedLocationActivity *) {

        if (context == null) {
            context = (Context) thisJoinPoint.getThis();
        }
        final boolean refreshDataIfLocationChanges = ignitedAnnotation
                .refreshDataIfLocationChanges();

        saveToPreferences(context, ignitedAnnotation);

        Log.d(LOG_TAG, "Retrieving last known location...");
        if (currentLocation != null) {
            ((OnIgnitedLocationChangedListener) context).onIgnitedLocationChanged(currentLocation);
            // If we have requested location updates, turn them on here.
            if (refreshDataIfLocationChanges) {
                requestLocationUpdates(context);
            }
            Log.d(LOG_TAG,
                    "Last known location from " + currentLocation.getProvider() + " (lat, long): "
                            + currentLocation.getLatitude() + ", " + currentLocation.getLongitude());
            return;
        }
        // Get the last known location (and optionally request location updates) and refresh the
        // data.
        // This isn't directly affecting the UI, so put it on a worker thread.
        new AsyncTask<Void, Void, Location>() {

            @Override
            protected Location doInBackground(Void... params) {
                return getLastKnownLocation(context);
            }

            @Override
            protected void onPostExecute(Location lastKnownLocation) {
                if (lastKnownLocation != null) {
                    currentLocation = lastKnownLocation;
                    ((OnIgnitedLocationChangedListener) context).onIgnitedLocationChanged(currentLocation);
                    Log.d(LOG_TAG, "Last known location from " + currentLocation.getProvider()
                            + " (lat, long): " + currentLocation.getLatitude() + ", "
                            + currentLocation.getLongitude());
                }
                // If we have requested location updates, turn them on here.
                if (refreshDataIfLocationChanges) {
                    requestLocationUpdates(context);
                }
            }
        }.execute();
    }

    /**
     * Save last settings to preferences.
     * 
     * @param context
     * @param locationAnnotation
     */
    private void saveToPreferences(Context context, IgnitedLocationActivity locationAnnotation) {
        locationUpdateDistanceDiff = locationAnnotation.locationUpdateDistanceDiff();
        locationUpdateInterval = locationAnnotation.locationUpdateInterval();
        int passiveLocationUpdateDistanceDiff = locationAnnotation
                .passiveLocationUpdateDistanceDiff();
        long passiveLocationUpdateInterval = locationAnnotation.passiveLocationUpdateInterval();
        boolean enablePassiveLocationUpdates = locationAnnotation.enablePassiveUpdates();

        // Set pref file
        SharedPreferences prefs = context.getSharedPreferences(
                IgnitedLocationConstants.SHARED_PREFERENCE_FILE, Context.MODE_PRIVATE);
        Editor editor = prefs.edit();
        editor.putBoolean(IgnitedLocationConstants.SP_KEY_FOLLOW_LOCATION_CHANGES,
                enablePassiveLocationUpdates);
        editor.putInt(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_DISTANCE_DIFF,
                locationUpdateDistanceDiff);
        editor.putLong(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_INTERVAL,
                locationUpdateInterval);
        editor.putInt(IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF,
                passiveLocationUpdateDistanceDiff);
        editor.putLong(IgnitedLocationConstants.SP_KEY_PASSIVE_LOCATION_UPDATES_INTERVAL,
                passiveLocationUpdateInterval);
        editor.putBoolean(IgnitedLocationConstants.SP_KEY_RUN_ONCE, true);
        editor.commit();

    }

    after(IgnitedLocationActivity ignitedAnnotation) : execution(* Activity.onPause(..)) && @this(ignitedAnnotation) 
        && within(@IgnitedLocationActivity *) && if (ignitedAnnotation.refreshDataIfLocationChanges()) {
        
        boolean finishing = ((Activity) context).isFinishing();
        disableLocationUpdates(context, ignitedAnnotation.enablePassiveUpdates(), finishing);
        
        if (finishing) {
            context = null;
        }
    }

//     after() : execution(* Activity.onDestroy(..)) && @this(IgnitedLocationActivity) 
//         && within(@IgnitedLocationActivity *) {
//     }

    Location around() : get(@IgnitedLocation Location *) {
        return currentLocation;
    }
    
    void around(Location freshLocation) : set(@IgnitedLocation Location *) && args(freshLocation) 
        && (within(com.github.ignition.location.receivers.*) || within(com.github.ignition.location.utils.*)) {
        
        currentLocation = freshLocation;
        Log.d(LOG_TAG, "New location from " + currentLocation.getProvider() + " (lat, long): "
                + currentLocation.getLatitude() + ", " + currentLocation.getLongitude());
        if (context != null) {
            ((OnIgnitedLocationChangedListener) context).onIgnitedLocationChanged(currentLocation);
        }
    }

    /**
     * Start listening for location updates.
     */
    protected void requestLocationUpdates(Context context) {
        Log.d(LOG_TAG, "requesting location updates...");
        // Normal updates while activity is visible.
        locationUpdateRequester.requestLocationUpdates(locationUpdateInterval,
                locationUpdateDistanceDiff, criteria, locationListenerPendingIntent);

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
        }

        locationManager.removeUpdates(locationListenerPassivePendingIntent);
    }

    /**
     * Stop listening for location updates
     * 
     * @param enablePassiveLocationUpdates
     */
    protected void disableLocationUpdates(Context context, boolean enablePassiveLocationUpdates, boolean finishing) {
        Log.d(LOG_TAG, "...disabling location updates");
        context.unregisterReceiver(locProviderDisabledReceiver);
        locationManager.removeUpdates(locationListenerPendingIntent);
        if (bestInactiveLocationProviderListener != null) {
            locationManager.removeUpdates(bestInactiveLocationProviderListener);
        }

        if (finishing) {
            lastLocationFinder.cancel();
        }
        if (IgnitedDiagnostics.SUPPORTS_FROYO && enablePassiveLocationUpdates) {
            // Passive location updates from 3rd party apps when the Activity isn't
            // visible. Only for Android 2.2+.
            locationUpdateRequester.requestPassiveLocationUpdates(locationUpdateInterval,
                    locationUpdateDistanceDiff, locationListenerPassivePendingIntent);
        }
    }

    /**
     * Find the last known location (using a {@link LastLocationFinder}) and updates the place list
     * accordingly.
     * 
     */
    protected Location getLastKnownLocation(Context context) {
        // Find the last known location, specifying a required accuracy
        // of within the min distance between updates
        // and a required latency of the minimum time required between
        // updates.
        Location lastKnownLocation = lastLocationFinder.getLastBestLocation(context,
                locationUpdateDistanceDiff, System.currentTimeMillis() - locationUpdateInterval);

        return lastKnownLocation;
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

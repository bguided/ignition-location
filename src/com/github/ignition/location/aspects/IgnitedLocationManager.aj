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

package com.github.ignition.location.aspects;

import static com.github.ignition.location.IgnitedLocationActivityConstants.SHARED_PREFERENCE_FILE;
import static com.github.ignition.location.IgnitedLocationActivityConstants.SP_KEY_FOLLOW_LOCATION_CHANGES;

import org.aspectj.lang.annotation.SuppressAjWarnings;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.location.Criteria;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;

import com.github.ignition.location.IgnitedLocationActivityConstants;
import com.github.ignition.location.annotations.IgnitedLocation;
import com.github.ignition.location.annotations.IgnitedLocationActivity;
import com.github.ignition.location.templates.ILastLocationFinder;
import com.github.ignition.location.templates.IgnitedOnLocationChangedListener;
import com.github.ignition.location.templates.LocationUpdateRequester;
import com.github.ignition.location.utils.PlatformSpecificImplementationFactory;

@SuppressAjWarnings
public aspect IgnitedLocationManager {

    public static final String LOG_TAG = IgnitedLocationManager.class
            .getSimpleName();

    declare parents : (@IgnitedLocationActivity *) implements IgnitedOnLocationChangedListener;

    protected Criteria criteria;

    protected ILastLocationFinder lastLocationFinder;

    protected LocationUpdateRequester locationUpdateRequester;

    protected PendingIntent locationListenerPendingIntent,
            locationListenerPassivePendingIntent;

    protected LocationManager locationManager;

    protected IgnitedLocationActivity locationAnnotation;

    private Activity activity;

    private static volatile Location currentLocation;

    private boolean refreshDataIfLocationChanges;

    /**
     * One-off location listener that receives updates from the
     * {@link LastLocationFinder}. This is triggered where the last known
     * location is outside the bounds of our maximum distance and latency.
     */
    protected LocationListener oneShotLastLocationUpdateListener = new LocationListener() {
        @Override
        public void onLocationChanged(Location lastLocation) {
            currentLocation = lastLocation;
            ((IgnitedOnLocationChangedListener) activity)
                    .onLocationChanged(currentLocation);
        }

        @Override
        public void onProviderDisabled(String provider) {
        }

        @Override
        public void onStatusChanged(String provider, int status, Bundle extras) {
        }

        @Override
        public void onProviderEnabled(String provider) {
        }
    };

    /**
     * If the best Location Provider (usually GPS) is not available when we
     * request location updates, this listener will be notified if / when it
     * becomes available. It calls requestLocationUpdates to re-register the
     * location listeners using the better Location Provider.
     */
    protected LocationListener bestInactiveLocationProviderListener = new LocationListener() {
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
            requestLocationUpdates();
        }
    };

    /**
     * If the Location Provider we're using to receive location updates is
     * disabled while the app is running, this Receiver will be notified,
     * allowing us to re-register our Location Receivers using the best
     * available Location Provider is still available.
     */
    protected BroadcastReceiver locProviderDisabledReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            boolean providerDisabled = !intent.getBooleanExtra(
                    LocationManager.KEY_PROVIDER_ENABLED, false);
            // Re-register the location listeners using the best available
            // Location Provider.
            if (providerDisabled) {
                requestLocationUpdates();
            }
        }
    };

    after() : execution(* onCreate(..)) && @this(IgnitedLocationActivity) {
        activity = (Activity) thisJoinPoint.getThis();
        locationAnnotation = activity.getClass().getAnnotation(
                IgnitedLocationActivity.class);

        refreshDataIfLocationChanges = locationAnnotation
                .refreshDataIfLocationChanges();
        SharedPreferences prefs = activity.getSharedPreferences(
                SHARED_PREFERENCE_FILE, Context.MODE_PRIVATE);
        prefs.edit()
                .putBoolean(SP_KEY_FOLLOW_LOCATION_CHANGES,
                        refreshDataIfLocationChanges).commit();

        // Get references to the managers
        locationManager = (LocationManager) activity
                .getSystemService(Context.LOCATION_SERVICE);
        // Specify the Criteria to use when requesting location updates while
        // the application is Active
        criteria = new Criteria();
        if (locationAnnotation.useGps()) {
            criteria.setAccuracy(Criteria.ACCURACY_FINE);
        } else {
            criteria.setPowerRequirement(Criteria.POWER_LOW);
        }

        // Setup the location update Pending Intents
        Intent activeIntent = new Intent(
                IgnitedLocationActivityConstants.ACTIVE_LOCATION_UPDATE_ACTION);
        locationListenerPendingIntent = PendingIntent.getBroadcast(activity, 0,
                activeIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        Intent passiveIntent = new Intent(
                IgnitedLocationActivityConstants.PASSIVE_LOCATION_UPDATE_ACTION);
        locationListenerPassivePendingIntent = PendingIntent.getBroadcast(
                activity, 0, passiveIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        // Instantiate a LastLocationFinder class. This will be used to find the
        // last known location when the application starts.
        lastLocationFinder = PlatformSpecificImplementationFactory
                .getLastLocationFinder(activity);
        lastLocationFinder
                .setChangedLocationListener(oneShotLastLocationUpdateListener);

        // Instantiate a Location Update Requester class based on the available
        // platform version. This will be used to request location updates.
        locationUpdateRequester = PlatformSpecificImplementationFactory
                .getLocationUpdateRequester(activity.getApplicationContext());

    }

    after() : execution(* onResume()) && @this(IgnitedLocationActivity) {
        // Get the last known location (and optionally request location updates)
        // and refresh the data.
        // boolean followLocationChanges =
        // prefs.getBoolean(PlacesConstants.SP_KEY_FOLLOW_LOCATION_CHANGES,
        // true);
        // getLocationAndUpdatePlaces(followLocationChanges);

        // This isn't directly affecting the UI, so put it on a worker thread.
        new AsyncTask<Void, Void, Location>() {
            
            protected Location doInBackground(Void... params) {
                return getLastKnownLocation();
            }

            @Override
            protected void onPostExecute(Location lastKnownLocation) {
                currentLocation = lastKnownLocation;
                Log.d(LOG_TAG,
                        "New Location (lat, long): "
                                + currentLocation.getLatitude() + ", "
                                + currentLocation.getLongitude());
                ((IgnitedOnLocationChangedListener) activity)
                        .onLocationChanged(currentLocation);

                // If we have requested location updates, turn them on here.
                toggleUpdatesWhenLocationChanges();
            }
        }.execute();

    }

    after() : execution(* onPause()) && @this(IgnitedLocationActivity) {
        disableLocationUpdates();
    }

    after() : execution(* onDestroy()) && @this(IgnitedLocationActivity) {
        activity = null;
    }

    Location around() : get(@IgnitedLocation Location *.*) {
        return currentLocation;
    }

    /**
     * Start listening for location updates.
     */
    protected void requestLocationUpdates() {
        Log.d(LOG_TAG, "requesting location updates...");
        // Normal updates while activity is visible.
        locationUpdateRequester.requestLocationUpdates(
                IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_TIME,
                IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_DISTANCE,
                criteria, locationListenerPendingIntent);

        // Passive location updates from 3rd party apps when the Activity isn't
        // visible.
        locationUpdateRequester.requestPassiveLocationUpdates(
                IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_TIME,
                IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_DISTANCE,
                locationListenerPassivePendingIntent);

        // Register a receiver that listens for when the provider I'm using has
        // been disabled.
        IntentFilter intentFilter = new IntentFilter(
                IgnitedLocationActivityConstants.ACTIVE_LOCATION_UPDATE_ACTION);
        activity.registerReceiver(locProviderDisabledReceiver, intentFilter);

        // Register a receiver that listens for when a better provider than I'm
        // using becomes available.
        String bestProvider = locationManager.getBestProvider(criteria, false);
        String bestAvailableProvider = locationManager.getBestProvider(
                criteria, true);
        if (bestProvider != null && !bestProvider.equals(bestAvailableProvider)) {
            locationManager.requestLocationUpdates(bestProvider, 0, 0,
                    bestInactiveLocationProviderListener,
                    activity.getMainLooper());
        }
    }

    /**
     * Stop listening for location updates
     */
    protected void disableLocationUpdates() {
        Log.d(LOG_TAG, "...disabling location updates");
        activity.unregisterReceiver(locProviderDisabledReceiver);
        locationManager.removeUpdates(locationListenerPendingIntent);
        locationManager.removeUpdates(bestInactiveLocationProviderListener);
        boolean finishing = activity.isFinishing();

//        if (finishing) {
        lastLocationFinder.cancel();
//        }
        if (IgnitedLocationActivityConstants.DISABLE_PASSIVE_LOCATION_WHEN_USER_EXIT
                && finishing) {
            locationManager.removeUpdates(locationListenerPassivePendingIntent);
        }
    }

    /**
     * Returns the current location
     * 
     * NB: Don't call this method in your Activity but use the @IgnitedLocation
     * annotation
     * 
     * @return the current location
     */
    public static Location getCurrentLocation() {
        return currentLocation;
    }

    /**
     * Sets the current location.
     * 
     * NB: Don't call this method in your Activity. Ignition will take care to
     * update the current location.
     * 
     * @param currentLocation
     */
    public static void setCurrentLocation(Location currentLocation) {
        IgnitedLocationManager.currentLocation = currentLocation;
    }

    /**
     * Find the last known location (using a {@link LastLocationFinder}) and
     * updates the place list accordingly.
     * 
     */
    protected Location getLastKnownLocation() {
        // Find the last known location, specifying a required accuracy
        // of within the min distance between updates
        // and a required latency of the minimum time required between
        // updates.
        Location lastKnownLocation = IgnitedLocationManager.this.lastLocationFinder
                .getLastBestLocation(
                        IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_DISTANCE,
                        System.currentTimeMillis()
                                - IgnitedLocationActivityConstants.LOCATION_UPDATE_MIN_TIME);

        return lastKnownLocation;
    }

    /**
     * Choose if we should receive location updates.
     */
    protected void toggleUpdatesWhenLocationChanges() {
        // Save the location update status in shared preferences
        // this.prefsEditor.putBoolean(
        // PlacesConstants.SP_KEY_FOLLOW_LOCATION_CHANGES,
        // updateWhenLocationChanges);
        // this.sharedPreferenceSaver.savePreferences(this.prefsEditor, true);

        // Start or stop listening for location changes
        if (refreshDataIfLocationChanges) {
            requestLocationUpdates();
        } else {
            disableLocationUpdates();
        }
    }
}

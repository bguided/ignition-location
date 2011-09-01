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
 */

package com.github.ignition.location.receivers;

import static com.github.ignition.location.IgnitedLocationActivityConstants.SHARED_PREFERENCE_FILE;
import static com.github.ignition.location.IgnitedLocationActivityConstants.SP_KEY_FOLLOW_LOCATION_CHANGES;
import static com.github.ignition.location.IgnitedLocationActivityConstants.SP_KEY_RUN_ONCE;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import com.github.ignition.location.IgnitedLocationActivityConstants;
import com.github.ignition.location.templates.LocationUpdateRequester;
import com.github.ignition.location.utils.PlatformSpecificImplementationFactory;
import com.github.ignition.support.IgnitedDiagnostics;

/**
 * This Receiver class is designed to listen for system boot.
 * <p/>
 * If the app has been run at least once, the passive location updates should be
 * enabled after a reboot.
 */
public class BootReceiver extends BroadcastReceiver {
	@Override
	public void onReceive(Context context, Intent intent) {
		SharedPreferences prefs = context.getSharedPreferences(
				SHARED_PREFERENCE_FILE, Context.MODE_PRIVATE);
		boolean runOnce = prefs.getBoolean(SP_KEY_RUN_ONCE, false);

		if (runOnce) {
			// Instantiate a Location Update Requester class based on the
			// available platform version.
			// This will be used to request location updates.
			LocationUpdateRequester locationUpdateRequester = PlatformSpecificImplementationFactory
					.getLocationUpdateRequester(context.getApplicationContext());

			// Check the Shared Preferences to see if we are updating location
			// changes.
			boolean followLocationChanges = prefs.getBoolean(
					SP_KEY_FOLLOW_LOCATION_CHANGES, true);

			if (followLocationChanges && IgnitedDiagnostics.SUPPORTS_FROYO) {
				// Passive location updates from 3rd party apps when the
				// Activity isn't visible.
				Intent passiveIntent = new Intent(context, PassiveLocationChangedReceiver.class);
				PendingIntent locationListenerPassivePendingIntent = PendingIntent
						.getBroadcast(context, 0, passiveIntent,
								PendingIntent.FLAG_UPDATE_CURRENT);
				locationUpdateRequester.requestPassiveLocationUpdates(
						IgnitedLocationActivityConstants.PASSIVE_MAX_TIME,
						IgnitedLocationActivityConstants.PASSIVE_MAX_DISTANCE,
						locationListenerPassivePendingIntent);
			}
		}
	}
}
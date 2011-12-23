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

import static com.github.ignition.location.IgnitedLocationConstants.SHARED_PREFERENCE_FILE;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.Criteria;

import com.github.ignition.location.IgnitedLocationConstants;
import com.github.ignition.location.IgnitedLocationManager;

/**
 * The manifest Receiver is used to detect changes in battery state. When the system broadcasts a
 * "Battery Low" warning we turn off the passive location updates to conserve battery when the app
 * is in the background.
 * 
 * When the system broadcasts "Battery OK" to indicate the battery has returned to an okay state,
 * the passive location updates are resumed.
 */
public class PowerStateChangedReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        boolean batteryLow = intent.getAction().equals(Intent.ACTION_BATTERY_LOW);

        PackageManager pm = context.getPackageManager();
        ComponentName passiveLocationReceiver = new ComponentName(context,
                IgnitedPassiveLocationChangedReceiver.class);

        // Disable the passive location update receiver when the battery state
        // is low. Disabling the Receiver will prevent the app from initiating the
        // background downloads of nearby locations.
        pm.setComponentEnabledSetting(passiveLocationReceiver,
                batteryLow ? PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                        : PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                PackageManager.DONT_KILL_APP);

        SharedPreferences prefs = context.getSharedPreferences(SHARED_PREFERENCE_FILE,
                Context.MODE_PRIVATE);

        if (prefs.getBoolean(IgnitedLocationConstants.SP_KEY_FOLLOW_LOCATION_CHANGES, true)
                && prefs.getBoolean(IgnitedLocationConstants.SP_KEY_LOCATION_UPDATES_USE_GPS, true)) {

            Criteria criteria = new Criteria();
            if (batteryLow) {
                criteria.setPowerRequirement(Criteria.POWER_LOW);
            } else {
                criteria.setAccuracy(Criteria.ACCURACY_FINE);
            }

            IgnitedLocationManager ilm = IgnitedLocationManager.aspectOf();
            ilm.requestLocationUpdatesWithNewCriteria(context, criteria);
        }
    }
}
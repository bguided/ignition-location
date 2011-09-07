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

package com.github.ignition.location;

import android.app.AlarmManager;

public class IgnitedLocationConstants {
    // TODO Turn off when deploying your app.
    public static boolean DEVELOPER_MODE = true;

    // The maximum distance the user should travel between location updates.
    public static int LOCATION_UPDATE_MIN_DISTANCE = 100;
    // The maximum time that should pass before the user gets a location update.
    public static long LOCATION_UPDATE_MIN_TIME = AlarmManager.INTERVAL_FIFTEEN_MINUTES;

    // You will generally want passive location updates to occur less frequently
    // than active updates. You need to balance location freshness with battery
    // life.
    // The location update distance for passive updates.
    public static int PASSIVE_MAX_DISTANCE = LOCATION_UPDATE_MIN_DISTANCE;
    // The location update time for passive updates
    public static long PASSIVE_MAX_TIME = LOCATION_UPDATE_MIN_TIME;
    // When the user exits via the back button, do you want to disable
    // passive background updates.
    public static boolean DISABLE_PASSIVE_LOCATION_WHEN_USER_EXIT = false;

    // Maximum latency before you force a cached detail page to be updated.
    public static long MAX_DETAILS_UPDATE_LATENCY = AlarmManager.INTERVAL_DAY;

    public static String SP_KEY_RUN_ONCE = "SP_KEY_RUN_ONCE";

    public static String SHARED_PREFERENCE_FILE = "LocationManagerPreference";

    public static String SP_KEY_FOLLOW_LOCATION_CHANGES = "SP_KEY_FOLLOW_LOCATION_CHANGES";

    public static String PASSIVE_LOCATION_UPDATE_ACTION = "com.github.ignition.location.passive_location_update_action";
    
    public static String ACTIVE_LOCATION_UPDATE_PROVIDER_DISABLED = "com.github.ignition.location.active_location_update_provider_disabled";

    public static String ACTIVE_LOCATION_UPDATE_ACTION = "com.github.ignition.location.active_location_update_action";

    public static String IGNITED_LOCATION_PROVIDER = "ignited_location_provider";

}

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

public class IgnitedLocationConstants {

    public static final boolean USE_GPS = true;

    public static final boolean REFRESH_DATA_ON_LOCATION_CHANGED = true;

    // The maximum distance the user should travel between location updates.
    public static final int LOCATION_UPDATES_DISTANCE_DIFF = 100; // meters
    // The maximum time that should pass before the user gets a location update.
    public static final long LOCATION_UPDATES_INTERVAL = 5; // minutes

    // You will generally want passive location updates to occur less frequently
    // than active updates. You need to balance location freshness with battery
    // life. The location update distance for passive updates.
    public static final int PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF = LOCATION_UPDATES_DISTANCE_DIFF; // meters
    // The location update time for passive updates
    public static final long PASSIVE_LOCATION_UPDATES_INTERVAL = 15; // minutes
    // When the user exits via the back button, do you want to disable
    // passive background updates.
    public static final boolean DISABLE_PASSIVE_LOCATION_WHEN_USER_EXIT = false;

    public static final String SHARED_PREFERENCE_FILE = "IgnitedLocationManagerPreference";
    public static final String SP_KEY_RUN_ONCE = "sp_key_run_once";
    public static String SP_KEY_FOLLOW_LOCATION_CHANGES = "sp_key_follow_location_changes";
    public static String SP_KEY_LOCATION_UPDATES_DISTANCE_DIFF = "sp_location_updates_distance_diff";
    public static String SP_KEY_LOCATION_UPDATES_INTERVAL = "sp_key_location_updates_interval";
    public static String SP_KEY_PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF = "sp_passive_location_updates_distance_diff";
    public static String SP_KEY_PASSIVE_LOCATION_UPDATES_INTERVAL = "sp_key_passive_location_updates_interval";

    public static final String PASSIVE_LOCATION_UPDATE_ACTION = "com.github.ignition.location.passive_location_update_action";
    public static final String ACTIVE_LOCATION_UPDATE_PROVIDER_DISABLED_ACTION = "com.github.ignition.location.ACTIVE_LOCATION_UPDATE_PROVIDER_DISABLED_ACTION";
    public static final String ACTIVE_LOCATION_UPDATE_ACTION = "com.github.ignition.location.ACTIVE_LOCATION_UPDATE_ACTION";

    public static final String IGNITED_LOCATION_PROVIDER = "ignited_location_provider";

}

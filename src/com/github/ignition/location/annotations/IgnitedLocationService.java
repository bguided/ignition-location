/* Copyright (c) 2011 Stefano Dacchille
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.github.ignition.location.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import com.github.ignition.location.IgnitedLocationConstants;

@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.TYPE })
public @interface IgnitedLocationService {

    boolean useGps() default IgnitedLocationConstants.USE_GPS;

    boolean refreshDataIfLocationChanges() default IgnitedLocationConstants.REFRESH_DATA_ON_LOCATION_CHANGED;

    int locationUpdateDistanceDiff() default IgnitedLocationConstants.LOCATION_UPDATES_DISTANCE_DIFF;

    long locationUpdateInterval() default IgnitedLocationConstants.LOCATION_UPDATES_INTERVAL;

    int passiveLocationUpdateDistanceDiff() default IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_DISTANCE_DIFF;

    long passiveLocationUpdateInterval() default IgnitedLocationConstants.PASSIVE_LOCATION_UPDATES_INTERVAL;

    boolean disablePassiveUpdatesOnDestroy() default IgnitedLocationConstants.ENABLE_PASSIVE_LOCATION_WHEN_USER_EXITS;

}

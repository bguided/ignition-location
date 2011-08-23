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

package com.github.ignition.location.example;

import java.util.ArrayList;

import android.app.ListActivity;
import android.location.Location;
import android.os.Bundle;
import android.util.Log;
import android.widget.ArrayAdapter;

import com.github.ignition.location.annotations.IgnitedLocation;
import com.github.ignition.location.annotations.IgnitedLocationActivity;

// Use the @IgnitedLocationActivity annotation to take advantage if the ignition-location 
// library functionalities.
@IgnitedLocationActivity(useGps = true, refreshDataIfLocationChanges = true)
public class IgnitedLocationSampleActivity extends ListActivity {

    private ArrayAdapter<Location> adapter;

    // Use the IgniteLocation annotation to get the most recent location.
    @IgnitedLocation
    private Location currentLocation;

    // Make sure the onCreate() method is overridden in your Activity or
    // the ignition-location library won't work properly
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);

        adapter = new ArrayAdapter<Location>(this,
                android.R.layout.activity_list_item, android.R.id.text1);
        setListAdapter(this.adapter);
    }

    // Make sure the onResume() method is overridden in your Activity or
    // the ignition-location library won't work properly
    @Override
    protected void onResume() {
        super.onResume();
    }

    // Make sure the onPause() method is overridden in your Activity or
    // the ignition-location library won't work properly
    @Override
    protected void onPause() {
        super.onPause();
    }

    // Make sure the onDestroy() method is overridden in your Activity or
    // the ignition-location library won't work properly
    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    // This callback is called every time the Location Manager has got a new
    // location. Use it to update you geo-sensible data.
    @Override
    public void onLocationChanged(Location newLocation) {
        refreshData();
    }

    public void refreshData() {
        Log.d(IgnitedLocationSampleActivity.class.getSimpleName(),
                currentLocation.toString());
        adapter.add(currentLocation);
    }

}
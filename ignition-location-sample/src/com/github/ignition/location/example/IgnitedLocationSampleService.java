/*
 * Copyright (C) 2007 The Android Open Source Project
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

package com.github.ignition.location.example;

// Need the following import to get access to the app resources, since this
// class is in a sub-package.

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Binder;
import android.os.IBinder;
import android.os.Parcel;
import android.os.RemoteException;
import android.util.Log;

import com.github.ignition.location.annotations.IgnitedLocationService;

/**
 * This is an example of service that will update its status bar balloon every 5
 * seconds for a minute.
 * 
 */
@IgnitedLocationService
public class IgnitedLocationSampleService extends Service {

    private static final String LOG_TAG = IgnitedLocationSampleService.class
            .getSimpleName();

    static final int IGNITED_LOCATION_NOTIFICATION_ID = 0;

    private final IBinder binder = new Binder() {
        @Override
        protected boolean onTransact(int code, Parcel data, Parcel reply,
                int flags) throws RemoteException {
            return super.onTransact(code, data, reply, flags);
        }
    };

    private NotificationManager notificationManager;

    @Override
    public void onCreate() {
        notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
    }

    @Override
    public void onDestroy() {
        Log.d(LOG_TAG, "Ignited Location Service stopped");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public void onStart(Intent intent, int startId) {
        Log.d(LOG_TAG, "Ignited Location Service started");
        super.onStart(intent, startId);
    }

    @Override
    public void onIgnitedLocationChanged(Location freshLocation) {

        // Start up the thread running the service. Note that we create a
        // separate thread because the service normally runs in the process's
        // main thread, which we don't want to block.
        Intent notificationIntent = new Intent(this,
                IgnitedLocationSampleActivity.class);
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0,
                notificationIntent, 0);
        Thread notifyingThread = new Thread(new IgnitedNotificationRunnable(
                this, contentIntent, freshLocation),
                "IgnitedLocationSampleService");
        notifyingThread.start();
    }

    private class IgnitedNotificationRunnable implements Runnable {
        private Context context;
        private PendingIntent intent;
        private Location location;

        public IgnitedNotificationRunnable(Context context,
                PendingIntent intent, Location location) {
            this.context = context.getApplicationContext();
            this.intent = intent;
            this.location = location;
        }

        @Override
        public void run() {
            Notification notification = new Notification(
                    R.drawable.icn_notification, "New location!",
                    System.currentTimeMillis());
            notification.setLatestEventInfo(context, "New location!",
                    location.getLatitude() + ", " + location.getLongitude(),
                    intent);
            notificationManager.notify(IGNITED_LOCATION_NOTIFICATION_ID,
                    notification);
        }
    }

}

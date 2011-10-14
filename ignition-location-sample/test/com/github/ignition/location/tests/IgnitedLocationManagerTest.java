package com.github.ignition.location.tests;

import java.util.List;

import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import com.github.ignition.location.example.IgnitedLocationSampleActivity;
import com.github.ignition.location.receivers.IgnitedPassiveLocationChangedReceiver;
import com.xtremelabs.robolectric.Robolectric;
import com.xtremelabs.robolectric.RobolectricTestRunner;
import com.xtremelabs.robolectric.shadows.ShadowApplication;

@RunWith(RobolectricTestRunner.class)
public class IgnitedLocationManagerTest {

    private IgnitedLocationSampleActivity activity;

    @Before
    public void setUp() throws Exception {
        activity = new IgnitedLocationSampleActivity();
        activity.onCreate(null);
    }

    @Test
    public void testOnResume() {
    }

    @Test
    public void testOnPause() {
        activity.onResume();
        activity.onPause();
        ShadowApplication shadowApp = Robolectric.shadowOf(activity.getApplication());
        List<ShadowApplication.Wrapper> receivers = shadowApp.getRegisteredReceivers();
        for (ShadowApplication.Wrapper receiver : receivers) {
            Assert.assertTrue(receiver.getBroadcastReceiver().getClass().getSimpleName()
                    .equals(IgnitedPassiveLocationChangedReceiver.class.getSimpleName()));
        }
    }

    @Test
    public void testOnCreate() {
    }

    @Test
    public void testOnIgnitedLocationChanged() {
    }

}

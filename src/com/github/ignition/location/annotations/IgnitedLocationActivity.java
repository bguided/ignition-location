package com.github.ignition.location.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.TYPE })
public @interface IgnitedLocationActivity {

    boolean useGps() default false;

    boolean refreshDataIfLocationChanges() default false;

}

package com.github.ignition.location.aspects;

import org.aspectj.lang.annotation.SuppressAjWarnings;

import com.github.ignition.location.annotations.LocationActivity;


public aspect LocationActivityAspect {
	
	@SuppressAjWarnings
	before() : execution(* onResume()) && @this(LocationActivity) {
		
	}
	
	@SuppressAjWarnings
	before() : execution(* onPause()) && @this(LocationActivity) {
		
	}
}

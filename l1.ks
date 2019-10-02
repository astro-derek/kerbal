//hellolaunch

//First, we'll clear the terminal screen to make it look nice
CLEARSCREEN.
print "v2".

sas off.

set circstart to 10.
set orbit_height to 100000.
set orbit_peri_height to 96000.
set fairing_height to 50000.

//Next, we'll lock our throttle to 100%.
LOCK THROTTLE TO 1.0.   // 1.0 is the max, 0.0 is idle.

//This is our countdown loop, which cycles from 10 to 0
PRINT "Counting down:".
FROM {local countdown is 2.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. // pauses the script here for 1 second.
}

WHEN MAXTHRUST = 0 THEN {
    STAGE.
    PRESERVE.
}.

set mysteer to heading(90,90).
lock steering to mysteer.

until ship:velocity:surface:mag > 20 {
	set mysteer to heading(90,90).
}.

when ship:altitude > fairing_height then {
	print "jettison fairing".
	for module in ship:modulesnamed("ModuleProceduralFairing") {
		module:doevent("deploy").
	}.
	for module in ship:modulesnamed("ProcedularFairingDecoupler") {
		module.doevent("jettison").
	}.
}.

until ship:obt:apoapsis > orbit_height {
	if ship:velocity:surface:mag < 100 {
		set mysteer to heading(90,89).
	}
	else if ship:velocity:surface:mag >= 100 and ship:velocity:surface:mag < 300 {
		set mysteer to heading(90,80).
	}
	else if ship:velocity:surface:mag >= 300 and ship:velocity:surface:mag < 400 {
		set mysteer to heading(90,70).
	}
	else if ship:velocity:surface:mag >= 400 and ship:velocity:surface:mag < 600 {
		set mysteer to heading(90,60).
	}
	else if ship:velocity:surface:mag >= 600 and ship:velocity:surface:mag < 700 {
		set mysteer to heading(90,50).
	}
	else if ship:velocity:surface:mag >= 700 and ship:velocity:surface:mag < 800 {
		set mysteer to heading(90,40).
	}
	else if ship:velocity:surface:mag >= 800 {
		set mysteer to heading(90,30).
	}.
}. 

lock throttle to 0.

set ship:control:pilotmainthrottle to 0.

until eta:apoapsis < circstart {
	set mysteer to ship:prograde.
}.

until ship:periapsis >= orbit_peri_height {
	lock throttle to 1.0.
}.

lock throttle to 0.
ag1 on.

// NOTE that it is vital to not just let the script end right away
// here.  Once a kOS script just ends, it releases all the controls
// back to manual piloting so that you can fly the ship by hand again.
// If the program just ended here, then that would cause the throttle
// to turn back off again right away and nothing would happen.
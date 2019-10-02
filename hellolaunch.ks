//hellolaunch

//First, we'll clear the terminal screen to make it look nice
CLEARSCREEN.
print "v2".

//Next, we'll lock our throttle to 100%.
LOCK THROTTLE TO 1.0.   // 1.0 is the max, 0.0 is idle.

//This is our countdown loop, which cycles from 10 to 0
PRINT "Counting down:".
FROM {local countdown is 5.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. // pauses the script here for 1 second.
}

WHEN MAXTHRUST = 0 THEN {
    PRINT "Staging".
    STAGE.
    PRESERVE.
}.

set mysteer to heading(0,90).
lock steering to mysteer.

when ship:velocity:surface:mag > 20 then {
	set mysteer to heading(90,80).
}.

when ship:altitude > 8000 then {
	lock steering to heading(0,45).
}.

WAIT UNTIL SHIP:ALTITUDE > 70000.

// NOTE that it is vital to not just let the script end right away
// here.  Once a kOS script just ends, it releases all the controls
// back to manual piloting so that you can fly the ship by hand again.
// If the program just ended here, then that would cause the throttle
// to turn back off again right away and nothing would happen.
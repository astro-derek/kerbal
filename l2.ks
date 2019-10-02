global fairing_height to 47000.
global apoapsis_target to 110000.
global fairing_jetissoned to false.
global inc to 1.

function main {
    doLaunch().
    doAscent().
    
    until apoapsis > apoapsis_target {
        doAutoStage().
    }

    doShutdown().
    set mapview to true.
    doCircularization().  
    doTransfer().
    set mapview to false.

    doHoverslam().

    wait until false. 
}

function doCircularization {
    local circ is list(0).
    set circ to improveConverge(circ, eccentricityScore@).
    executeManeuver(list(time:seconds + eta:apoapsis, 0, 0, circ[0])).
}

function protectFromPast {
    parameter originalFn.
    
    local replacementFn is {
        parameter data.
        if data[0] < time:seconds + 15 {
            return 2^64.
        } else {
            return originalFn(data).
        }
    }.

    return replacementFn@.
}

function doTransfer {
  local startSearchTime is ternarySearch(
    angleToMun@,
    time:seconds + 30, 
    time:seconds + 30 + orbit:period,
    1
  ).
  local transfer is list(startSearchTime, 0, 0, 0).
  set transfer to improveConverge(transfer, protectFromPast(munTransferScore@)).
  executeManeuver(transfer).
  wait 1.
  warpto(time:seconds + obt:nextPatchEta - 5).
  wait until body = Mun.
  wait 1.
}

function angleToMun {
  parameter t.
  return vectorAngle(
    Kerbin:position - positionAt(ship, t),
    Kerbin:position - positionAt(Mun, t)
  ).
}

function munTransferScore {
  parameter data.
  local mnv is node(data[0], data[1], data[2], data[3]).
  addManeuverToFlightPlan(mnv).
  local result is 0.
  if mnv:orbit:hasNextPatch {
    set result to mnv:orbit:nextPatch:periapsis.
  } else {
    set result to distanceToMunAtApoapsis(mnv).
  }
  removeManeuverFromFlightPlan(mnv).
  return result.
}

function distanceToMunAtApoapsis {
  parameter mnv.
  local apoapsisTime is ternarySearch(
    altitudeAt@, 
    time:seconds + mnv:eta, 
    time:seconds + mnv:eta + (mnv:orbit:period / 2),
    1
  ).
  return (positionAt(ship, apoapsisTime) - positionAt(Mun, apoapsisTime)):mag.
}

function altitudeAt {
  parameter t.
  return Kerbin:altitudeOf(positionAt(ship, t)).
}

function ternarySearch {
  parameter f, left, right, absolutePrecision.
  until false {
    if abs(right - left) < absolutePrecision {
      return (left + right) / 2.
    }
    local leftThird is left + (right - left) / 3.
    local rightThird is right - (right - left) / 3.
    if f(leftThird) < f(rightThird) {
      set left to leftThird.
    } else {
      set right to rightThird.
    }
  }
}

function improveConverge {
    parameter data, scoreFn.

    for stepsize in list(100, 10, 1) {
        until false {
            local oldScore is scoreFn(data).
            set data to improve(data, stepsize, scoreFn).
            if oldscore <= scoreFn(data) {
                break.
            } 
        }
    }

    return data.
}

function eccentricityScore {
    parameter data.

    local mnv is node(time:seconds + eta:apoapsis, 0, 0, data[0]).
    addManeuverToFlightPlan(mnv).
    
    local result is mnv:orbit:eccentricity.
    removeManeuverFromFlightPlan(mnv).
    return result.
}

function improve {
    parameter data, stepsize, scoreFn.

    local scoretobeat is scoreFn(data).
    local bestCandidate is data.
    local candidates is list().
    local index is 0.

    until index >= data:length {
        local inccan is data:copy().
        local deccan is data:copy().
        set inccan[index] to inccan[index] + stepsize.
        set deccan[index] to deccan[index] - stepsize.
        candidates:add(inccan).
        candidates:add(deccan).
        set index to index + 1.
    }

    for candidate in candidates {
        local candidateScore is scoreFn(candidate).
        if candidateScore < scoretobeat {
            set scoreToBeat to candidateScore.
            set bestCandidate to candidate.
        }
    }

    return bestCandidate.
}

function executeManeuver {
    parameter plist.

    local mnv is node(plist[0], plist[1], plist[2], plist[3]).
    addManeuverToFlightPlan(mnv).

    local startTime is calculateStartTime(mnv).
    wait until time:seconds > startTime - 10.
    rcs on.
    lockSteeringAtManeuverTarget(mnv).
    wait until time:seconds > startTime.
    rcs off.

    lock throttle to 1.
    wait until isManeuverComplete(mnv).
    lock throttle to 0.
    unlock steering.
    removeManeuverFromFlightPlan(mnv).
}

function addManeuverToFlightPlan {
    parameter mnv.

    add mnv.
}

function calculateStartTime {
    parameter mnv.

    return time:seconds + mnv:eta - maneuverBurntime(mnv) / 2.
}

function maneuverBurntime {
    parameter mnv. 
    local g0 is 9.80665.
    local isp is 0.
    local dv is mnv:deltaV:mag.
    
    list engines in myengines.
    for en in myengines {
        if en:ignition and not en:flameout {
            set isp to isp + (en:isp * (en:availablethrust / ship:availablethrust)).
        }
    }

    local mf is ship:mass / constant():e^(dv / (isp * g0)).
    local fuelflow is ship:maxthrust / (isp * g0).
    local t is (ship:mass - mf) / fuelflow.

    return t.
}

function lockSteeringAtManeuverTarget {
    parameter mnv.

    lock steering to mnv:burnvector.
}

function isManeuverComplete {
    parameter mnv.

    if not(defined originalVector) or originalVector = -1 {
        global originalVector is mnv:burnVector.
    }

    if vang(originalVector, mnv:burnvector) > 90 {
        global originalVector is -1.
        return true.
    }
    doAutoStage().
    
    return false.
}

function removeManeuverFromFlightPlan {
    parameter mnv.

    remove mnv.
}

function doLaunch {
    lock throttle to .8.
    doSafeStage().
}

function doAscent {
    lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
    set targetDirection to 90.
    lock steering to heading(targetDirection, targetPitch).
}

function doShutdown {
    lock throttle to 0.
    lock steering to prograde.
}

function doAutoStage {
    if maxthrust = 0 {
        doSafeStage().
    }

    if ship:altitude > fairing_height and not(fairing_jetissoned) {
        doJettisonFairing().
        set fairing_jetissoned to true.
    }
}

function doJettisonFairing {
    print "jettison fairing".
	for module in ship:modulesnamed("ModuleProceduralFairing") {
		module:doevent("deploy").
	}.
	for module in ship:modulesnamed("ProceduralFairingDecoupler") {
		module:doevent("jettison").
	}.
}

function doSafeStage {
    wait until stage:ready.
    stage.
}

function doHoverslam {
  lock steering to srfRetrograde.
  lock pct to stoppingDistance() / distanceToGround().
  set warp to 4.
  wait until pct > 0.1.
  set warp to 3.
  wait until pct > 0.4.
  set warp to 0.
  wait until pct > 1.
  lock throttle to pct.
  when distanceToGround() < 500 then { gear on. }
  wait until ship:verticalSpeed > 0.
  lock throttle to 0.
  lock steering to groundSlope().
  wait 30.
  unlock steering.
}

function distanceToGround {
  return altitude - body:geopositionOf(ship:position):terrainHeight - 4.7.
}

function stoppingDistance {
  local grav is constant():g * (body:mass / body:radius^2).
  local maxDeceleration is (ship:availableThrust / ship:mass) - grav.
  return ship:verticalSpeed^2 / (2 * maxDeceleration).
}

function groundSlope {
  local east is vectorCrossProduct(north:vector, up:vector).

  local center is ship:position.

  local a is body:geopositionOf(center + 5 * north:vector).
  local b is body:geopositionOf(center - 3 * north:vector + 4 * east).
  local c is body:geopositionOf(center - 3 * north:vector - 4 * east).

  local a_vec is a:altitudePosition(a:terrainHeight).
  local b_vec is b:altitudePosition(b:terrainHeight).
  local c_vec is c:altitudePosition(c:terrainHeight).

  return vectorCrossProduct(c_vec - a_vec, b_vec - a_vec):normalized.
}

main().
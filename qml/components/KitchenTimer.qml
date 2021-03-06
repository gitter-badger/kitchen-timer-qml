/****************************************************************************************
**
** Copyright (C) 2013 Thomas Tanghus
**
** Originally:
** Copyright (C) 2013 Jolla Ltd.
** Contact: Matt Vogt <matthew.vogt@jollamobile.com>
** All rights reserved.
** 
** You may use this file under the terms of BSD license as follows:
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are met:
**     * Redistributions of source code must retain the above copyright
**       notice, this list of conditions and the following disclaimer.
**     * Redistributions in binary form must reproduce the above copyright
**       notice, this list of conditions and the following disclaimer in the
**       documentation and/or other materials provided with the distribution.
**     * Neither the name of the Jolla Ltd nor the
**       names of its contributors may be used to endorse or promote products
**       derived from this software without specific prior written permission.
** 
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
** ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
** WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
** DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
** ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
** (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
** LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
** ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
** SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**
** Modified from Sailfish Silica TimePicker by Thomas Tanghus.
****************************************************************************************/

import QtQuick 2.0
import Sailfish.Silica 1.0


Item {
    id: timePicker

    property int minutes
    property int seconds

    // the original dimensions = 408x408
    property real _scaleRatio: secondsCircle.width / 408

    width: secondsCircle.width
    height: secondsCircle.height

    onMinutesChanged: {
        minutes = (minutes < 0 ? 0 : (minutes > 59 ? 59 : minutes))

        if(mouse.changingProperty === 0) {
            var delta = (minutes - minutesIndicator.value) % 30
            if ((delta > 15) || (delta < -15)) {
                // We don't want to animate for more than a full cycle
                minutesIndicator.animationEnabled = false

                minutesIndicator.value += (delta > 0 ? 15 : -15)
                delta = (minutes - minutesIndicator.value) % 15

                minutesIndicator.animationEnabled = true
            }

            minutesIndicator.value += delta
        }
    }

    onSecondsChanged: {
        if(seconds === 0 && minutes > 0 && isRunning) {
            seconds = 60;
            minutes -= 1;
        } else if(seconds < 0 && isRunning) {
            if(minutes > 0) {
                minutes -= 1;
                seconds = 60 + seconds;
            } else {
                seconds = minutes = 0;
            }
        }

        if(mouse.changingProperty === 0) {
            var delta = (seconds - secondsIndicator.value) % 60
            secondsIndicator.value += delta
        }
    }

    function _xTranslation(value, bound) {
        // Use sine to map range of 0-bound to the X translation of a circular locus (-1 to 1)
        return Math.sin((value % bound) / bound * Math.PI * 2)
    }

    function _yTranslation(value, bound) {
        // Use cosine to map range of 0-bound to the Y translation of a circular locus (-1 to 1)
        return Math.cos((value % bound) / bound * Math.PI * 2)
    }

    Image {
        id: secondsCircle

        source: "image://Theme/timepicker"
        opacity: 0.1
    }

    GlassItem {
        id: minutesIndicator
        falloffRadius: 0.22
        radius: 0.25
        anchors.centerIn: secondsCircle
        color: mouse.changingProperty == 1 ? Theme.highlightColor : Theme.primaryColor

        property real value
        property bool animationEnabled: applicationActive;

        transform: Translate { 
            // The minutes circle ends at 132px from the center
            x: _scaleRatio*96 * _xTranslation(minutesIndicator.value, 60)
            y: -_scaleRatio*96 * _yTranslation(minutesIndicator.value, 60)
        }
    }

    GlassItem {
        id: secondsIndicator
        falloffRadius: 0.22
        radius: 0.25
        anchors.centerIn: secondsCircle
        color: mouse.changingProperty == 2 ? Theme.highlightColor : Theme.primaryColor

        property real value

        transform: Translate { 
            // The seconds band is 72px wide, ending at 204px from the center
            x: _scaleRatio*168 * _xTranslation(secondsIndicator.value, 60)
            y: -_scaleRatio*168 * _yTranslation(secondsIndicator.value, 60)
        }
    }

    MouseArea {
        id: mouse

        property int changingProperty
        property bool isMoving
        property bool isLagging

        anchors.fill: parent
        preventStealing: true

        function radiusForCoord(x, y) {
            // Return the distance from the mouse position to the center
            return Math.sqrt(Math.pow(x, 2) + Math.pow(y, 2))
        }

        function angleForCoord(x, y) {
            // Return the angular position in degrees, rising anticlockwise from the positive X-axis
            var result = Math.atan(y / x) / (Math.PI * 2) * 360

            // Adjust for various quadrants
            if (x < 0)  {
                result += 180
            } else if (y < 0) {
                result += 360
            }
            return result
        }

        function remapAngle(value, bound) {
            // Return the angle in degrees mapped to the adjusted range 0 - (bound-1) and
            // translated to the clockwise from positive Y-axis orientation
            return Math.round(bound - (((value - 90) / 360) * bound)) % bound
        }

        function remapMouse(mouseX, mouseY) {
            // Return the mouse coordinates in cartesian coords relative to the circle center
            return { x: mouseX - (width / 2), y: 0 - (mouseY - (height / 2)) }
        }

        function propertyForRadius(radius) {
            // Return the property associated with clicking at radius distance from the center
            if (radius < 132) {
                return 1 // Minutes
            } else if (radius < 204) {
                return 2 // Seconds
            }
            return 0
        }

        function updateForAngle(angle) {
            // Update the selected property for the specified angular position
            if (changingProperty == 1) { // Minutes
                // Map angular position to 0-59
                var h = remapAngle(angle, 60)
                var delta = (h - minutesIndicator.value) % 60

                // It is not possible to make jumps of more than 6 minutes - reverse the direction
                if (delta > 30) {
                    delta -= 60
                } else if (delta < -30) {
                    delta += 60
                }
                if (isMoving && isLagging) {
                    if (Math.abs(delta) < 2) {
                        isLagging = false
                    }
                }

                var target = (minutesIndicator.value + delta)
                minutesIndicator.value += delta

                if (target < 0) {
                    var multiple = Math.ceil(target / 60)
                    target += ((-multiple + 1) * 60)
                }
                timePicker.minutes = (target % 60)
            } else { // Seconds
                // Map angular position to 0-59
                var s = remapAngle(angle, 60)
                var delta = (s - secondsIndicator.value) % 60

                // It is not possible to make jumps of more than 30 seconds - reverse the direction
                if (delta > 30) {
                    delta -= 60
                } else if (delta < -30) {
                    delta += 60
                }
                if (isMoving && isLagging) {
                    if (Math.abs(delta) < 2) {
                        isLagging = false
                    }
                }

                secondsIndicator.value += delta

                timePicker.seconds = s
            }
        }

        onPressed: {
            var coords = remapMouse(mouseX, mouseY)
            var radius = radiusForCoord(coords.x, coords.y)

            changingProperty = propertyForRadius(radius)
            if (changingProperty != 0) {
                preventStealing = true
                var angle = angleForCoord(coords.x, coords.y)

                isLagging = true
                updateForAngle(angle)
            } else {
                // Outside the seconds band - allow pass through to underlying component
                preventStealing = false
            }
        }
        onPositionChanged: {
            if (changingProperty > 0) {
                var coords = remapMouse(mouseX, mouseY)
                var angle = angleForCoord(coords.x, coords.y)

                isMoving = true
                updateForAngle(angle)
            }
        }
        onReleased: {
            changingProperty = 0
            isMoving = false
            isLagging = false
        }
    }
}

import QtQuick

// Physically-simulated M3 spring (mass 1). Interruptible: retargeting keeps velocity.
Item {
    id: root
    visible: false
    width: 0; height: 0

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real initial: NaN           // optional start value (animates toward target)
    property var spring: M3.spatialDefault
    property real precision: 0.0005

    Component.onCompleted: {
        value = isNaN(initial) ? target : initial
        if (value !== target) anim.running = true
    }
    onTargetChanged: anim.running = true

    // Restart the simulation without changing the target (e.g. after the value
    // was moved by a drag and must settle back to the same target).
    function kick() { anim.running = true }

    FrameAnimation {
        id: anim
        onTriggered: {
            const dt = Math.min(frameTime, 0.032)
            const k = root.spring.stiffness
            const c = 2 * root.spring.damping * Math.sqrt(k)
            const n = Math.max(1, Math.ceil(dt / 0.004))
            const h = dt / n
            let x = root.value
            let v = root.velocity
            for (let i = 0; i < n; i++) {
                v += (-k * (x - root.target) - c * v) * h
                x += v * h
            }
            if (Math.abs(x - root.target) < root.precision && Math.abs(v) < root.precision * 10) {
                x = root.target
                v = 0
                anim.running = false
            }
            root.value = x
            root.velocity = v
        }
    }
}

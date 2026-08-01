//@ probe peripheralBattery -g 420x520
/**
 * The devices tab and the bar indicator drawn from made-up peripherals: the views
 * take their list as a property, so no hardware and nothing stubbed. `-p scenario=edge`
 * is the pile that has looked wrong - empty and full, charging under the low
 * threshold, a name too long for its card, a device UPower knows nothing about.
 */
import ".." // The widget's own types and its PeripheralBattery singleton, via its qmldir
import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    property string scenario: "plain"
    property string view: "tab"

    /// UPower devices are objects; the views only ever read these fields
    function dev(type, model, percentage, state, extra) {
        return Object.assign({
            "type": type,
            "model": model,
            "nativePath": "",
            "percentage": percentage,
            "state": state,
            "timeToEmpty": 0,
            "timeToFull": 0
        }, extra ?? {});
    }

    // Emptiest first, the order the service hands over
    readonly property var sets: ({
        "plain": [
            root.dev(UPowerDeviceType.Keyboard, "MX Keys", 0.45, UPowerDeviceState.Discharging),
            root.dev(UPowerDeviceType.Mouse, "MX Master 3S", 0.62, UPowerDeviceState.Discharging),
            root.dev(UPowerDeviceType.Headset, "WH-1000XM4", 0.88, UPowerDeviceState.Discharging, {
                "timeToEmpty": 12600
            })
        ],
        "edge": [
            root.dev(UPowerDeviceType.Mouse, "Logitech G Pro X Superlight 2 DEX Wireless Gaming Mouse", 0, UPowerDeviceState.Empty),
            root.dev(UPowerDeviceType.Keyboard, "K380", 0.08, UPowerDeviceState.Discharging, {
                "timeToEmpty": 900
            }),
            root.dev(UPowerDeviceType.GamingInput, "DualSense", 0.15, UPowerDeviceState.Charging, {
                "timeToFull": 5400
            }),
            root.dev(UPowerDeviceType.Headphones, "WH-1000XM4", 0.5, UPowerDeviceState.Discharging, {
                "timeToEmpty": 7200
            }),
            root.dev(UPowerDeviceType.Pen, "Wacom Intuos Pen", 0.77, UPowerDeviceState.Unknown),
            root.dev(UPowerDeviceType.Unknown, "", 0.8, UPowerDeviceState.Discharging), // Not even a name
            root.dev(UPowerDeviceType.Wearable, "Galaxy Watch 6", 0.93, UPowerDeviceState.PendingCharge),
            root.dev(UPowerDeviceType.Speakers, "Soundcore Motion", 1, UPowerDeviceState.FullyCharged)
        ]
    })

    readonly property var devices: root.sets[root.scenario] ?? root.sets.plain

    function byModel(model) {
        return root.devices.find(d => d.model === model) ?? null;
    }

    implicitWidth: root.view === "bar" ? bar.implicitWidth : 0
    implicitHeight: root.view === "bar" ? bar.implicitHeight : 0

    function checks() {
        return [
            {
                "name": "a card per device, and the panel has height",
                "got": [cards.count, tab.height > 0],
                "want": [root.devices.length, true]
            },
            {
                "name": "a lone device takes the whole panel",
                "got": [tab.single, lone.single],
                "want": [false, true]
            },
            {
                "name": "empty counts as low, charging never does",
                "got": [PeripheralBattery.isLow(root.byModel("Logitech G Pro X Superlight 2 DEX Wireless Gaming Mouse")), PeripheralBattery.isLow(root.byModel("DualSense")), PeripheralBattery.isCharging(root.byModel("DualSense"))],
                "want": [root.scenario === "edge", false, root.scenario === "edge"]
            },
            {
                "name": "a device with no name still gets one",
                "got": PeripheralBattery.nameFor(root.byModel("")).length > 0,
                "want": root.scenario === "edge"
            },
            {
                "name": "with neither state nor time known the detail line stays empty",
                "got": PeripheralBattery.detailFor(root.byModel("Wacom Intuos Pen")),
                "want": ""
            },
            {
                "name": "time left reads as hours and minutes, and drops an empty half",
                "got": [PeripheralBattery.durationString(900), PeripheralBattery.durationString(5400), PeripheralBattery.durationString(7200)],
                "want": ["15 min", "1 h 30 min", "2 h"]
            },
            {
                "name": "showAll off keeps the emptiest one alone",
                "got": [bar.shownDevices.length, narrow.shownDevices.length, narrow.shownDevices[0].model],
                "want": [root.devices.length, 1, root.devices[0].model]
            }
        ];
    }

    PeripheralBatteryTab {
        id: tab
        visible: root.view === "tab"
        anchors.fill: parent
        devices: root.devices
    }

    PeripheralBatteryIndicator {
        id: bar
        visible: root.view === "bar"
        anchors.centerIn: parent
        devices: root.devices
        showAll: true
    }

    // Off-screen, for the checks above: the single-device layout and showAll: false
    PeripheralBatteryTab {
        id: lone
        visible: false
        devices: root.devices.slice(0, 1)
    }

    PeripheralBatteryIndicator {
        id: narrow
        visible: false
        devices: root.devices
        showAll: false
    }

    // The tab builds its own cards; this one only counts them
    Repeater {
        id: cards
        model: root.devices
        delegate: Item {}
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    readonly property var today: Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null

    // The card shows a window onto Weather.hourlyForecast. hourOffset is the target page,
    // shownOffset is what's on screen mid-slide.
    readonly property var allHourly: Weather.hourlyForecast ?? []
    readonly property int windowSize: 12
    readonly property int step: 6
    readonly property int maxOffset: Math.max(0, allHourly.length - windowSize)

    property int hourOffset: 0
    property int shownOffset: 0
    property int slideDir: 1
    property bool sliding: false

    function pageEntries(offset: int): var {
        return allHourly.slice(offset, offset + windowSize);
    }

    onMaxOffsetChanged: {
        // Reloads drop past hours, so keep the target in range.
        if (hourOffset > maxOffset)
            hourOffset = maxOffset;
    }

    onHourOffsetChanged: {
        if (hourOffset === shownOffset)
            return;
        slideDir = hourOffset > shownOffset ? 1 : -1;
        sliding = true;
        slideAnim.restart();
    }

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight
    Component.onCompleted: Weather.reload()

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.fillWidth: true

            Column {
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: Weather.city || Tr.tr("Loading...")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: Tokens.spacing.largeIncreased

                WeatherStat {
                    icon: "wb_twilight"
                    label: Tr.tr("Sunrise")
                    value: Weather.sunrise
                    colour: Colours.palette.m3tertiary
                }

                WeatherStat {
                    icon: "bedtime"
                    label: Tr.tr("Sunset")
                    value: Weather.sunset
                    colour: Colours.palette.m3tertiary
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: bigInfoRow.implicitHeight + Tokens.padding.small

            radius: Tokens.rounding.extraLarge * 2
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: bigInfoRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.icon
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
                    color: Colours.palette.m3secondary
                    animate: true
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Tokens.spacing.small

                    StyledText {
                        text: Weather.temp
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Medium).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.leftMargin: Tokens.padding.extraSmall
                        text: Weather.description
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            DetailCard {
                icon: "water_drop"
                label: Tr.tr("Humidity")
                value: Strings.percent(Weather.humidity)
                colour: Colours.palette.m3secondary
            }
            DetailCard {
                icon: "thermostat"
                label: Tr.trCtx("Feels like", "apparent temperature")
                value: Weather.feelsLike
                colour: Colours.palette.m3primary
            }
            DetailCard {
                icon: "air"
                label: Tr.tr("Wind")
                value: Weather.windSpeed ? Tr.tr("%1 km/h").arg(Weather.windSpeed) : "--"
                colour: Colours.palette.m3tertiary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            visible: root.allHourly.length > 0
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Hourly forecast")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
            }

            ArrowButton {
                icon: "chevron_left"
                active: root.hourOffset > 0
                onClicked: {
                    if (!root.sliding)
                        root.hourOffset = Math.max(0, root.hourOffset - root.step);
                }
            }

            ArrowButton {
                icon: "chevron_right"
                active: root.hourOffset < root.maxOffset
                onClicked: {
                    if (!root.sliding)
                        root.hourOffset = Math.min(root.maxOffset, root.hourOffset + root.step);
                }
            }
        }

        StyledClippingRect {
            id: hourlyCard

            Layout.fillWidth: true
            visible: root.allHourly.length > 0
            implicitHeight: pageCur.implicitHeight

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            // Two pages side by side. The strip slides, the card stays put.
            Item {
                id: strip

                width: hourlyCard.width
                height: hourlyCard.height

                HourPage {
                    id: pageCur

                    width: strip.width
                    entries: root.pageEntries(root.shownOffset)
                    showNow: root.shownOffset === 0
                }

                HourPage {
                    id: pageNext

                    x: root.slideDir * strip.width
                    width: strip.width
                    visible: root.sliding
                    entries: root.pageEntries(root.hourOffset)
                    showNow: root.hourOffset === 0
                }
            }

            SequentialAnimation {
                id: slideAnim

                Anim {
                    target: strip
                    property: "x"
                    to: -root.slideDir * strip.width
                    type: Anim.DefaultSpatial
                }

                // The incoming page becomes the shown one. They render identically, so it's seamless.
                ScriptAction {
                    script: {
                        root.shownOffset = root.hourOffset;
                        strip.x = 0;
                        root.sliding = false;
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            Layout.leftMargin: Tokens.padding.medium
            visible: forecastRepeater.count > 0
            text: Tr.tr("7-day forecast")
            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
            color: Colours.palette.m3onSurface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Repeater {
                id: forecastRepeater

                model: Weather.forecast

                StyledRect {
                    id: forecastItem

                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: forecastItemColumn.implicitHeight + Tokens.padding.medium * 2

                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainer

                    ColumnLayout {
                        id: forecastItemColumn

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: forecastItem.index === 0 ? Tr.trCtx("Today", "forecast column") : new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.topMargin: -Tokens.spacing.extraSmall
                            Layout.alignment: Qt.AlignHCenter
                            text: new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                            font: Tokens.font.body.small
                            opacity: 0.7
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: forecastItem.modelData.icon
                            fontStyle: Tokens.font.icon.extraLarge
                            color: Colours.palette.m3secondary
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                const min = Weather.formatTemp(forecastItem.modelData.minTempC, true);
                                const max = Weather.formatTemp(forecastItem.modelData.maxTempC, true);
                                return Tr.trCtx("%1 / %2", "min/max temperature").arg(min).arg(max);
                            }
                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3tertiary
                        }
                    }
                }
            }
        }
    }

    // One page of hours: the temperature curve and the hour columns.
    component HourPage: Item {
        id: page

        required property var entries
        required property bool showNow

        readonly property real minT: entries.length > 0 ? Math.min(...entries.map(h => h.tempC)) : 0
        readonly property real maxT: entries.length > 0 ? Math.max(...entries.map(h => h.tempC)) : 0

        function formatHour(h: int): string {
            if (Units.twelveHourClock) {
                const suffix = h >= 12 ? "PM" : "AM";
                const hr = h % 12 === 0 ? 12 : h % 12;
                return `${hr}${suffix}`;
            }
            return `${String(h).padStart(2, "0")}:00`;
        }

        // Midnight shows the weekday instead of 00:00.
        function hourLabel(entry: var): string {
            if (entry.hour === 0) {
                const d = new Date(entry.timestamp.replace("T", " ").replace(/-/g, "/"));
                return d.toLocaleDateString(Qt.locale(), "ddd");
            }
            return formatHour(entry.hour);
        }

        implicitHeight: pageCol.implicitHeight + Tokens.padding.medium * 2
        height: implicitHeight

        ColumnLayout {
            id: pageCol

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: 0

            Item {
                id: chart

                readonly property real padTop: 26
                readonly property real padBottom: 12
                readonly property real colW: width / Math.max(1, page.entries.length)
                readonly property real plotH: height - padTop - padBottom

                function xAt(i: int): real {
                    return colW * (i + 0.5);
                }

                function yAt(temp: real): real {
                    const range = page.maxT - page.minT;
                    const t = range > 0 ? (temp - page.minT) / range : 0.5;
                    return padTop + plotH * (1 - t);
                }

                // Smooth curve: cubic segments with horizontal handles.
                readonly property string curvePath: {
                    const n = page.entries.length;
                    if (n < 2)
                        return "";
                    let d = `M ${xAt(0)} ${yAt(page.entries[0].tempC)}`;
                    for (let i = 1; i < n; i++) {
                        const x0 = xAt(i - 1);
                        const y0 = yAt(page.entries[i - 1].tempC);
                        const x1 = xAt(i);
                        const y1 = yAt(page.entries[i].tempC);
                        const cx = (x0 + x1) / 2;
                        d += ` C ${cx} ${y0}, ${cx} ${y1}, ${x1} ${y1}`;
                    }
                    return d;
                }

                Layout.fillWidth: true
                Layout.preferredHeight: 120

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillGradient: LinearGradient {
                            x1: 0
                            y1: 0
                            x2: 0
                            y2: chart.height

                            GradientStop {
                                position: 0
                                color: Qt.alpha(Colours.palette.m3primary, 0.28)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Colours.palette.m3primary, 0)
                            }
                        }

                        PathSvg {
                            path: chart.curvePath ? `${chart.curvePath} L ${chart.xAt(page.entries.length - 1)} ${chart.height} L ${chart.xAt(0)} ${chart.height} Z` : ""
                        }
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Colours.palette.m3primary
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: chart.curvePath
                        }
                    }
                }

                Repeater {
                    model: page.entries

                    Item {
                        id: dot

                        required property int index
                        required property var modelData

                        readonly property bool isNow: page.showNow && index === 0
                        readonly property bool isExtreme: modelData.tempC === page.maxT || modelData.tempC === page.minT

                        x: chart.xAt(index)
                        y: chart.yAt(modelData.tempC)

                        StyledRect {
                            anchors.centerIn: parent
                            implicitWidth: dot.isExtreme ? 12 : 8
                            implicitHeight: implicitWidth
                            radius: Tokens.rounding.full
                            color: dot.isNow ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -height - 8
                            text: Weather.formatTemp(dot.modelData.tempC, true)
                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                            color: dot.isNow ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                        }
                    }
                }
            }

            // Columns use chart.xAt so they line up with the dots.
            Item {
                id: hourRow

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                implicitHeight: sizer.implicitHeight

                // Never shown. Gives the row the height of a real cell.
                HourCell {
                    id: sizer

                    opacity: 0
                    enabled: false
                    label: "00:00"
                    icon: "cloud"
                    precip: 100
                }

                Repeater {
                    model: page.entries

                    HourCell {
                        id: cell

                        required property int index
                        required property var modelData

                        readonly property bool isNow: page.showNow && index === 0

                        x: chart.xAt(index) - width / 2
                        width: chart.colW

                        now: isNow
                        midnight: modelData.hour === 0 && !isNow
                        label: isNow ? Tr.trCtx("Now", "hourly forecast, current hour") : page.hourLabel(modelData)
                        icon: modelData.icon
                        precip: modelData.precipChance
                    }
                }
            }
        }
    }

    component HourCell: ColumnLayout {
        id: cell

        property string label
        property string icon
        property int precip
        property bool now
        property bool midnight

        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: cell.label
            font: Tokens.font.body.builders.small.weight(cell.now || cell.midnight ? Font.DemiBold : Font.Normal).build()
            color: cell.now ? Colours.palette.m3tertiary : (cell.midnight ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: cell.icon
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3secondary
        }

        // Hidden under 20%, but keeps its space so columns don't shift.
        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: rainLabel.implicitWidth + Tokens.padding.small * 2
            implicitHeight: rainLabel.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3secondary, 0.1 + 0.3 * (cell.precip / 100))
            opacity: cell.precip >= 20 ? 1 : 0

            StyledText {
                id: rainLabel

                anchors.centerIn: parent
                text: Strings.percent(cell.precip)
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Colours.palette.m3secondary
            }
        }
    }

    component ArrowButton: StyledRect {
        id: arrow

        required property string icon
        property bool active: true

        signal clicked

        implicitWidth: 36
        implicitHeight: 36
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: active ? 1 : 0.38

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        StateLayer {
            radius: Tokens.rounding.full
            disabled: !arrow.active
            color: Colours.palette.m3onSurface
            onClicked: arrow.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: arrow.icon
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.medium
        }
    }

    component DetailCard: StyledRect {
        id: detailRoot

        property string icon
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: detailRoot.icon
                color: detailRoot.colour
                fontStyle: Tokens.font.icon.large
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: detailRoot.label
                    font: Tokens.font.body.small
                    opacity: 0.7
                    horizontalAlignment: Text.AlignLeft
                }
                StyledText {
                    text: detailRoot.value
                    font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    component WeatherStat: Row {
        id: weatherStat

        property string icon
        property string label
        property string value
        property color colour

        spacing: Tokens.spacing.small

        MaterialIcon {
            text: weatherStat.icon
            fontStyle: Tokens.font.icon.extraLarge
            color: weatherStat.colour
        }

        Column {
            StyledText {
                text: weatherStat.label
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                text: weatherStat.value
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
            }
        }
    }
}

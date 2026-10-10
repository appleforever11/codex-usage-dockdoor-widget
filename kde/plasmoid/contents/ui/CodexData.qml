import QtQuick
import QtQuick.LocalStorage

// Data bridge to the codex-usage-helper daemon. Pure-QML plasmoids cannot
// spawn processes or read files, so everything flows over loopback HTTP
// (Qt's QML XHR has no same-origin restriction) with a localStorage copy of
// the last good snapshot for offline rendering.
QtObject {
    id: dataSource

    // --- connection --------------------------------------------------------
    property int helperPort: 47631
    property int pollIntervalMs: 5000
    property string baseUrl: "http://127.0.0.1:" + helperPort

    // --- state -------------------------------------------------------------
    property var snapshot: null
    property bool connected: false
    property date lastGoodAt
    property int nowEpoch: Math.floor(Date.now() / 1000)
    property string statusMessage: ""

    // Fires whenever `nowEpoch` advances (1 s cadence, shared by countdowns).
    signal snapshotArrived()
    // Fires only when a refreshNow() cycle produced a newer snapshot (or
    // gave up) — what spinner UIs should wait for.
    signal freshSnapshotArrived()
    signal connectionChanged()

    // --- 1 s heartbeat for countdown labels --------------------------------
    property Timer _clock: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dataSource.nowEpoch = Math.floor(Date.now() / 1000)
    }

    property Timer _poll: Timer {
        interval: Math.max(2000, dataSource.pollIntervalMs)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: dataSource.poll()
    }

    function poll() {
        getJSON("/snapshot", function(ok, payload) {
            if (ok && payload && payload.usage !== undefined) {
                dataSource.applySnapshot(payload);
            } else {
                if (dataSource.connected) {
                    dataSource.connected = false;
                    dataSource.statusMessage = "Helper unreachable — showing the last snapshot";
                }
                if (!dataSource.snapshot) {
                    const cached = loadCachedSnapshot();
                    if (cached)
                        dataSource.snapshot = cached;
                }
            }
        });
    }

    // Apply a snapshot document, updating the freshness bookkeeping shared by
    // the periodic poll and the refresh flow.
    function applySnapshot(payload) {
        snapshot = payload;
        connected = true;
        lastGoodAt = new Date();
        statusMessage = "";
        cacheSnapshot(payload);
        snapshotArrived();
        if (_fastPoll.running && Number(payload.generatedAt || 0) > _generatedAtSeen) {
            _fastPoll.stop();
            _refreshWatchdog.stop();
            freshSnapshotArrived();
        }
        _generatedAtSeen = Math.max(_generatedAtSeen, Number(payload.generatedAt || 0));
    }

    // While a refresh cycle runs server-side, poll fast until the snapshot's
    // generatedAt advances; a watchdog bounds the wait either way.
    property int _generatedAtSeen: 0
    property Timer _fastPoll: Timer {
        interval: 600
        repeat: true
        onTriggered: dataSource.poll()
    }
    property Timer _refreshWatchdog: Timer {
        interval: 25000
        onTriggered: {
            dataSource._fastPoll.stop();
            dataSource.freshSnapshotArrived();
        }
    }

    function refreshNow() {
        // POST /refresh asks the helper for a full account cycle. Newer
        // helpers answer 202 immediately and stream the fresh snapshot into
        // /snapshot (handled by the fast poll); older helpers block and
        // answer with the document itself.
        postJSON("/refresh", {}, function(ok, payload) {
            if (ok && payload && payload.usage !== undefined) {
                dataSource.applySnapshot(payload);
                dataSource.freshSnapshotArrived();
                return;
            }
            if (ok) {
                _fastPoll.restart();
                _refreshWatchdog.restart();
                return;
            }
            dataSource.statusMessage = "Refresh failed — is codex-usage-helper running?";
            dataSource.snapshotArrived();
            dataSource.freshSnapshotArrived();
        });
    }

    function setModel(model, reasoningEffort, fast, handler) {
        postJSON("/model", {
            model: model,
            reasoning: reasoningEffort,
            serviceTier: fast ? "fast" : "default",
        }, function(ok, payload) {
            if (ok && payload && payload.ok) {
                poll();
            }
            if (handler)
                handler(ok && payload && payload.ok === true, payload ? payload.error : "request failed");
        });
    }

    function openSession(sessionId, handler) {
        postJSON("/open", { sessionId: sessionId }, function(ok, payload) {
            if (handler)
                handler(ok && payload && payload.ok === true);
        });
    }

    // Keep the daemon's dataSource-affecting settings aligned with the plasmoid's.
    function pushSettings(cfg) {
        postJSON("/settings", {
            port: cfg.helperPort,
            refreshSeconds: cfg.helperRefreshSeconds,
            sessionsFolder: cfg.sessionsFolder,
            usageStatePath: cfg.usageStatePath,
            recentLimit: cfg.recentSessionCount,
            usageBudgetMillions: cfg.usageBudgetMillions,
            usageWindowHours: cfg.usageWindowHours,
            dailyGoalMillions: cfg.dailyGoalMillions,
            chatViewerCommand: cfg.chatViewerCommand,
        }, function(ok) { if (ok) poll(); });
    }

    // --- transport ---------------------------------------------------------
    function getJSON(path, handler) {
        request("GET", path, null, handler);
    }

    function postJSON(path, body, handler) {
        request("POST", path, JSON.stringify(body), handler);
    }

    function request(method, path, body, handler) {
        const xhr = new XMLHttpRequest();
        xhr.open(method, baseUrl + path);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let payload = null;
            try {
                payload = JSON.parse(xhr.responseText);
            } catch (e) {
                payload = null;
            }
            handler(xhr.status >= 200 && xhr.status < 300, payload);
        };
        // Generous timeout: POST /refresh performs a live account fetch.
        xhr.timeout = 30000;
        xhr.send(body);
    }

    // --- offline cache -----------------------------------------------------
    function _db() {
        return LocalStorage.openDatabaseSync("codex-usage-plasmoid", "1", "Codex Usage snapshot cache", 1);
    }

    function cacheSnapshot(payload) {
        try {
            const db = _db();
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS cache (k TEXT PRIMARY KEY, v TEXT)");
                tx.executeSql("INSERT OR REPLACE INTO cache (k, v) VALUES (?, ?)", ["snapshot", JSON.stringify(payload)]);
            });
        } catch (e) {}
    }

    function loadCachedSnapshot() {
        try {
            const db = _db();
            let result = null;
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS cache (k TEXT PRIMARY KEY, v TEXT)");
                const rows = tx.executeSql("SELECT v FROM cache WHERE k = ?", ["snapshot"]);
                if (rows.rows.length > 0)
                    result = JSON.parse(rows.rows.item(0).v);
            });
            return result;
        } catch (e) {
            return null;
        }
    }

    // --- convenience accessors used by the representations -----------------
    readonly property var usage: snapshot ? snapshot.usage : null
    readonly property var telemetry: snapshot ? snapshot.telemetry : null
    readonly property var analytics: snapshot ? snapshot.analytics : null
    readonly property var modelSettings: snapshot ? snapshot.modelSettings : null
    readonly property var availableModels: snapshot && snapshot.availableModels ? snapshot.availableModels : []
    readonly property var dockCards: snapshot && snapshot.dockCards ? snapshot.dockCards : []
    readonly property var counts: snapshot ? snapshot.counts : { projectCount: 0, activeCount: 0, chatCount: 0, taskCount: 0 }

    function rotatingCard(preferredKind, intervalSeconds, pinnedEpoch) {
        const cards = dockCards;
        if (!cards || cards.length === 0) {
            return { title: "Codex", subtitle: "Waiting for dataSource", shortLabel: "Codex", percentRemaining: null, kind: "usage" };
        }
        const normalized = String(preferredKind || "Auto").toLowerCase();
        if (normalized !== "auto") {
            for (let i = 0; i < cards.length; ++i) {
                if (String(cards[i].kind).toLowerCase() === normalized)
                    return cards[i];
            }
        }
        const interval = Math.max(intervalSeconds, 2);
        const epoch = pinnedEpoch !== undefined ? pinnedEpoch : nowEpoch;
        const index = Math.floor(epoch / interval) % cards.length;
        return cards[index];
    }
}

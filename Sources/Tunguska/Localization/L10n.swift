import Foundation

/// Runtime localization layer. Every user-facing string resolves through this
/// lookup so the active language (`AppSettings.appLanguage`) can change at
/// runtime without restarting the app. Translations live in the static
/// four-language `table`; the completeness test in `TunguskaTests` guards that
/// every key has a translation for all four supported languages.
enum L10n {
    /// Stable string-key namespace. Reference these constants at call sites.
    enum Key {
        static let appName = "app.name"

        static let commonOK = "common.ok"
        static let commonSelect = "common.select"
        static let commonDelete = "common.delete"
        static let commonDiscard = "common.discard"
        static let commonName = "common.name"
        static let commonEndpoint = "common.endpoint"
        static let commonFlow = "common.flow"
        static let commonDefault = "common.default"
        static let commonSNI = "common.sni"
        static let commonOn = "common.on"
        static let commonOff = "common.off"
        static let commonEnabled = "common.enabled"
        static let commonDisabled = "common.disabled"
        static let commonNone = "common.none"
        static let commonAny = "common.any"
        static let commonReset = "common.reset"
        static let commonPort = "common.port"
        static let commonProtocol = "common.protocol"
        static let commonCopy = "common.copy"
        static let commonProfile = "common.profile"
        static let commonNoProfile = "common.noProfile"
        static let commonNoProfileSelected = "common.noProfileSelected"
        static let commonSafeMode = "common.safeMode"
        static let commonLocalProxy = "common.localProxy"
        static let commonDebugEndpoints = "common.debugEndpoints"
        static let commonSystemDns = "common.systemDns"
        static let commonDisconnect = "common.disconnect"
        static let commonConnect = "common.connect"

        static let sidebarHome = "sidebar.home"
        static let sidebarProfiles = "sidebar.profiles"
        static let sidebarRouting = "sidebar.routing"
        static let sidebarSecurity = "sidebar.security"
        static let sidebarSettings = "sidebar.settings"

        static let settingsLanguage = "settings.language"
        static let settingsLanguageHint = "settings.languageHint"
        static let settingsAppearanceSystem = "settings.appearanceSystem"
        static let settingsAppearanceLight = "settings.appearanceLight"
        static let settingsAppearanceDark = "settings.appearanceDark"

        static let homeTagline = "home.tagline"
        static let homeConnection = "home.connection"
        static let homeImportProfileHint = "home.importProfileHint"
        static let homeMode = "home.mode"
        static let homeModeTun = "home.modeTun"
        static let homeModeSystemProxy = "home.modeSystemProxy"
        static let homeHelpTun = "home.helpTun"
        static let homeHelpSystemProxy = "home.helpSystemProxy"
        static let homeStartVPN = "home.startVPN"
        static let homeTraffic = "home.traffic"
        static let homeTrafficDown = "home.trafficDown"
        static let homeTrafficUp = "home.trafficUp"
        static let homeTrafficEmpty = "home.trafficEmpty"
        static let homeTrafficTotal = "home.trafficTotal"
        static let homeSession = "home.session"
        static let homeTunnelScope = "home.tunnelScope"
        static let homePackages = "home.packages"
        static let homeAllApplications = "home.allApplications"
        static let homeIdentifiersFormat = "home.identifiersFormat"
        static let homeDnsLabel = "home.dnsLabel"
        static let homeDnsVpnFormat = "home.dnsVpnFormat"
        static let homeDnsCustomFormat = "home.dnsCustomFormat"
        static let homeRoutingRules = "home.routingRules"
        static let homeRegionalBypass = "home.regionalBypass"
        static let homeSafetyPanel = "home.safetyPanel"
        static let homeRuntimeIntegrity = "home.runtimeIntegrity"
        static let homeIntegrityConnectedUI = "home.integrityConnectedUI"
        static let homeIntegrityLoopback = "home.integrityLoopback"
        static let homeIntegritySecrets = "home.integritySecrets"
        static let homeIntegrityHelper = "home.integrityHelper"
        static let homeTunnelErrorTitle = "home.tunnelErrorTitle"
        static let homeSplitTunnelFull = "home.splitTunnelFull"
        static let homeSplitTunnelAllowlist = "home.splitTunnelAllowlist"
        static let homeSplitTunnelDenylist = "home.splitTunnelDenylist"

        static let profilesSelectOrImport = "profiles.selectOrImport"
        static let profilesStagedImport = "profiles.stagedImport"
        static let profilesValidateImport = "profiles.validateImport"
        static let profilesImportNeverAutoConnects = "profiles.importNeverAutoConnects"
        static let profilesSaveToKeychain = "profiles.saveToKeychain"
        static let profilesDiscardPreview = "profiles.discardPreview"
        static let profilesActive = "profiles.active"
        static let profilesActiveProfile = "profiles.activeProfile"
        static let profilesRealityPublicKey = "profiles.realityPublicKey"
        static let profilesRealityShortId = "profiles.realityShortId"
        static let profilesDnsVpnServersFormat = "profiles.dnsVpnServersFormat"
        static let profilesDnsCustomFormat = "profiles.dnsCustomFormat"

        static let routingEmpty = "routing.empty"
        static let routingRussiaToggle = "routing.russiaToggle"
        static let routingGeoipHint = "routing.geoipHint"
        static let routingCustomDirectDomains = "routing.customDirectDomains"
        static let routingCustomDirectDomainsHint = "routing.customDirectDomainsHint"
        static let routingRoutePreview = "routing.routePreview"
        static let routingFieldAppBundleID = "routing.fieldAppBundleID"
        static let routingFieldDestinationHost = "routing.fieldDestinationHost"
        static let routingFieldDestinationIp = "routing.fieldDestinationIp"
        static let routingEvaluate = "routing.evaluate"
        static let routingOfflineHint = "routing.offlineHint"
        static let routingResolvedPolicy = "routing.resolvedPolicy"
        static let routingBlockRulesFirst = "routing.blockRulesFirst"
        static let routingGeneratedRegionalRules = "routing.generatedRegionalRules"
        static let routingNonBlockRules = "routing.nonBlockRules"
        static let routingInvalidPolicy = "routing.invalidPolicy"
        static let routingCriteriaExact = "routing.criteriaExact"
        static let routingCriteriaSuffix = "routing.criteriaSuffix"
        static let routingCriteriaKeyword = "routing.criteriaKeyword"
        static let routingCriteriaCidr = "routing.criteriaCidr"
        static let routingCriteriaGeosite = "routing.criteriaGeosite"
        static let routingCriteriaGeoip = "routing.criteriaGeoip"
        static let routingCriteriaAsn = "routing.criteriaAsn"
        static let routingCriteriaApp = "routing.criteriaApp"
        static let routingNoCriteria = "routing.noCriteria"

        static let securityLocalStorage = "security.localStorage"
        static let securityProfileCount = "security.profileCount"
        static let securityStorageLabel = "security.storageLabel"
        static let securityStorageValue = "security.storageValue"
        static let securityAutoConnectAfterImport = "security.autoConnectAfterImport"
        static let securityEncryptedBackup = "security.encryptedBackup"
        static let securityBackupDescription = "security.backupDescription"
        static let securityBackupPassphrase = "security.backupPassphrase"
        static let securityExportBackup = "security.exportBackup"
        static let securityRestoreBackup = "security.restoreBackup"
        static let securityBackupWrittenFormat = "security.backupWrittenFormat"
        static let securityRestoredOneFormat = "security.restoredOneFormat"
        static let securityRestoredManyFormat = "security.restoredManyFormat"
        static let securityRedactedDiagnostics = "security.redactedDiagnostics"
        static let securityDiagnosticsDescription = "security.diagnosticsDescription"
        static let securityGenerateReport = "security.generateReport"
        static let securitySafetyPosture = "security.safetyPosture"
        static let securitySafeModeDetail = "security.safeModeDetail"
        static let securityKeptDisabled = "security.keptDisabled"
        static let securityFailClosed = "security.failClosed"
        static let securityFailClosedDetail = "security.failClosedDetail"
        static let securityConnectionInvariants = "security.connectionInvariants"
        static let securityInvariantConnected = "security.invariantConnected"
        static let securityInvariantDesired = "security.invariantDesired"
        static let securityInvariantSecrets = "security.invariantSecrets"
        static let securityInvariantLoopback = "security.invariantLoopback"
        static let securityRuntimePackaging = "security.runtimePackaging"
        static let securityAppTarget = "security.appTarget"
        static let securityAppTargetValue = "security.appTargetValue"
        static let securityTunnelTarget = "security.tunnelTarget"
        static let securityTunnelTargetValue = "security.tunnelTargetValue"
        static let securityEngine = "security.engine"
        static let securityEngineValue = "security.engineValue"
        static let securityHelperInstallNote = "security.helperInstallNote"
        static let securityGatekeeperNote = "security.gatekeeperNote"
        static let securityPass = "security.pass"
        static let securityRestricted = "security.restricted"

        static let menubarSystemProxyFormat = "menubar.systemProxyFormat"
        static let menubarTunMode = "menubar.tunMode"
        static let menubarOpenApp = "menubar.openApp"
        static let menubarQuitApp = "menubar.quitApp"

        static let stateDisconnected = "state.disconnected"
        static let stateConnecting = "state.connecting"
        static let stateConnected = "state.connected"
        static let stateDisconnecting = "state.disconnecting"
        static let stateFailed = "state.failed"
        static let stateUnavailable = "state.unavailable"
        static let stateDisconnectedDetail = "state.disconnectedDetail"
        static let stateConnectingDetail = "state.connectingDetail"
        static let stateConnectedDetail = "state.connectedDetail"
        static let stateDisconnectingDetail = "state.disconnectingDetail"

        static let errorInvalidProfileFormat = "error.invalidProfileFormat"
        static let errorVpnMustBeStopped = "error.vpnMustBeStopped"
        static let errorDeleteWhileConnected = "error.deleteWhileConnected"
        static let errorSelectProfileFirst = "error.selectProfileFirst"
        static let errorInvalidDestinationPort = "error.invalidDestinationPort"
        static let errorNoProfileToConnect = "error.noProfileToConnect"
        static let errorLoginItemEnableFormat = "error.loginItemEnableFormat"
        static let errorLoginItemDisableFormat = "error.loginItemDisableFormat"
        static let errorServiceNotChecked = "error.serviceNotChecked"
        static let errorHelperStartFailed = "error.helperStartFailed"
        static let errorNoLiveSession = "error.noLiveSession"
        static let errorNoTunInterface = "error.noTunInterface"
        static let errorHelperStopFailed = "error.helperStopFailed"
        static let errorIncompleteResponse = "error.incompleteResponse"
        static let errorNoTunReported = "error.noTunReported"
        static let errorServiceFailure = "error.serviceFailure"
    }

    /// Four-language string table keyed by the stable keys above. English is
    /// the fallback language; every key is expected to carry all four
    /// translations (enforced by the completeness test in `TunguskaTests`).
    static let table: [String: [AppLanguage: String]] = [
        Key.appName: [.en: "Tunguska", .de: "Tunguska", .ru: "Tunguska", .zh: "Tunguska"],

        Key.commonOK: [.en: "OK", .de: "OK", .ru: "OK", .zh: "好"],
        Key.commonSelect: [.en: "Select", .de: "Auswählen", .ru: "Выбрать", .zh: "选择"],
        Key.commonDelete: [.en: "Delete", .de: "Löschen", .ru: "Удалить", .zh: "删除"],
        Key.commonDiscard: [.en: "Discard", .de: "Verwerfen", .ru: "Отменить", .zh: "放弃"],
        Key.commonName: [.en: "Name", .de: "Name", .ru: "Имя", .zh: "名称"],
        Key.commonEndpoint: [.en: "Endpoint", .de: "Endpunkt", .ru: "Конечная точка", .zh: "端点"],
        Key.commonFlow: [.en: "Flow", .de: "Flow", .ru: "Поток", .zh: "Flow"],
        Key.commonDefault: [.en: "Default", .de: "Standard", .ru: "По умолчанию", .zh: "默认"],
        Key.commonSNI: [.en: "SNI", .de: "SNI", .ru: "SNI", .zh: "SNI"],
        Key.commonOn: [.en: "On", .de: "Ein", .ru: "Вкл.", .zh: "开启"],
        Key.commonOff: [.en: "Off", .de: "Aus", .ru: "Выкл.", .zh: "关闭"],
        Key.commonEnabled: [.en: "Enabled", .de: "Aktiviert", .ru: "Включено", .zh: "已启用"],
        Key.commonDisabled: [.en: "Disabled", .de: "Deaktiviert", .ru: "Отключено", .zh: "已禁用"],
        Key.commonNone: [.en: "None", .de: "Keine", .ru: "Нет", .zh: "无"],
        Key.commonAny: [.en: "Any", .de: "Beliebig", .ru: "Любой", .zh: "任意"],
        Key.commonReset: [.en: "Reset", .de: "Zurücksetzen", .ru: "Сбросить", .zh: "重置"],
        Key.commonPort: [.en: "Port", .de: "Port", .ru: "Порт", .zh: "端口"],
        Key.commonProtocol: [.en: "Protocol", .de: "Protokoll", .ru: "Протокол", .zh: "协议"],
        Key.commonCopy: [.en: "Copy", .de: "Kopieren", .ru: "Копировать", .zh: "复制"],
        Key.commonProfile: [.en: "Profile", .de: "Profil", .ru: "Профиль", .zh: "配置文件"],
        Key.commonNoProfile: [.en: "No profile", .de: "Kein Profil", .ru: "Нет профиля", .zh: "无配置文件"],
        Key.commonNoProfileSelected: [.en: "No profile selected", .de: "Kein Profil ausgewählt", .ru: "Профиль не выбран", .zh: "未选择配置文件"],
        Key.commonSafeMode: [.en: "Safe mode", .de: "Sicherer Modus", .ru: "Безопасный режим", .zh: "安全模式"],
        Key.commonLocalProxy: [.en: "Local proxy", .de: "Lokaler Proxy", .ru: "Локальный прокси", .zh: "本地代理"],
        Key.commonDebugEndpoints: [.en: "Debug endpoints", .de: "Debug-Endpunkte", .ru: "Отладочные конечные точки", .zh: "调试端点"],
        Key.commonSystemDns: [.en: "System DNS", .de: "System-DNS", .ru: "Системный DNS", .zh: "系统 DNS"],
        Key.commonDisconnect: [.en: "Disconnect", .de: "Trennen", .ru: "Отключить", .zh: "断开连接"],
        Key.commonConnect: [.en: "Connect", .de: "Verbinden", .ru: "Подключить", .zh: "连接"],

        Key.sidebarHome: [.en: "Home", .de: "Startseite", .ru: "Главная", .zh: "主页"],
        Key.sidebarProfiles: [.en: "Profiles", .de: "Profile", .ru: "Профили", .zh: "配置文件"],
        Key.sidebarRouting: [.en: "Routing", .de: "Routing", .ru: "Маршрутизация", .zh: "路由"],
        Key.sidebarSecurity: [.en: "Security", .de: "Sicherheit", .ru: "Безопасность", .zh: "安全"],
        Key.sidebarSettings: [.en: "Settings", .de: "Einstellungen", .ru: "Настройки", .zh: "设置"],

        Key.settingsLanguage: [.en: "Language", .de: "Sprache", .ru: "Язык", .zh: "语言"],
        Key.settingsLanguageHint: [
            .en: "Changes apply immediately without restarting.",
            .de: "Änderungen werden sofort ohne Neustart übernommen.",
            .ru: "Изменения применяются сразу, без перезапуска.",
            .zh: "更改立即生效，无需重启。",
        ],
        Key.settingsAppearanceSystem: [.en: "System", .de: "System", .ru: "Системная", .zh: "跟随系统"],
        Key.settingsAppearanceLight: [.en: "Light", .de: "Hell", .ru: "Светлая", .zh: "浅色"],
        Key.settingsAppearanceDark: [.en: "Dark", .de: "Dunkel", .ru: "Тёмная", .zh: "深色"],

        Key.homeTagline: [
            .en: "Native Apple Silicon VLESS + REALITY client",
            .de: "Nativer Apple-Silicon-Client für VLESS + REALITY",
            .ru: "Нативный клиент VLESS + REALITY для Apple Silicon",
            .zh: "原生 Apple Silicon VLESS + REALITY 客户端",
        ],
        Key.homeConnection: [.en: "Connection", .de: "Verbindung", .ru: "Подключение", .zh: "连接"],
        Key.homeImportProfileHint: [
            .en: "Import a VLESS + REALITY profile to prepare the tunnel.",
            .de: "Importiere ein VLESS-+-REALITY-Profil, um den Tunnel vorzubereiten.",
            .ru: "Импортируйте профиль VLESS + REALITY, чтобы подготовить туннель.",
            .zh: "导入 VLESS + REALITY 配置文件以准备隧道。",
        ],
        Key.homeMode: [.en: "Mode", .de: "Modus", .ru: "Режим", .zh: "模式"],
        Key.homeModeTun: [.en: "TUN", .de: "TUN", .ru: "TUN", .zh: "TUN"],
        Key.homeModeSystemProxy: [.en: "System Proxy", .de: "System-Proxy", .ru: "Системный прокси", .zh: "系统代理"],
        Key.homeHelpTun: [
            .en: "TUN mode captures all system traffic through a virtual interface.",
            .de: "Der TUN-Modus leitet den gesamten Systemverkehr über eine virtuelle Schnittstelle.",
            .ru: "Режим TUN перенаправляет весь системный трафик через виртуальный интерфейс.",
            .zh: "TUN 模式通过虚拟接口接管所有系统流量。",
        ],
        Key.homeHelpSystemProxy: [
            .en: "System Proxy mode routes apps that honor the macOS proxy settings through %@:%d.",
            .de: "Der System-Proxy-Modus leitet Apps, die die macOS-Proxyeinstellungen beachten, über %@:%d.",
            .ru: "Режим системного прокси направляет через %@:%d приложения, которые учитывают настройки прокси macOS.",
            .zh: "系统代理模式通过 %@:%d 路由遵循 macOS 代理设置的应用。",
        ],
        Key.homeStartVPN: [.en: "Start VPN", .de: "VPN starten", .ru: "Запустить VPN", .zh: "启动 VPN"],
        Key.homeTraffic: [.en: "Traffic", .de: "Datenverkehr", .ru: "Трафик", .zh: "流量"],
        Key.homeTrafficDown: [.en: "Down", .de: "Empfang", .ru: "Приём", .zh: "下载"],
        Key.homeTrafficUp: [.en: "Up", .de: "Senden", .ru: "Передача", .zh: "上传"],
        Key.homeTrafficEmpty: [
            .en: "Connect the VPN to see live speed, session traffic, and volume totals.",
            .de: "Verbinde das VPN, um Live-Geschwindigkeit, Sitzungsverkehr und Gesamtvolumen zu sehen.",
            .ru: "Подключите VPN, чтобы видеть скорость в реальном времени, трафик сессии и общие объёмы.",
            .zh: "连接 VPN 以查看实时速度、会话流量和总量。",
        ],
        Key.homeTrafficTotal: [.en: "%@ total", .de: "%@ gesamt", .ru: "всего: %@", .zh: "总计 %@"],
        Key.homeSession: [.en: "Session", .de: "Sitzung", .ru: "Сеанс", .zh: "会话"],
        Key.homeTunnelScope: [.en: "Tunnel scope", .de: "Tunnelumfang", .ru: "Область туннеля", .zh: "隧道范围"],
        Key.homePackages: [.en: "Packages", .de: "Pakete", .ru: "Пакеты", .zh: "应用包"],
        Key.homeAllApplications: [.en: "All applications", .de: "Alle Anwendungen", .ru: "Все приложения", .zh: "所有应用"],
        Key.homeIdentifiersFormat: [.en: "%d identifiers", .de: "%d Kennungen", .ru: "%d идентификаторов", .zh: "%d 个标识符"],
        Key.homeDnsLabel: [.en: "DNS", .de: "DNS", .ru: "DNS", .zh: "DNS"],
        Key.homeDnsVpnFormat: [.en: "VPN DNS (%d)", .de: "VPN-DNS (%d)", .ru: "VPN DNS (%d)", .zh: "VPN DNS (%d)"],
        Key.homeDnsCustomFormat: [
            .en: "Encrypted DNS %@ (%d)",
            .de: "Verschlüsseltes DNS %@ (%d)",
            .ru: "Зашифрованный DNS %@ (%d)",
            .zh: "加密 DNS %@ (%d)",
        ],
        Key.homeRoutingRules: [.en: "Rules", .de: "Regeln", .ru: "Правила", .zh: "规则"],
        Key.homeRegionalBypass: [.en: "Regional bypass", .de: "Regionale Umgehung", .ru: "Региональный обход", .zh: "区域绕行"],
        Key.homeSafetyPanel: [.en: "Safety", .de: "Sicherheit", .ru: "Безопасность", .zh: "安全"],
        Key.homeRuntimeIntegrity: [.en: "Runtime integrity", .de: "Laufzeitintegrität", .ru: "Целостность среды выполнения", .zh: "运行时完整性"],
        Key.homeIntegrityConnectedUI: [
            .en: "Connected UI state requires a live TUN interface from the privileged service.",
            .de: "Der verbundene UI-Zustand erfordert eine aktive TUN-Schnittstelle des privilegierten Dienstes.",
            .ru: "Состояние «Подключено» требует активного TUN-интерфейса от привилегированной службы.",
            .zh: "“已连接”界面状态要求特权服务提供活动的 TUN 接口。",
        ],
        Key.homeIntegrityLoopback: [
            .en: "Loopback traffic remains local by policy.",
            .de: "Loopback-Verkehr bleibt richtlinienbedingt lokal.",
            .ru: "Loopback-трафик по политике остаётся локальным.",
            .zh: "环回流量按策略保留在本地。",
        ],
        Key.homeIntegritySecrets: [
            .en: "Profile secrets are read from Keychain storage, not UserDefaults or logs.",
            .de: "Profilgeheimnisse werden aus dem Schlüsselbund gelesen, nicht aus UserDefaults oder Logs.",
            .ru: "Секреты профилей читаются из Keychain, а не из UserDefaults или логов.",
            .zh: "配置文件机密从 Keychain 读取，而非 UserDefaults 或日志。",
        ],
        Key.homeIntegrityHelper: [
            .en: "The Clash-Verge-style arm64 helper starts a pinned sing-box CLI and owns routes/DNS.",
            .de: "Der arm64-Helfer im Clash-Verge-Stil startet eine gepinnte sing-box-CLI und verwaltet Routen/DNS.",
            .ru: "Арм64-хелпер в стиле Clash Verge запускает закреплённый sing-box CLI и управляет маршрутами и DNS.",
            .zh: "Clash Verge 风格的 arm64 助手启动固定版本的 sing-box CLI 并管理路由/DNS。",
        ],
        Key.homeTunnelErrorTitle: [.en: "Tunnel error", .de: "Tunnelfehler", .ru: "Ошибка туннеля", .zh: "隧道错误"],
        Key.homeSplitTunnelFull: [.en: "Full tunnel", .de: "Volltunnel", .ru: "Полный туннель", .zh: "全隧道"],
        Key.homeSplitTunnelAllowlist: [.en: "Allowlist", .de: "Allowlist", .ru: "Белый список", .zh: "白名单"],
        Key.homeSplitTunnelDenylist: [.en: "Denylist", .de: "Denylist", .ru: "Чёрный список", .zh: "黑名单"],

        Key.profilesSelectOrImport: [
            .en: "Select or import a profile.",
            .de: "Wähle ein Profil aus oder importiere eines.",
            .ru: "Выберите профиль или импортируйте новый.",
            .zh: "选择或导入配置文件。",
        ],
        Key.profilesStagedImport: [.en: "Staged import", .de: "Import-Vorschau", .ru: "Подготовка импорта", .zh: "暂存导入"],
        Key.profilesValidateImport: [.en: "Validate Import", .de: "Import prüfen", .ru: "Проверить импорт", .zh: "验证导入"],
        Key.profilesImportNeverAutoConnects: [
            .en: "Import never auto-connects",
            .de: "Import verbindet nie automatisch",
            .ru: "Импорт никогда не подключается автоматически",
            .zh: "导入后永远不会自动连接",
        ],
        Key.profilesSaveToKeychain: [.en: "Save to Keychain", .de: "Im Schlüsselbund speichern", .ru: "Сохранить в Keychain", .zh: "保存到 Keychain"],
        Key.profilesDiscardPreview: [.en: "Discard Preview", .de: "Vorschau verwerfen", .ru: "Отменить предпросмотр", .zh: "放弃预览"],
        Key.profilesActive: [.en: "Active", .de: "Aktiv", .ru: "Активен", .zh: "当前"],
        Key.profilesActiveProfile: [.en: "Active profile", .de: "Aktives Profil", .ru: "Активный профиль", .zh: "当前配置文件"],
        Key.profilesRealityPublicKey: [.en: "REALITY public key", .de: "REALITY-Öffentlicher Schlüssel", .ru: "Открытый ключ REALITY", .zh: "REALITY 公钥"],
        Key.profilesRealityShortId: [.en: "REALITY short id", .de: "REALITY-Kurz-ID", .ru: "Короткий ID REALITY", .zh: "REALITY 短 ID"],
        Key.profilesDnsVpnServersFormat: [
            .en: "VPN DNS (%d servers)",
            .de: "VPN-DNS (%d Server)",
            .ru: "VPN DNS (%d серверов)",
            .zh: "VPN DNS (%d 个服务器)",
        ],
        Key.profilesDnsCustomFormat: [
            .en: "Custom %@, %d endpoints",
            .de: "Benutzerdefiniert: %@, %d Endpunkte",
            .ru: "Пользовательский %@, %d конечных точек",
            .zh: "自定义 %@，%d 个端点",
        ],

        Key.routingEmpty: [
            .en: "Select a profile to inspect and preview routing.",
            .de: "Wähle ein Profil aus, um das Routing zu prüfen und eine Vorschau zu erhalten.",
            .ru: "Выберите профиль, чтобы просматривать и проверять маршрутизацию.",
            .zh: "选择配置文件以查看和预览路由。",
        ],
        Key.routingRussiaToggle: [
            .en: "Route Russian domains (.ru, .su, .xn--p1ai) directly",
            .de: "Russische Domains (.ru, .su, .xn--p1ai) direkt routen",
            .ru: "Направлять российские домены (.ru, .su, .xn--p1ai) напрямую",
            .zh: "直接路由俄罗斯域名（.ru、.su、.xn--p1ai）",
        ],
        Key.routingGeoipHint: [
            .en: "GeoIP:RU is shown as a runtime hint until a regional dataset is bundled; the local configuration applies domain suffixes only.",
            .de: "GeoIP:RU wird bis zum Einbinden eines regionalen Datensatzes als Laufzeit-Hinweis angezeigt; die lokale Konfiguration wendet nur Domain-Suffixe an.",
            .ru: "GeoIP:RU показывается как подсказка времени выполнения, пока не подключён региональный набор данных; локальная конфигурация применяет только суффиксы доменов.",
            .zh: "在打包区域数据集之前，GeoIP:RU 仅显示为运行时提示；本地配置仅应用域名后缀。",
        ],
        Key.routingCustomDirectDomains: [.en: "Custom direct domains", .de: "Eigene Direkt-Domains", .ru: "Пользовательские прямые домены", .zh: "自定义直连域名"],
        Key.routingCustomDirectDomainsHint: [
            .en: "One domain per line. Unicode domains are normalized to IDN.",
            .de: "Eine Domain pro Zeile. Unicode-Domains werden zu IDN normalisiert.",
            .ru: "По одному домену в строке. Юникод-домены нормализуются в IDN.",
            .zh: "每行一个域名。Unicode 域名将规范化为 IDN。",
        ],
        Key.routingRoutePreview: [.en: "Route preview", .de: "Routing-Vorschau", .ru: "Предпросмотр маршрута", .zh: "路由预览"],
        Key.routingFieldAppBundleID: [.en: "App bundle ID", .de: "App-Bundle-ID", .ru: "ID пакета приложения", .zh: "应用 Bundle ID"],
        Key.routingFieldDestinationHost: [.en: "Destination host", .de: "Ziel-Host", .ru: "Хост назначения", .zh: "目标主机"],
        Key.routingFieldDestinationIp: [.en: "Destination IP", .de: "Ziel-IP", .ru: "IP назначения", .zh: "目标 IP"],
        Key.routingEvaluate: [.en: "Evaluate", .de: "Auswerten", .ru: "Оценить", .zh: "评估"],
        Key.routingOfflineHint: [
            .en: "Evaluation is offline; GeoSite/GeoIP/ASN-only matches are reported as runtime hints rather than silently claimed.",
            .de: "Die Auswertung ist offline; Treffer nur über GeoSite/GeoIP/ASN werden als Laufzeit-Hinweise gemeldet, statt sie stillschweigend zu übernehmen.",
            .ru: "Оценка выполняется автономно; совпадения только по GeoSite/GeoIP/ASN сообщаются как подсказки времени выполнения, а не применяются молча.",
            .zh: "评估为离线模式；仅通过 GeoSite/GeoIP/ASN 的匹配会报告为运行时提示，而不会静默采用。",
        ],
        Key.routingResolvedPolicy: [.en: "Resolved policy", .de: "Aufgelöste Regeln", .ru: "Итоговая политика", .zh: "解析后的策略"],
        Key.routingBlockRulesFirst: [.en: "Block rules first", .de: "Blockregeln zuerst", .ru: "Блокирующие правила первыми", .zh: "拦截规则优先"],
        Key.routingGeneratedRegionalRules: [.en: "Generated regional rules", .de: "Generierte Regionsregeln", .ru: "Сгенерированные региональные правила", .zh: "生成的区域规则"],
        Key.routingNonBlockRules: [.en: "Non-block rules", .de: "Nicht blockierende Regeln", .ru: "Неблокирующие правила", .zh: "非拦截规则"],
        Key.routingInvalidPolicy: [
            .en: "The routing policy contains an invalid regional bypass domain.",
            .de: "Die Routing-Richtlinie enthält eine ungültige Regions-Umgehungsdomain.",
            .ru: "Политика маршрутизации содержит недопустимый домен регионального обхода.",
            .zh: "路由策略包含无效的区域绕行域名。",
        ],
        Key.routingCriteriaExact: [.en: "exact", .de: "exakt", .ru: "точно", .zh: "精确"],
        Key.routingCriteriaSuffix: [.en: "suffix", .de: "Suffix", .ru: "суффикс", .zh: "后缀"],
        Key.routingCriteriaKeyword: [.en: "keyword", .de: "Schlüsselwort", .ru: "ключевое слово", .zh: "关键词"],
        Key.routingCriteriaCidr: [.en: "CIDR", .de: "CIDR", .ru: "CIDR", .zh: "CIDR"],
        Key.routingCriteriaGeosite: [.en: "GeoSite", .de: "GeoSite", .ru: "GeoSite", .zh: "GeoSite"],
        Key.routingCriteriaGeoip: [.en: "GeoIP", .de: "GeoIP", .ru: "GeoIP", .zh: "GeoIP"],
        Key.routingCriteriaAsn: [.en: "ASN", .de: "ASN", .ru: "ASN", .zh: "ASN"],
        Key.routingCriteriaApp: [.en: "app", .de: "App", .ru: "приложение", .zh: "应用"],
        Key.routingNoCriteria: [.en: "No criteria", .de: "Keine Kriterien", .ru: "Нет критериев", .zh: "无条件匹配"],

        Key.securityLocalStorage: [.en: "Local storage", .de: "Lokaler Speicher", .ru: "Локальное хранилище", .zh: "本地存储"],
        Key.securityProfileCount: [.en: "Profile count", .de: "Anzahl der Profile", .ru: "Количество профилей", .zh: "配置文件数量"],
        Key.securityStorageLabel: [.en: "Storage", .de: "Speicher", .ru: "Хранилище", .zh: "存储"],
        Key.securityStorageValue: [
            .en: "macOS Keychain, this-device accessible",
            .de: "macOS-Schlüsselbund, nur dieses Gerät",
            .ru: "Keychain macOS, доступ только с этого устройства",
            .zh: "macOS Keychain，仅限本设备",
        ],
        Key.securityAutoConnectAfterImport: [
            .en: "Auto-connect after import",
            .de: "Nach dem Import automatisch verbinden",
            .ru: "Автоподключение после импорта",
            .zh: "导入后自动连接",
        ],
        Key.securityEncryptedBackup: [.en: "Encrypted backup", .de: "Verschlüsseltes Backup", .ru: "Зашифрованная резервная копия", .zh: "加密备份"],
        Key.securityBackupDescription: [
            .en: "Exports every profile into one authenticated AES-256-GCM container. The passphrase derives the key with PBKDF2-HMAC-SHA256 and is never stored.",
            .de: "Exportiert jedes Profil in einen authentifizierten AES-256-GCM-Container. Die Passphrase leitet den Schlüssel per PBKDF2-HMAC-SHA256 ab und wird nie gespeichert.",
            .ru: "Экспортирует каждый профиль в один контейнер AES-256-GCM с аутентификацией. Парольная фраза выводит ключ через PBKDF2-HMAC-SHA256 и никогда не сохраняется.",
            .zh: "将所有配置文件导出到一个经验证的 AES-256-GCM 容器。密码短语通过 PBKDF2-HMAC-SHA256 派生密钥，且永远不会被存储。",
        ],
        Key.securityBackupPassphrase: [
            .en: "Backup passphrase (12 characters or more)",
            .de: "Backup-Passphrase (mindestens 12 Zeichen)",
            .ru: "Парольная фраза резервной копии (не менее 12 символов)",
            .zh: "备份密码短语（至少 12 个字符）",
        ],
        Key.securityExportBackup: [.en: "Export backup", .de: "Backup exportieren", .ru: "Экспортировать копию", .zh: "导出备份"],
        Key.securityRestoreBackup: [.en: "Restore backup", .de: "Backup wiederherstellen", .ru: "Восстановить копию", .zh: "恢复备份"],
        Key.securityBackupWrittenFormat: [
            .en: "Encrypted backup written to %@.",
            .de: "Verschlüsseltes Backup in %@ geschrieben.",
            .ru: "Зашифрованная копия записана в %@.",
            .zh: "加密备份已写入 %@。",
        ],
        Key.securityRestoredOneFormat: [
            .en: "Restored 1 profile from %@.",
            .de: "1 Profil aus %@ wiederhergestellt.",
            .ru: "Восстановлен 1 профиль из %@.",
            .zh: "已从 %@ 恢复 1 个配置文件。",
        ],
        Key.securityRestoredManyFormat: [
            .en: "Restored %d profiles from %@.",
            .de: "%d Profile aus %@ wiederhergestellt.",
            .ru: "Восстановлено %d профилей из %@.",
            .zh: "已恢复 %d 个配置文件，来自 %@。",
        ],
        Key.securityRedactedDiagnostics: [.en: "Redacted diagnostics", .de: "Anonymisierte Diagnose", .ru: "Обезличенная диагностика", .zh: "脱敏诊断"],
        Key.securityDiagnosticsDescription: [
            .en: "Builds a support report without profile IDs, names, endpoints, UUIDs, REALITY keys, DNS addresses, rule domains, or share links.",
            .de: "Erstellt einen Support-Bericht ohne Profil-IDs, Namen, Endpunkte, UUIDs, REALITY-Schlüssel, DNS-Adressen, Regel-Domains oder Freigabelinks.",
            .ru: "Создаёт отчёт для поддержки без ID профилей, имён, конечных точек, UUID, ключей REALITY, DNS-адресов, доменов правил и ссылок общего доступа.",
            .zh: "生成支持报告，不包含配置文件 ID、名称、端点、UUID、REALITY 密钥、DNS 地址、规则域名或分享链接。",
        ],
        Key.securityGenerateReport: [.en: "Generate report", .de: "Bericht erstellen", .ru: "Создать отчёт", .zh: "生成报告"],
        Key.securitySafetyPosture: [.en: "Safety posture", .de: "Sicherheitsstatus", .ru: "Состояние безопасности", .zh: "安全态势"],
        Key.securitySafeModeDetail: [
            .en: "Unsafe imported profiles are rejected.",
            .de: "Unsichere importierte Profile werden abgelehnt.",
            .ru: "Небезопасные импортированные профили отклоняются.",
            .zh: "不安全的导入配置文件将被拒绝。",
        ],
        Key.securityKeptDisabled: [
            .en: "Kept disabled for the local build.",
            .de: "Für den lokalen Build deaktiviert.",
            .ru: "Отключено в локальной сборке.",
            .zh: "在本地构建中保持禁用。",
        ],
        Key.securityFailClosed: [
            .en: "Fail-closed tunnel policy",
            .de: "Fail-Closed-Tunnelrichtlinie",
            .ru: "Политика туннеля «закрыто при сбое»",
            .zh: "故障关闭式隧道策略",
        ],
        Key.securityFailClosedDetail: [
            .en: "An invalid runtime configuration must not connect.",
            .de: "Eine ungültige Laufzeitkonfiguration darf keine Verbindung aufbauen.",
            .ru: "Недопустимая конфигурация не должна устанавливать соединение.",
            .zh: "无效的运行时配置不得建立连接。",
        ],
        Key.securityConnectionInvariants: [.en: "Connection invariants", .de: "Verbindungs-Invarianten", .ru: "Инварианты подключения", .zh: "连接不变量"],
        Key.securityInvariantConnected: [
            .en: "Only a live TUN interface from the privileged helper can produce the Connected state.",
            .de: "Nur eine aktive TUN-Schnittstelle des privilegierten Helfers kann den Zustand „Verbunden“ erzeugen.",
            .ru: "Только активный TUN-интерфейс от привилегированного хелпера может дать состояние «Подключено».",
            .zh: "只有来自特权助手的活动 TUN 接口才能产生“已连接”状态。",
        ],
        Key.securityInvariantDesired: [
            .en: "Desired state is separate from observed runtime state.",
            .de: "Gewünschter Zustand und beobachteter Laufzeitstatus sind getrennt.",
            .ru: "Желаемое состояние отделено от наблюдаемого состояния выполнения.",
            .zh: "期望状态与观察到的运行状态相互独立。",
        ],
        Key.securityInvariantSecrets: [
            .en: "Secrets are masked in the UI and are not written to logs.",
            .de: "Geheimnisse werden in der UI maskiert und nicht in Logs geschrieben.",
            .ru: "Секреты маскируются в интерфейсе и не записываются в логи.",
            .zh: "机密在界面中会被掩码处理，且不会写入日志。",
        ],
        Key.securityInvariantLoopback: [
            .en: "Loopback destinations remain direct by routing policy.",
            .de: "Loopback-Ziele bleiben richtlinienbedingt direkt.",
            .ru: "Назначения loopback остаются прямыми согласно политике маршрутизации.",
            .zh: "环回目标按路由策略保持直连。",
        ],
        Key.securityRuntimePackaging: [.en: "Runtime packaging", .de: "Laufzeit-Paketierung", .ru: "Упаковка среды выполнения", .zh: "运行时打包"],
        Key.securityAppTarget: [.en: "App target", .de: "App-Ziel", .ru: "Цель приложения", .zh: "应用目标"],
        Key.securityAppTargetValue: [.en: "SwiftUI instrument panel", .de: "SwiftUI-Instrumentenpanel", .ru: "Панель инструментов SwiftUI", .zh: "SwiftUI 仪表面板"],
        Key.securityTunnelTarget: [.en: "Tunnel target", .de: "Tunnel-Ziel", .ru: "Цель туннеля", .zh: "隧道目标"],
        Key.securityTunnelTargetValue: [
            .en: "Privileged helper + sing-box CLI",
            .de: "privilegierter Helfer + sing-box-CLI",
            .ru: "привилегированный хелпер + sing-box CLI",
            .zh: "特权助手 + sing-box CLI",
        ],
        Key.securityEngine: [.en: "Engine", .de: "Engine", .ru: "Движок", .zh: "引擎"],
        Key.securityEngineValue: [
            .en: "Pinned sing-box CLI, arm64",
            .de: "Gepinnte sing-box-CLI, arm64",
            .ru: "Закреплённый sing-box CLI, arm64",
            .zh: "固定版本的 sing-box CLI，arm64",
        ],
        Key.securityHelperInstallNote: [
            .en: "The helper installs a LaunchDaemon under /Library/Tunguska and requires an administrator password once during setup.",
            .de: "Der Helfer installiert einen LaunchDaemon unter /Library/Tunguska und benötigt während der Einrichtung einmal ein Administratorpasswort.",
            .ru: "Хелпер устанавливает LaunchDaemon в /Library/Tunguska и один раз запрашивает пароль администратора при настройке.",
            .zh: "助手会在 /Library/Tunguska 下安装 LaunchDaemon，并在设置过程中要求输入一次管理员密码。",
        ],
        Key.securityGatekeeperNote: [
            .en: "This Clash-Verge-style path avoids the NetworkExtension entitlement. Gatekeeper may warn for unsigned local builds; do not run an unsigned privileged helper from untrusted sources.",
            .de: "Dieser Weg im Clash-Verge-Stil vermeidet die NetworkExtension-Berechtigung. Gatekeeper kann bei unsignierten lokalen Builds warnen; führe keinen unsignierten privilegierten Helfer aus unbekannten Quellen aus.",
            .ru: "Этот путь в стиле Clash Verge обходит entitlement NetworkExtension. Gatekeeper может предупреждать о неподписанных локальных сборках; не запускайте неподписанный привилегированный хелпер из ненадёжных источников.",
            .zh: "这条 Clash Verge 风格的路径避开了 NetworkExtension 权限。Gatekeeper 可能对未签名的本地构建发出警告；请勿运行来自不受信任来源的未签名特权助手。",
        ],
        Key.securityPass: [.en: "Pass", .de: "Bestanden", .ru: "Пройдено", .zh: "通过"],
        Key.securityRestricted: [.en: "Restricted", .de: "Eingeschränkt", .ru: "Ограничено", .zh: "受限"],

        Key.menubarSystemProxyFormat: [
            .en: "System proxy · %@:%d",
            .de: "Systemproxy · %@:%d",
            .ru: "Системный прокси · %@:%d",
            .zh: "系统代理 · %@:%d",
        ],
        Key.menubarTunMode: [.en: "TUN mode", .de: "TUN-Modus", .ru: "Режим TUN", .zh: "TUN 模式"],
        Key.menubarOpenApp: [.en: "Open Tunguska", .de: "Tunguska öffnen", .ru: "Открыть Tunguska", .zh: "打开 Tunguska"],
        Key.menubarQuitApp: [.en: "Quit Tunguska", .de: "Tunguska beenden", .ru: "Выйти из Tunguska", .zh: "退出 Tunguska"],

        Key.stateDisconnected: [.en: "Disconnected", .de: "Getrennt", .ru: "Отключено", .zh: "已断开"],
        Key.stateConnecting: [.en: "Connecting", .de: "Verbinde", .ru: "Подключение", .zh: "连接中"],
        Key.stateConnected: [.en: "Connected", .de: "Verbunden", .ru: "Подключено", .zh: "已连接"],
        Key.stateDisconnecting: [.en: "Disconnecting", .de: "Trennen", .ru: "Отключение", .zh: "断开中"],
        Key.stateFailed: [.en: "Failed", .de: "Fehlgeschlagen", .ru: "Ошибка", .zh: "连接失败"],
        Key.stateUnavailable: [.en: "Unavailable", .de: "Nicht verfügbar", .ru: "Недоступно", .zh: "不可用"],
        Key.stateDisconnectedDetail: [
            .en: "No privileged session is active.",
            .de: "Keine privilegierte Sitzung aktiv.",
            .ru: "Привилегированная сессия не активна.",
            .zh: "没有活动的特权会话。",
        ],
        Key.stateConnectingDetail: [
            .en: "The sing-box service is starting; the UI stays non-connected until the session is live.",
            .de: "Der sing-box-Dienst startet; die UI bleibt bis zum Livegang der Sitzung getrennt.",
            .ru: "Служба sing-box запускается; интерфейс остаётся неподключённым, пока сессия не станет активной.",
            .zh: "sing-box 服务正在启动；会话生效之前界面保持未连接状态。",
        ],
        Key.stateConnectedDetail: [
            .en: "The privileged sing-box service reported a live session.",
            .de: "Der privilegierte sing-box-Dienst hat eine aktive Sitzung gemeldet.",
            .ru: "Привилегированная служба sing-box сообщила об активной сессии.",
            .zh: "特权 sing-box 服务已报告会话生效。",
        ],
        Key.stateDisconnectingDetail: [
            .en: "The privileged service is stopping the tunnel.",
            .de: "Der privilegierte Dienst stoppt den Tunnel.",
            .ru: "Привилегированная служба останавливает туннель.",
            .zh: "特权服务正在停止隧道。",
        ],

        Key.errorInvalidProfileFormat: [
            .en: "The selected profile cannot be used by the tunnel: %@",
            .de: "Das ausgewählte Profil kann vom Tunnel nicht verwendet werden: %@",
            .ru: "Выбранный профиль не может использоваться туннелем: %@",
            .zh: "所选配置文件无法被隧道使用：%@",
        ],
        Key.errorVpnMustBeStopped: [
            .en: "Stop the VPN before restoring a profile backup.",
            .de: "Beende das VPN, bevor du ein Profil-Backup wiederherstellst.",
            .ru: "Остановите VPN перед восстановлением резервной копии профиля.",
            .zh: "恢复配置文件备份前请先停止 VPN。",
        ],
        Key.errorDeleteWhileConnected: [
            .en: "Disconnect the active VPN session before deleting a profile.",
            .de: "Trenne die aktive VPN-Sitzung, bevor du ein Profil löschst.",
            .ru: "Отключите активную VPN-сессию перед удалением профиля.",
            .zh: "删除配置文件前请先断开活动的 VPN 会话。",
        ],
        Key.errorSelectProfileFirst: [
            .en: "Select a profile before evaluating a route.",
            .de: "Wähle ein Profil aus, bevor du eine Route auswertest.",
            .ru: "Выберите профиль перед оценкой маршрута.",
            .zh: "评估路由前请先选择配置文件。",
        ],
        Key.errorInvalidDestinationPort: [
            .en: "Destination port must be empty or an integer between 1 and 65535.",
            .de: "Der Zielport muss leer oder eine Ganzzahl zwischen 1 und 65535 sein.",
            .ru: "Порт назначения должен быть пустым или целым числом от 1 до 65535.",
            .zh: "目标端口必须为空或 1 到 65535 之间的整数。",
        ],
        Key.errorNoProfileToConnect: [
            .en: "Import and select a profile before starting the VPN.",
            .de: "Importiere und wähle ein Profil aus, bevor du das VPN startest.",
            .ru: "Импортируйте и выберите профиль перед запуском VPN.",
            .zh: "启动 VPN 前请先导入并选择配置文件。",
        ],
        Key.errorLoginItemEnableFormat: [
            .en: "Launch at login could not be enabled: %@",
            .de: "Anmeldung beim Start konnte nicht aktiviert werden: %@",
            .ru: "Не удалось включить запуск при входе: %@",
            .zh: "无法启用登录时启动：%@",
        ],
        Key.errorLoginItemDisableFormat: [
            .en: "Launch at login could not be disabled: %@",
            .de: "Anmeldung beim Start konnte nicht deaktiviert werden: %@",
            .ru: "Не удалось отключить запуск при входе: %@",
            .zh: "无法禁用登录时启动：%@",
        ],
        Key.errorServiceNotChecked: [
            .en: "The privileged tunnel service has not been checked yet.",
            .de: "Der privilegierte Tunneldienst wurde noch nicht geprüft.",
            .ru: "Привилегированная служба туннеля ещё не проверена.",
            .zh: "尚未检查特权隧道服务。",
        ],
        Key.errorHelperStartFailed: [
            .en: "The privileged tunnel service could not start sing-box.",
            .de: "Der privilegierte Dienst konnte sing-box nicht starten.",
            .ru: "Привилегированная служба не смогла запустить sing-box.",
            .zh: "特权服务无法启动 sing-box。",
        ],
        Key.errorNoLiveSession: [
            .en: "sing-box did not report a live session.",
            .de: "sing-box hat keine aktive Sitzung gemeldet.",
            .ru: "sing-box не сообщил об активной сессии.",
            .zh: "sing-box 未报告活动会话。",
        ],
        Key.errorNoTunInterface: [
            .en: "sing-box did not report a live TUN interface.",
            .de: "sing-box hat keine aktive TUN-Schnittstelle gemeldet.",
            .ru: "sing-box не сообщил об активном TUN-интерфейсе.",
            .zh: "sing-box 未报告活动 TUN 接口。",
        ],
        Key.errorHelperStopFailed: [
            .en: "The privileged tunnel service could not stop sing-box.",
            .de: "Der privilegierte Dienst konnte sing-box nicht stoppen.",
            .ru: "Привилегированная служба не смогла остановить sing-box.",
            .zh: "特权服务无法停止 sing-box。",
        ],
        Key.errorIncompleteResponse: [
            .en: "The helper response was incomplete.",
            .de: "Die Antwort des Helfers war unvollständig.",
            .ru: "Ответ хелпера был неполным.",
            .zh: "助手响应不完整。",
        ],
        Key.errorNoTunReported: [
            .en: "The helper reported a running engine without a TUN interface.",
            .de: "Der Helfer meldete eine laufende Engine ohne TUN-Schnittstelle.",
            .ru: "Хелпер сообщил о работающем движке без TUN-интерфейса.",
            .zh: "助手报告了运行中的引擎，但没有 TUN 接口。",
        ],
        Key.errorServiceFailure: [
            .en: "The tunnel service reported a failure.",
            .de: "Der Tunneldienst meldete einen Fehler.",
            .ru: "Служба туннеля сообщила об ошибке.",
            .zh: "隧道服务报告了错误。",
        ],
    ]

    /// Resolves a key in the active language (`AppSettings.shared.appLanguage`).
    @MainActor
    static func t(_ key: String) -> String {
        t(key, language: AppSettings.shared.appLanguage)
    }

    /// Resolves a key in an explicit language. Falls back to English when the
    /// key or the language entry is missing; in debug builds a gap in the
    /// shared table triggers an assertion so missing translations surface
    /// during development instead of silently rendering English.
    static func t(_ key: String, language: AppLanguage) -> String {
        let value = translated(key, language: language, table: table)
        #if DEBUG
        if table[key] == nil {
            assertionFailure("Unknown L10n key: \(key)")
        } else if language != .en, table[key]?[language] == nil {
            assertionFailure("Missing \(language) translation for L10n key '\(key)'; fell back to English.")
        }
        #endif
        return value
    }

    /// Formatting variant for templates containing `%@` / `%d` placeholders,
    /// resolved in the active language.
    @MainActor
    static func fmt(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    /// Formatting variant resolved in an explicit language.
    static func fmt(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: t(key, language: language), arguments: arguments)
    }

    /// Pure lookup over an explicit table. This is the rendering primitive:
    /// it never asserts, so tests can exercise fallback behavior with fixture
    /// tables that contain deliberate gaps.
    static func translated(_ key: String, language: AppLanguage, table: [String: [AppLanguage: String]]) -> String {
        table[key]?[language] ?? table[key]?[.en] ?? key
    }
}

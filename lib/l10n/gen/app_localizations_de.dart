// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonPlay => 'Abspielen';

  @override
  String get commonOn => 'An';

  @override
  String get commonOff => 'Aus';

  @override
  String get navChannels => 'Sender';

  @override
  String get navFavorites => 'Favoriten';

  @override
  String get navMyLists => 'Meine Listen';

  @override
  String get navSearch => 'Suchen';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get linkChannelUnavailable => 'Dieser Sender ist nicht mehr verfügbar';

  @override
  String get channelUnavailable => 'Dieser Sender ist nicht mehr verfügbar';

  @override
  String get bootstrapPreparing => 'Sender werden vorbereitet…';

  @override
  String get bootstrapFailed => 'Die Senderliste konnte nicht geladen werden';

  @override
  String get agoMoment => 'gerade eben';

  @override
  String agoMinutes(int n) {
    return 'vor $n Min.';
  }

  @override
  String agoHours(int n) {
    return 'vor $n Std.';
  }

  @override
  String agoDays(int n) {
    return 'vor $n T.';
  }

  @override
  String get browserAllChannels => 'Alle Sender';

  @override
  String get browserRecents => 'Zuletzt gesehen';

  @override
  String get browserFooterHint =>
      'OK Abspielen  ·  OK halten Optionen  ·  ← Menü';

  @override
  String get browserEmptyFavorites =>
      'Du hast noch keine Favoriten. Halte OK auf einem Sender gedrückt, um ihn hinzuzufügen.';

  @override
  String get browserEmptyGroup => 'In dieser Gruppe gibt es keine Sender';

  @override
  String get favoriteAdded => 'Zu Favoriten hinzugefügt';

  @override
  String get favoriteRemoved => 'Aus Favoriten entfernt';

  @override
  String get deadMarkRemoved => 'Markierung entfernt';

  @override
  String get deadMarked => 'Als ausgefallen markiert';

  @override
  String get menuFavoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get menuFavoriteRemove => 'Aus Favoriten entfernen';

  @override
  String get menuAddToList => 'Zu einer Liste hinzufügen…';

  @override
  String get menuShowGuide => 'Programm anzeigen';

  @override
  String get menuDeadClear => 'Ausfall-Markierung entfernen';

  @override
  String get menuDeadMark => 'Als ausgefallen markieren';

  @override
  String get searchUpdateListsForCountries =>
      'Aktualisiere die Listen, um die Länder zu sehen';

  @override
  String get searchCountryTitle => 'Land';

  @override
  String get searchAllCountries => 'Alle Länder';

  @override
  String get searchCountryAllShort => 'Alle';

  @override
  String searchCountryChip(String value) {
    return 'Land: $value';
  }

  @override
  String get searchLabel => 'Sender suchen';

  @override
  String get searchHint => 'OK drücken zum Eingeben';

  @override
  String searchStatusIdle(int min) {
    return 'Gib mindestens $min Buchstaben ein oder wähle ein Land';
  }

  @override
  String get searchStatusSearching => 'Suche läuft…';

  @override
  String searchStatusResults(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Ergebnisse',
      one: '1 Ergebnis',
    );
    return '$_temp0';
  }

  @override
  String get searchStatusNoCountryChannels => 'Keine Sender aus diesem Land';

  @override
  String searchStatusNoResults(String query) {
    return 'Keine Ergebnisse für „$query“';
  }

  @override
  String get searchStatusError => 'Fehler bei der Suche. Versuche es erneut.';

  @override
  String get playlistNew => 'Neue Liste';

  @override
  String get playlistCreate => 'Erstellen';

  @override
  String get playlistCreateFailed => 'Die Liste konnte nicht erstellt werden';

  @override
  String playlistAddedTo(String name) {
    return 'Zu „$name“ hinzugefügt';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Bereits in „$name“';
  }

  @override
  String get playlistRename => 'Umbenennen';

  @override
  String get playlistRenameFailed => 'Umbenennen nicht möglich';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Liste „$name“ löschen?';
  }

  @override
  String get playlistAddChannelByUrl => 'Sender per URL hinzufügen';

  @override
  String get playlistChannelNameLabel => 'Name des Senders';

  @override
  String get playlistStreamUrlLabel => 'Stream-URL';

  @override
  String get playlistAddChannelFailed =>
      'Der Sender konnte nicht hinzugefügt werden';

  @override
  String get playlistMoveUp => 'Weiter nach vorn';

  @override
  String get playlistMoveDown => 'Weiter nach hinten';

  @override
  String get playlistRemoveFromList => 'Aus der Liste entfernen';

  @override
  String get playlistDeleteChannel => 'Sender löschen';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Sender',
      one: '1 Sender',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst =>
      'Erstelle deine erste Liste mit „Neue Liste“.';

  @override
  String get playlistEmptyList =>
      'Diese Liste ist leer. Halte OK auf einem Sender gedrückt und wähle „Zu einer Liste hinzufügen…“.';

  @override
  String get keyboardDone => 'Fertig';

  @override
  String get keyboardSearch => 'Suchen';

  @override
  String get keyboardShift => 'Umschalt';

  @override
  String get keyboardSpace => 'Leertaste';

  @override
  String get keyboardBackspace => '⌫ Löschen';

  @override
  String get keyboardClear => 'Leeren';

  @override
  String get keyboardSystem => 'Sprache / System';

  @override
  String get guideToday => 'Heute';

  @override
  String get guideTomorrow => 'Morgen';

  @override
  String get guideWeekdaysShort => 'Mo|Di|Mi|Do|Fr|Sa|So';

  @override
  String get guidePrevious => 'Zurück';

  @override
  String get guideNext => 'Weiter';

  @override
  String get guideNowBadge => 'JETZT';

  @override
  String get guideLoadFailed =>
      'Der Programmführer konnte nicht geladen werden';

  @override
  String get guideEmptyDay => 'Kein Programm für diesen Tag';

  @override
  String get playerSetCameraFirst =>
      'Richte die Kamera zuerst in den Einstellungen ein';

  @override
  String get playerMenuAudio => 'Audio';

  @override
  String get playerMenuSubtitles => 'Untertitel';

  @override
  String get playerMenuLast => 'Zurück zum vorherigen Sender';

  @override
  String get playerMenuFit => 'Bild anpassen';

  @override
  String get playerMenuToMpv =>
      'mpv für diesen Sender verwenden (Audio und Untertitel)';

  @override
  String get playerMenuToExo => 'ExoPlayer für diesen Sender verwenden';

  @override
  String get playerCamShow => 'Kamera anzeigen';

  @override
  String get playerCamHide => 'Kamera ausblenden';

  @override
  String get playerCamInBox => 'Kamera im Fenster (Sender groß)';

  @override
  String get playerCamFull => 'Kamera im Vollbild';

  @override
  String get playerCamZoom => 'Kamera-Zoom';

  @override
  String get playerCamRetry => 'Kamera erneut versuchen';

  @override
  String get playerLoading => 'Lädt…';

  @override
  String get playerPaused => 'Pausiert';

  @override
  String get playerLive => 'Live';

  @override
  String get playerKeyHintLive =>
      '↑↓ Sender wechseln  ·  OK Info  ·  OK halten Optionen  ·  Zurück Beenden';

  @override
  String get playerKeyHintVod =>
      '←→ 10 Sek.  ·  OK Pause  ·  OK halten Optionen  ·  Zurück Beenden';

  @override
  String get playerCamNoSignal => 'Kamera ohne Signal';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Bewegen  ·  OK Zoom ändern  ·  Zurück Fertig';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Sender $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Jetzt: $title';
  }

  @override
  String get playerErrorTitle => 'Dieser Sender kann nicht abgespielt werden';

  @override
  String get playerNextChannel => 'Nächster Sender';

  @override
  String get playerBack => 'Zurück';

  @override
  String get settingsAddFromIptvOrg => 'Aus iptv-org hinzufügen';

  @override
  String get settingsAddM3u => 'M3U-Liste per URL hinzufügen';

  @override
  String get settingsRefreshNow => 'Listen jetzt aktualisieren';

  @override
  String get settingsAutoRefresh =>
      'Automatische Aktualisierung (alle 24 Std.)';

  @override
  String get settingsAutoOn => 'An';

  @override
  String get settingsAutoOff => 'Aus';

  @override
  String get settingsBuffer => 'Wiedergabepuffer';

  @override
  String get settingsBufferHint =>
      'Mehr Sekunden = weniger Ruckeln; startet etwas später';

  @override
  String get settingsEngine => 'Video-Engine';

  @override
  String get settingsEngineAutoHint =>
      'ExoPlayer und, falls das scheitert, mpv';

  @override
  String get settingsEngineMpvHint => 'Nur mpv (am kompatibelsten)';

  @override
  String get engineModeAuto => 'Automatisch';

  @override
  String get engineModeMpv => 'Nur mpv';

  @override
  String get settingsDecoding => 'Videodecodierung (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'Wenn ein 1080p-Sender mit mpv ruckelt, probiere „Ohne Kopie“';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Experimentell: ohne Bildkopie; gibt es kein Bild, wird wieder auf Automatik gewechselt';

  @override
  String get settingsDecodingZeroCopy => 'Ohne Kopie';

  @override
  String get settingsDecodingAuto => 'Automatisch';

  @override
  String get settingsTextSize => 'Schriftgröße';

  @override
  String get settingsTextSizeHint =>
      'Vergrößert die Texte der gesamten Oberfläche';

  @override
  String get settingsHighContrast => 'Hoher Kontrast';

  @override
  String get settingsHighContrastHint =>
      'Hellerer Text und dickerer gelber Fokusrahmen';

  @override
  String get settingsHideDead => 'Ausgefallene Sender ausblenden';

  @override
  String get settingsHideDeadHint =>
      'In Sender und Suche (Favoriten zeigt sie immer an)';

  @override
  String get settingsDeadChannels => 'Ausgefallene Sender';

  @override
  String get settingsDeadChannelsHint =>
      'Sie werden beim Umschalten übersprungen. OK, um die Markierungen zu löschen';

  @override
  String get settingsDeadNone => 'Keine';

  @override
  String settingsDeadCount(int n) {
    return '$n markiert';
  }

  @override
  String get settingsHideAdult => 'Inhalte für Erwachsene ausblenden';

  @override
  String get settingsHideAdultHintPin => 'Zum Deaktivieren ist die PIN nötig';

  @override
  String get settingsHideAdultHintNoPin =>
      'Lege eine PIN an, um es zu schützen';

  @override
  String get settingsPin => 'PIN für die Kindersicherung';

  @override
  String get settingsPinHint => '4 Ziffern; schützt den Jugendschutzfilter';

  @override
  String get settingsPinSet => 'Festgelegt';

  @override
  String get settingsPinNone => 'Keine PIN';

  @override
  String get settingsBackup => 'Sicherung';

  @override
  String get settingsBackupHint =>
      'Exportiere oder importiere Favoriten, eigene Listen und Einstellungen';

  @override
  String get settingsEpg => 'Eigener Programmführer (XMLTV)';

  @override
  String get settingsEpgHint =>
      'Mehr Sender mit Programm; ergänzt die Programme deiner Länder';

  @override
  String get settingsEpgSet => 'Festgelegt';

  @override
  String get settingsEpgUnset => 'Nicht festgelegt';

  @override
  String get settingsCamera => 'Überwachungskamera';

  @override
  String get settingsCameraHint =>
      'Wird als Sender und in einem Fenster angezeigt (OK auf einem Sender halten)';

  @override
  String get settingsCameraSet => 'Eingerichtet';

  @override
  String get settingsCameraUnset => 'Keine Kamera';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageHint => 'Sprache der TV-Oberfläche';

  @override
  String get settingsLanguageAuto => 'Automatisch (System)';

  @override
  String get settingsMySources => 'Meine Quellen';

  @override
  String get settingsAlreadyRefreshing =>
      'Die Listen werden bereits aktualisiert';

  @override
  String get settingsRefreshing => 'Listen werden aktualisiert…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Listen konnten nicht aktualisiert werden',
      one: '1 Liste konnte nicht aktualisiert werden',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Listen aktualisiert';

  @override
  String get settingsRefreshFailed =>
      'Die Listen konnten nicht aktualisiert werden';

  @override
  String get pinWrong => 'Falsche PIN';

  @override
  String get pinNew => 'Neue PIN';

  @override
  String get pinRepeat => 'PIN wiederholen';

  @override
  String get pinMismatch => 'Die PINs stimmen nicht überein';

  @override
  String get pinEnter => 'PIN eingeben';

  @override
  String get pinEnterCurrent => 'Aktuelle PIN eingeben';

  @override
  String get pinSaved => 'PIN gespeichert';

  @override
  String get pinRemoved => 'PIN entfernt';

  @override
  String get pinChange => 'PIN ändern';

  @override
  String get pinRemove => 'PIN entfernen';

  @override
  String get backupExport => 'Sicherung exportieren';

  @override
  String get backupImportMenu => 'Sicherung importieren…';

  @override
  String backupSavedTo(String path) {
    return 'Sicherung gespeichert unter $path';
  }

  @override
  String get backupSaveFailed =>
      'Die Sicherung konnte nicht gespeichert werden';

  @override
  String get backupImportTitle => 'Sicherung importieren';

  @override
  String get backupFromUrl => 'Von einer URL…';

  @override
  String get backupFromPicker => 'Aus einer Datei auf dem Gerät…';

  @override
  String get backupImportFromUrlTitle => 'Von einer URL importieren';

  @override
  String get backupUrlLabel => 'Adresse der Sicherung (.json)';

  @override
  String get backupImportConfirm => 'Importieren';

  @override
  String get backupNoFile => 'Es wurde keine Datei ausgewählt';

  @override
  String get backupImporting => 'Import läuft…';

  @override
  String backupImported(String summary) {
    return 'Sicherung importiert: $summary';
  }

  @override
  String get backupImportFailed =>
      'Die Sicherung konnte nicht importiert werden';

  @override
  String backupSummaryLists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Listen',
      one: '1 Liste',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryFavorites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Favoriten',
      one: '1 Favorit',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n neue eigene Listen',
      one: '1 neue eigene Liste',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Sender in Listen',
      one: '1 Sender in Listen',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n eigene Sender',
      one: '1 eigener Sender',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Einstellungen',
      one: '1 Einstellung',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Nichts Neues zu importieren';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Favoriten ohne Sender',
      one: '1 Favorit ohne Sender',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'Die Adresse ist ungültig';

  @override
  String backupErrDownload(int code) {
    return 'Download nicht möglich (HTTP $code)';
  }

  @override
  String get backupErrNotBackup => 'Die Datei ist keine gültige Sicherung';

  @override
  String get backupErrNotFred => 'Die Datei ist keine Fred-TV-Sicherung';

  @override
  String get backupErrNoVersion => 'Die Sicherung enthält keine Versionsangabe';

  @override
  String get backupErrNewer =>
      'Die Sicherung stammt aus einer neueren Version der App';

  @override
  String get epgUrlLabel =>
      'Adresse (.xml oder .xml.gz); leer lassen zum Entfernen';

  @override
  String get cameraUrlLabel => 'RTSP-Adresse; leer lassen zum Entfernen';

  @override
  String get cameraRemoved => 'Kamera entfernt';

  @override
  String cameraSaved(String name) {
    return 'Kamera gespeichert: Du findest sie als Sender „$name“ unter Favoriten';
  }

  @override
  String get deadClearConfirm => 'Markierungen ausgefallener Sender löschen?';

  @override
  String get deadClearAction => 'Löschen';

  @override
  String get sourceRefresh => 'Aktualisieren';

  @override
  String get sourceDisable => 'Deaktivieren';

  @override
  String get sourceEnable => 'Aktivieren';

  @override
  String sourceDeleteConfirm(String name) {
    return 'Quelle „$name“ und ihre Sender löschen?';
  }

  @override
  String get sourceDisabled => 'Deaktiviert';

  @override
  String get sourceNeverRefreshed => 'Nie aktualisiert';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Aktualisiert $ago';
  }

  @override
  String get playlistNameLabel => 'Name der Liste';

  @override
  String get playlistDuplicate =>
      'Eine Liste mit diesem Namen existiert bereits';

  @override
  String get addM3uTitle => 'M3U-Liste hinzufügen';

  @override
  String get addM3uUrlLabel => 'URL der M3U-Liste';

  @override
  String get addM3uButton => 'Liste hinzufügen';

  @override
  String get addM3uFillAll => 'Fülle alle Felder aus';

  @override
  String get addM3uAdding => 'Liste wird hinzugefügt…';

  @override
  String get addM3uAdded => 'Liste erfolgreich hinzugefügt';

  @override
  String get urlMustBeHttp => 'Die URL muss mit http:// oder https:// beginnen';

  @override
  String get sourceErrUnavailable => 'Diese Liste ist nicht verfügbar';

  @override
  String get sourceErrGeneric => 'Die Liste konnte nicht hinzugefügt werden';

  @override
  String get iptvTitle => 'iptv-org-Listen';

  @override
  String get iptvSectionRecommended => 'Empfohlen';

  @override
  String get iptvSectionCountries => 'Länder';

  @override
  String get iptvSectionCategories => 'Kategorien';

  @override
  String get iptvAlreadyAdded => 'Bereits hinzugefügt';

  @override
  String iptvAdding(String name) {
    return '„$name“ wird hinzugefügt…';
  }

  @override
  String iptvAdded(String name) {
    return '„$name“ hinzugefügt';
  }

  @override
  String get iptvLoadFailed =>
      'Der Katalog konnte nicht geladen werden. Prüfe deine Verbindung.';

  @override
  String get iptvKindLanguage => 'Sprache';

  @override
  String get iptvAddedBadge => 'Hinzugefügt';

  @override
  String get iptvAllSpanish => 'Alles auf Spanisch';

  @override
  String get iptvCatNews => 'Nachrichten';

  @override
  String get iptvCatSports => 'Sport';

  @override
  String get iptvCatKids => 'Kinder';

  @override
  String get iptvCatMovies => 'Filme';

  @override
  String get iptvCatMusic => 'Musik';

  @override
  String get iptvCatDocumentary => 'Dokumentationen';
}

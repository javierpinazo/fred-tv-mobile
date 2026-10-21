// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get navChannels => 'Channels';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navMyLists => 'My lists';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get linkChannelUnavailable => 'That channel is no longer available';

  @override
  String get channelUnavailable => 'This channel is no longer available';

  @override
  String get bootstrapPreparing => 'Preparing channels…';

  @override
  String get bootstrapFailed => 'Couldn\'t download the channel list';

  @override
  String get agoMoment => 'just now';

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n d ago';
  }

  @override
  String get browserAllChannels => 'All channels';

  @override
  String get browserRecents => 'Recent';

  @override
  String get browserFooterHint => 'OK Play  ·  Hold OK Options  ·  ← Menu';

  @override
  String get browserEmptyFavorites =>
      'You don\'t have any favorites yet. Hold OK on a channel to add it.';

  @override
  String get browserEmptyGroup => 'There are no channels in this group';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get deadMarkRemoved => 'Mark removed';

  @override
  String get deadMarked => 'Marked as down';

  @override
  String get menuFavoriteAdd => 'Add to favorites';

  @override
  String get menuFavoriteRemove => 'Remove from favorites';

  @override
  String get menuAddToList => 'Add to a list…';

  @override
  String get menuShowGuide => 'View schedule';

  @override
  String get menuDeadClear => 'Clear the down mark';

  @override
  String get menuDeadMark => 'Mark as down';

  @override
  String get searchUpdateListsForCountries =>
      'Update your lists to see the countries';

  @override
  String get searchCountryTitle => 'Country';

  @override
  String get searchAllCountries => 'All countries';

  @override
  String get searchCountryAllShort => 'All';

  @override
  String searchCountryChip(String value) {
    return 'Country: $value';
  }

  @override
  String get searchLabel => 'Search channels';

  @override
  String get searchHint => 'Press OK to type';

  @override
  String searchStatusIdle(int min) {
    return 'Type at least $min letters or pick a country';
  }

  @override
  String get searchStatusSearching => 'Searching…';

  @override
  String searchStatusResults(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get searchStatusNoCountryChannels => 'No channels from this country';

  @override
  String searchStatusNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchStatusError => 'Search error. Try again.';

  @override
  String get playlistNew => 'New list';

  @override
  String get playlistCreate => 'Create';

  @override
  String get playlistCreateFailed => 'Couldn\'t create the list';

  @override
  String playlistAddedTo(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Already in \"$name\"';
  }

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistRenameFailed => 'Couldn\'t rename it';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete the list \"$name\"?';
  }

  @override
  String get playlistAddChannelByUrl => 'Add channel by URL';

  @override
  String get playlistChannelNameLabel => 'Channel name';

  @override
  String get playlistStreamUrlLabel => 'Stream URL';

  @override
  String get playlistAddChannelFailed => 'Couldn\'t add the channel';

  @override
  String get playlistMoveUp => 'Move earlier';

  @override
  String get playlistMoveDown => 'Move later';

  @override
  String get playlistRemoveFromList => 'Remove from list';

  @override
  String get playlistDeleteChannel => 'Delete channel';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst => 'Create your first list with \"New list\".';

  @override
  String get playlistEmptyList =>
      'This list is empty. Hold OK on any channel and choose \"Add to a list…\".';

  @override
  String get keyboardDone => 'Done';

  @override
  String get keyboardSearch => 'Search';

  @override
  String get keyboardShift => 'Shift';

  @override
  String get keyboardSpace => 'Space';

  @override
  String get keyboardBackspace => '⌫ Delete';

  @override
  String get keyboardClear => 'Clear';

  @override
  String get keyboardSystem => 'Voice / system';

  @override
  String get guideToday => 'Today';

  @override
  String get guideTomorrow => 'Tomorrow';

  @override
  String get guideWeekdaysShort => 'Mon|Tue|Wed|Thu|Fri|Sat|Sun';

  @override
  String get guidePrevious => 'Previous';

  @override
  String get guideNext => 'Next';

  @override
  String get guideNowBadge => 'NOW';

  @override
  String get guideLoadFailed => 'Couldn\'t load the guide';

  @override
  String get guideEmptyDay => 'No schedule for this day';

  @override
  String get playerSetCameraFirst => 'Set up the camera in Settings first';

  @override
  String get playerMenuAudio => 'Audio';

  @override
  String get playerMenuSubtitles => 'Subtitles';

  @override
  String get playerMenuLast => 'Back to the previous channel';

  @override
  String get playerMenuFit => 'Adjust picture';

  @override
  String get playerMenuToMpv => 'Use mpv on this channel (audio and subtitles)';

  @override
  String get playerMenuToExo => 'Use ExoPlayer on this channel';

  @override
  String get playerCamShow => 'Show camera';

  @override
  String get playerCamHide => 'Hide camera';

  @override
  String get playerCamInBox => 'Camera in the small box (channel full screen)';

  @override
  String get playerCamFull => 'Camera full screen';

  @override
  String get playerCamZoom => 'Camera zoom';

  @override
  String get playerCamRetry => 'Retry camera';

  @override
  String get playerLoading => 'Loading…';

  @override
  String get playerPaused => 'Paused';

  @override
  String get playerLive => 'Live';

  @override
  String get playerKeyHintLive =>
      '↑↓ Change channel  ·  OK Info  ·  Hold OK Options  ·  Back Exit';

  @override
  String get playerKeyHintVod =>
      '←→ 10 s  ·  OK Pause  ·  Hold OK Options  ·  Back Exit';

  @override
  String get playerCamNoSignal => 'Camera has no signal';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Move  ·  OK Change zoom  ·  Back Done';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Channel $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Now: $title';
  }

  @override
  String get playerErrorTitle => 'Couldn\'t play this channel';

  @override
  String get playerNextChannel => 'Next channel';

  @override
  String get playerBack => 'Back';

  @override
  String get settingsAddFromIptvOrg => 'Add from iptv-org';

  @override
  String get settingsAddM3u => 'Add M3U list by URL';

  @override
  String get settingsRefreshNow => 'Refresh lists now';

  @override
  String get settingsAutoRefresh => 'Automatic refresh (every 24 h)';

  @override
  String get settingsAutoOn => 'On';

  @override
  String get settingsAutoOff => 'Off';

  @override
  String get settingsBuffer => 'Playback buffer';

  @override
  String get settingsBufferHint =>
      'More seconds = fewer stutters; starts a little later';

  @override
  String get settingsEngine => 'Video engine';

  @override
  String get settingsEngineAutoHint => 'ExoPlayer and, if it fails, mpv';

  @override
  String get settingsEngineMpvHint => 'mpv only (the most compatible)';

  @override
  String get engineModeAuto => 'Automatic';

  @override
  String get engineModeMpv => 'mpv only';

  @override
  String get settingsDecoding => 'Video decoding (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'If a 1080p channel stutters with mpv, try \"Zero-copy\"';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Experimental: no frame copying; if there\'s no picture, it goes back to automatic';

  @override
  String get settingsDecodingZeroCopy => 'Zero-copy';

  @override
  String get settingsDecodingAuto => 'Automatic';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTextSizeHint =>
      'Enlarges the text across the whole interface';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsHighContrastHint =>
      'Lighter text and a thicker yellow focus border';

  @override
  String get settingsHideDead => 'Hide down channels';

  @override
  String get settingsHideDeadHint =>
      'In Channels and Search (Favorites always shows them)';

  @override
  String get settingsDeadChannels => 'Down channels';

  @override
  String get settingsDeadChannelsHint =>
      'They\'re skipped when changing channel. OK to clear the marks';

  @override
  String get settingsDeadNone => 'None';

  @override
  String settingsDeadCount(int n) {
    return '$n marked';
  }

  @override
  String get settingsHideAdult => 'Hide adult content';

  @override
  String get settingsHideAdultHintPin => 'Turning it off requires the PIN';

  @override
  String get settingsHideAdultHintNoPin => 'Create a PIN to protect it';

  @override
  String get settingsPin => 'Parental control PIN';

  @override
  String get settingsPinHint => '4 digits; protects the adult filter';

  @override
  String get settingsPinSet => 'Set';

  @override
  String get settingsPinNone => 'No PIN';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupHint =>
      'Export or import favorites, your own lists and settings';

  @override
  String get settingsEpg => 'Custom guide (XMLTV)';

  @override
  String get settingsEpgHint =>
      'More channels with a guide; added to your countries\' guides';

  @override
  String get settingsEpgSet => 'Set';

  @override
  String get settingsEpgUnset => 'Not set';

  @override
  String get settingsCamera => 'Security camera';

  @override
  String get settingsCameraHint =>
      'Shown as a channel and in a small box (hold OK on a channel)';

  @override
  String get settingsCameraSet => 'Set up';

  @override
  String get settingsCameraUnset => 'No camera';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'Language of the TV interface';

  @override
  String get settingsLanguageAuto => 'Automatic (system)';

  @override
  String get settingsMySources => 'My sources';

  @override
  String get settingsAlreadyRefreshing =>
      'The lists are already being refreshed';

  @override
  String get settingsRefreshing => 'Refreshing lists…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lists couldn\'t be refreshed',
      one: '1 list couldn\'t be refreshed',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Lists refreshed';

  @override
  String get settingsRefreshFailed => 'Couldn\'t refresh the lists';

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String get pinNew => 'New PIN';

  @override
  String get pinRepeat => 'Repeat the PIN';

  @override
  String get pinMismatch => 'The PINs don\'t match';

  @override
  String get pinEnter => 'Enter the PIN';

  @override
  String get pinEnterCurrent => 'Enter the current PIN';

  @override
  String get pinSaved => 'PIN saved';

  @override
  String get pinRemoved => 'PIN removed';

  @override
  String get pinChange => 'Change PIN';

  @override
  String get pinRemove => 'Remove PIN';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupImportMenu => 'Import backup…';

  @override
  String backupSavedTo(String path) {
    return 'Backup saved to $path';
  }

  @override
  String get backupSaveFailed => 'Couldn\'t save the backup';

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String get backupFromUrl => 'From a URL…';

  @override
  String get backupFromPicker => 'From a file on the device…';

  @override
  String get backupImportFromUrlTitle => 'Import from a URL';

  @override
  String get backupUrlLabel => 'Backup address (.json)';

  @override
  String get backupImportConfirm => 'Import';

  @override
  String get backupNoFile => 'No file was chosen';

  @override
  String get backupImporting => 'Importing…';

  @override
  String backupImported(String summary) {
    return 'Backup imported: $summary';
  }

  @override
  String get backupImportFailed => 'Couldn\'t import the backup';

  @override
  String backupSummaryLists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryFavorites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favorites',
      one: '1 favorite',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n new own lists',
      one: '1 new own list',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n channels in lists',
      one: '1 channel in lists',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n own channels',
      one: '1 own channel',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n settings',
      one: '1 setting',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Nothing new to import';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favorites without a channel',
      one: '1 favorite without a channel',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'The address isn\'t valid';

  @override
  String backupErrDownload(int code) {
    return 'Couldn\'t download (HTTP $code)';
  }

  @override
  String get backupErrNotBackup => 'The file isn\'t a valid backup';

  @override
  String get backupErrNotFred => 'The file isn\'t a Fred TV backup';

  @override
  String get backupErrNoVersion => 'The backup doesn\'t state its version';

  @override
  String get backupErrNewer => 'The backup is from a newer version of the app';

  @override
  String get epgUrlLabel =>
      'Address (.xml or .xml.gz); leave empty to remove it';

  @override
  String get cameraUrlLabel => 'RTSP address; leave empty to remove it';

  @override
  String get cameraRemoved => 'Camera removed';

  @override
  String cameraSaved(String name) {
    return 'Camera saved: find it as the \"$name\" channel in Favorites';
  }

  @override
  String get deadClearConfirm => 'Clear the down-channel marks?';

  @override
  String get deadClearAction => 'Clear';

  @override
  String get sourceRefresh => 'Refresh';

  @override
  String get sourceDisable => 'Disable';

  @override
  String get sourceEnable => 'Enable';

  @override
  String sourceDeleteConfirm(String name) {
    return 'Delete the source \"$name\" and its channels?';
  }

  @override
  String get sourceDisabled => 'Disabled';

  @override
  String get sourceNeverRefreshed => 'Never refreshed';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Refreshed $ago';
  }

  @override
  String get playlistNameLabel => 'List name';

  @override
  String get playlistDuplicate => 'A list with that name already exists';

  @override
  String get addM3uTitle => 'Add M3U list';

  @override
  String get addM3uUrlLabel => 'M3U list URL';

  @override
  String get addM3uButton => 'Add list';

  @override
  String get addM3uFillAll => 'Fill in all the fields';

  @override
  String get addM3uAdding => 'Adding list…';

  @override
  String get addM3uAdded => 'List added successfully';

  @override
  String get urlMustBeHttp => 'The URL must start with http:// or https://';

  @override
  String get sourceErrUnavailable => 'This list isn\'t available';

  @override
  String get sourceErrGeneric => 'Couldn\'t add the list';

  @override
  String get iptvTitle => 'iptv-org lists';

  @override
  String get iptvSectionRecommended => 'Recommended';

  @override
  String get iptvSectionCountries => 'Countries';

  @override
  String get iptvSectionCategories => 'Categories';

  @override
  String get iptvAlreadyAdded => 'Already added';

  @override
  String iptvAdding(String name) {
    return 'Adding \"$name\"…';
  }

  @override
  String iptvAdded(String name) {
    return '\"$name\" added';
  }

  @override
  String get iptvLoadFailed =>
      'Couldn\'t load the catalog. Check your connection.';

  @override
  String get iptvKindLanguage => 'Language';

  @override
  String get iptvAddedBadge => 'Added';

  @override
  String get iptvAllSpanish => 'Everything in Spanish';

  @override
  String get iptvCatNews => 'News';

  @override
  String get iptvCatSports => 'Sports';

  @override
  String get iptvCatKids => 'Kids';

  @override
  String get iptvCatMovies => 'Movies';

  @override
  String get iptvCatMusic => 'Music';

  @override
  String get iptvCatDocumentary => 'Documentaries';
}

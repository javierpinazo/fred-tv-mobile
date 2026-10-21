// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonPlay => 'Riproduci';

  @override
  String get commonOn => 'Attivo';

  @override
  String get commonOff => 'Disattivo';

  @override
  String get navChannels => 'Canali';

  @override
  String get navFavorites => 'Preferiti';

  @override
  String get navMyLists => 'Le mie liste';

  @override
  String get navSearch => 'Cerca';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get linkChannelUnavailable => 'Quel canale non è più disponibile';

  @override
  String get channelUnavailable => 'Questo canale non è più disponibile';

  @override
  String get bootstrapPreparing => 'Preparazione dei canali…';

  @override
  String get bootstrapFailed => 'Impossibile scaricare l\'elenco dei canali';

  @override
  String get agoMoment => 'adesso';

  @override
  String agoMinutes(int n) {
    return '$n min fa';
  }

  @override
  String agoHours(int n) {
    return '$n h fa';
  }

  @override
  String agoDays(int n) {
    return '$n g fa';
  }

  @override
  String get browserAllChannels => 'Tutti i canali';

  @override
  String get browserRecents => 'Recenti';

  @override
  String get browserFooterHint =>
      'OK Riproduci  ·  Tieni OK Opzioni  ·  ← Menu';

  @override
  String get browserEmptyFavorites =>
      'Non hai ancora preferiti. Tieni premuto OK su un canale per aggiungerlo.';

  @override
  String get browserEmptyGroup => 'Non ci sono canali in questo gruppo';

  @override
  String get favoriteAdded => 'Aggiunto ai preferiti';

  @override
  String get favoriteRemoved => 'Rimosso dai preferiti';

  @override
  String get deadMarkRemoved => 'Segno rimosso';

  @override
  String get deadMarked => 'Segnato come non funzionante';

  @override
  String get menuFavoriteAdd => 'Aggiungi ai preferiti';

  @override
  String get menuFavoriteRemove => 'Rimuovi dai preferiti';

  @override
  String get menuAddToList => 'Aggiungi a una lista…';

  @override
  String get menuShowGuide => 'Vedi programmazione';

  @override
  String get menuDeadClear => 'Rimuovi il segno di non funzionante';

  @override
  String get menuDeadMark => 'Segna come non funzionante';

  @override
  String get searchUpdateListsForCountries =>
      'Aggiorna le liste per vedere i paesi';

  @override
  String get searchCountryTitle => 'Paese';

  @override
  String get searchAllCountries => 'Tutti i paesi';

  @override
  String get searchCountryAllShort => 'Tutti';

  @override
  String searchCountryChip(String value) {
    return 'Paese: $value';
  }

  @override
  String get searchLabel => 'Cerca canali';

  @override
  String get searchHint => 'Premi OK per scrivere';

  @override
  String searchStatusIdle(int min) {
    return 'Scrivi almeno $min lettere o scegli un paese';
  }

  @override
  String get searchStatusSearching => 'Ricerca in corso…';

  @override
  String searchStatusResults(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n risultati',
      one: '1 risultato',
    );
    return '$_temp0';
  }

  @override
  String get searchStatusNoCountryChannels => 'Nessun canale di questo paese';

  @override
  String searchStatusNoResults(String query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String get searchStatusError => 'Errore durante la ricerca. Riprova.';

  @override
  String get playlistNew => 'Nuova lista';

  @override
  String get playlistCreate => 'Crea';

  @override
  String get playlistCreateFailed => 'Impossibile creare la lista';

  @override
  String playlistAddedTo(String name) {
    return 'Aggiunto a \"$name\"';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Già in \"$name\"';
  }

  @override
  String get playlistRename => 'Rinomina';

  @override
  String get playlistRenameFailed => 'Impossibile rinominare';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Eliminare la lista \"$name\"?';
  }

  @override
  String get playlistAddChannelByUrl => 'Aggiungi canale tramite URL';

  @override
  String get playlistChannelNameLabel => 'Nome del canale';

  @override
  String get playlistStreamUrlLabel => 'URL dello stream';

  @override
  String get playlistAddChannelFailed => 'Impossibile aggiungere il canale';

  @override
  String get playlistMoveUp => 'Sposta prima';

  @override
  String get playlistMoveDown => 'Sposta dopo';

  @override
  String get playlistRemoveFromList => 'Rimuovi dalla lista';

  @override
  String get playlistDeleteChannel => 'Elimina canale';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canali',
      one: '1 canale',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst =>
      'Crea la tua prima lista con \"Nuova lista\".';

  @override
  String get playlistEmptyList =>
      'Questa lista è vuota. Tieni premuto OK su un canale e scegli \"Aggiungi a una lista…\".';

  @override
  String get keyboardDone => 'Fatto';

  @override
  String get keyboardSearch => 'Cerca';

  @override
  String get keyboardShift => 'Maiusc';

  @override
  String get keyboardSpace => 'Spazio';

  @override
  String get keyboardBackspace => '⌫ Cancella';

  @override
  String get keyboardClear => 'Svuota';

  @override
  String get keyboardSystem => 'Voce / sistema';

  @override
  String get guideToday => 'Oggi';

  @override
  String get guideTomorrow => 'Domani';

  @override
  String get guideWeekdaysShort => 'lun|mar|mer|gio|ven|sab|dom';

  @override
  String get guidePrevious => 'Precedente';

  @override
  String get guideNext => 'Successivo';

  @override
  String get guideNowBadge => 'ORA';

  @override
  String get guideLoadFailed => 'Impossibile caricare la guida';

  @override
  String get guideEmptyDay => 'Nessuna programmazione per questo giorno';

  @override
  String get playerSetCameraFirst =>
      'Prima imposta la telecamera nelle Impostazioni';

  @override
  String get playerMenuAudio => 'Audio';

  @override
  String get playerMenuSubtitles => 'Sottotitoli';

  @override
  String get playerMenuLast => 'Torna al canale precedente';

  @override
  String get playerMenuFit => 'Adatta immagine';

  @override
  String get playerMenuToMpv =>
      'Usa mpv su questo canale (audio e sottotitoli)';

  @override
  String get playerMenuToExo => 'Usa ExoPlayer su questo canale';

  @override
  String get playerCamShow => 'Mostra telecamera';

  @override
  String get playerCamHide => 'Nascondi telecamera';

  @override
  String get playerCamInBox =>
      'Telecamera nel riquadro (canale a schermo intero)';

  @override
  String get playerCamFull => 'Telecamera a schermo intero';

  @override
  String get playerCamZoom => 'Zoom della telecamera';

  @override
  String get playerCamRetry => 'Riprova telecamera';

  @override
  String get playerLoading => 'Caricamento…';

  @override
  String get playerPaused => 'In pausa';

  @override
  String get playerLive => 'In diretta';

  @override
  String get playerKeyHintLive =>
      '↑↓ Cambia canale  ·  OK Info  ·  Tieni OK Opzioni  ·  Indietro Esci';

  @override
  String get playerKeyHintVod =>
      '←→ 10 s  ·  OK Pausa  ·  Tieni OK Opzioni  ·  Indietro Esci';

  @override
  String get playerCamNoSignal => 'Telecamera senza segnale';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Sposta  ·  OK Cambia zoom  ·  Indietro Fine';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Canale $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Ora: $title';
  }

  @override
  String get playerErrorTitle => 'Impossibile riprodurre questo canale';

  @override
  String get playerNextChannel => 'Canale successivo';

  @override
  String get playerBack => 'Indietro';

  @override
  String get settingsAddFromIptvOrg => 'Aggiungi da iptv-org';

  @override
  String get settingsAddM3u => 'Aggiungi lista M3U tramite URL';

  @override
  String get settingsRefreshNow => 'Aggiorna le liste ora';

  @override
  String get settingsAutoRefresh => 'Aggiornamento automatico (ogni 24 h)';

  @override
  String get settingsAutoOn => 'Attivo';

  @override
  String get settingsAutoOff => 'Disattivo';

  @override
  String get settingsBuffer => 'Buffer di riproduzione';

  @override
  String get settingsBufferHint =>
      'Più secondi = meno scatti; parte un po\' più tardi';

  @override
  String get settingsEngine => 'Motore video';

  @override
  String get settingsEngineAutoHint => 'ExoPlayer e, se fallisce, mpv';

  @override
  String get settingsEngineMpvHint => 'Solo mpv (il più compatibile)';

  @override
  String get engineModeAuto => 'Automatico';

  @override
  String get engineModeMpv => 'Solo mpv';

  @override
  String get settingsDecoding => 'Decodifica video (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'Se un canale 1080p scatta con mpv, prova \"Senza copia\"';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Sperimentale: senza copiare i fotogrammi; se non c\'è immagine, torna all\'automatica';

  @override
  String get settingsDecodingZeroCopy => 'Senza copia';

  @override
  String get settingsDecodingAuto => 'Automatica';

  @override
  String get settingsTextSize => 'Dimensione del testo';

  @override
  String get settingsTextSizeHint =>
      'Ingrandisce i testi di tutta l\'interfaccia';

  @override
  String get settingsHighContrast => 'Alto contrasto';

  @override
  String get settingsHighContrastHint =>
      'Testo più chiaro e bordo di focus giallo più spesso';

  @override
  String get settingsHideDead => 'Nascondi i canali non funzionanti';

  @override
  String get settingsHideDeadHint =>
      'In Canali e Cerca (Preferiti li mostra sempre)';

  @override
  String get settingsDeadChannels => 'Canali non funzionanti';

  @override
  String get settingsDeadChannelsHint =>
      'Vengono saltati quando cambi canale. OK per cancellare i segni';

  @override
  String get settingsDeadNone => 'Nessuno';

  @override
  String settingsDeadCount(int n) {
    return '$n segnati';
  }

  @override
  String get settingsHideAdult => 'Nascondi i contenuti per adulti';

  @override
  String get settingsHideAdultHintPin => 'Per disattivarlo serve il PIN';

  @override
  String get settingsHideAdultHintNoPin => 'Crea un PIN per proteggerlo';

  @override
  String get settingsPin => 'PIN del controllo parentale';

  @override
  String get settingsPinHint => '4 cifre; protegge il filtro per adulti';

  @override
  String get settingsPinSet => 'Impostato';

  @override
  String get settingsPinNone => 'Nessun PIN';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupHint =>
      'Esporta o importa preferiti, liste personali e impostazioni';

  @override
  String get settingsEpg => 'Guida personalizzata (XMLTV)';

  @override
  String get settingsEpgHint =>
      'Più canali con guida; si aggiunge a quella dei tuoi paesi';

  @override
  String get settingsEpgSet => 'Impostata';

  @override
  String get settingsEpgUnset => 'Non impostata';

  @override
  String get settingsCamera => 'Telecamera di sicurezza';

  @override
  String get settingsCameraHint =>
      'Si vede come canale e in un riquadro (tieni OK su un canale)';

  @override
  String get settingsCameraSet => 'Configurata';

  @override
  String get settingsCameraUnset => 'Nessuna telecamera';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLanguageHint => 'Lingua dell\'interfaccia TV';

  @override
  String get settingsLanguageAuto => 'Automatico (sistema)';

  @override
  String get settingsMySources => 'Le mie fonti';

  @override
  String get settingsAlreadyRefreshing => 'Le liste sono già in aggiornamento';

  @override
  String get settingsRefreshing => 'Aggiornamento delle liste…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n liste non sono state aggiornate',
      one: '1 lista non è stata aggiornata',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Liste aggiornate';

  @override
  String get settingsRefreshFailed => 'Impossibile aggiornare le liste';

  @override
  String get pinWrong => 'PIN errato';

  @override
  String get pinNew => 'Nuovo PIN';

  @override
  String get pinRepeat => 'Ripeti il PIN';

  @override
  String get pinMismatch => 'I PIN non coincidono';

  @override
  String get pinEnter => 'Inserisci il PIN';

  @override
  String get pinEnterCurrent => 'Inserisci il PIN attuale';

  @override
  String get pinSaved => 'PIN salvato';

  @override
  String get pinRemoved => 'PIN rimosso';

  @override
  String get pinChange => 'Cambia PIN';

  @override
  String get pinRemove => 'Rimuovi PIN';

  @override
  String get backupExport => 'Esporta backup';

  @override
  String get backupImportMenu => 'Importa backup…';

  @override
  String backupSavedTo(String path) {
    return 'Backup salvato in $path';
  }

  @override
  String get backupSaveFailed => 'Impossibile salvare il backup';

  @override
  String get backupImportTitle => 'Importa backup';

  @override
  String get backupFromUrl => 'Da un URL…';

  @override
  String get backupFromPicker => 'Da un file del dispositivo…';

  @override
  String get backupImportFromUrlTitle => 'Importa da un URL';

  @override
  String get backupUrlLabel => 'Indirizzo del backup (.json)';

  @override
  String get backupImportConfirm => 'Importa';

  @override
  String get backupNoFile => 'Nessun file scelto';

  @override
  String get backupImporting => 'Importazione…';

  @override
  String backupImported(String summary) {
    return 'Backup importato: $summary';
  }

  @override
  String get backupImportFailed => 'Impossibile importare il backup';

  @override
  String backupSummaryLists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n liste',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryFavorites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n preferiti',
      one: '1 preferito',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nuove liste personali',
      one: '1 nuova lista personale',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canali nelle liste',
      one: '1 canale nelle liste',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canali personali',
      one: '1 canale personale',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n impostazioni',
      one: '1 impostazione',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Niente di nuovo da importare';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n preferiti senza canale',
      one: '1 preferito senza canale',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'L\'indirizzo non è valido';

  @override
  String backupErrDownload(int code) {
    return 'Impossibile scaricare (HTTP $code)';
  }

  @override
  String get backupErrNotBackup => 'Il file non è un backup valido';

  @override
  String get backupErrNotFred => 'Il file non è un backup di Fred TV';

  @override
  String get backupErrNoVersion => 'Il backup non indica la sua versione';

  @override
  String get backupErrNewer =>
      'Il backup proviene da una versione più recente dell\'app';

  @override
  String get epgUrlLabel => 'Indirizzo (.xml o .xml.gz); vuoto per rimuoverlo';

  @override
  String get cameraUrlLabel => 'Indirizzo RTSP; vuoto per rimuoverlo';

  @override
  String get cameraRemoved => 'Telecamera rimossa';

  @override
  String cameraSaved(String name) {
    return 'Telecamera salvata: cercala come canale \"$name\" in Preferiti';
  }

  @override
  String get deadClearConfirm =>
      'Cancellare i segni dei canali non funzionanti?';

  @override
  String get deadClearAction => 'Cancella';

  @override
  String get sourceRefresh => 'Aggiorna';

  @override
  String get sourceDisable => 'Disattiva';

  @override
  String get sourceEnable => 'Attiva';

  @override
  String sourceDeleteConfirm(String name) {
    return 'Eliminare la fonte \"$name\" e i suoi canali?';
  }

  @override
  String get sourceDisabled => 'Disattivata';

  @override
  String get sourceNeverRefreshed => 'Mai aggiornata';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Aggiornata $ago';
  }

  @override
  String get playlistNameLabel => 'Nome della lista';

  @override
  String get playlistDuplicate => 'Esiste già una lista con questo nome';

  @override
  String get addM3uTitle => 'Aggiungi lista M3U';

  @override
  String get addM3uUrlLabel => 'URL della lista M3U';

  @override
  String get addM3uButton => 'Aggiungi lista';

  @override
  String get addM3uFillAll => 'Compila tutti i campi';

  @override
  String get addM3uAdding => 'Aggiunta della lista…';

  @override
  String get addM3uAdded => 'Lista aggiunta correttamente';

  @override
  String get urlMustBeHttp => 'L\'URL deve iniziare con http:// o https://';

  @override
  String get sourceErrUnavailable => 'Questa lista non è disponibile';

  @override
  String get sourceErrGeneric => 'Impossibile aggiungere la lista';

  @override
  String get iptvTitle => 'Liste di iptv-org';

  @override
  String get iptvSectionRecommended => 'Consigliate';

  @override
  String get iptvSectionCountries => 'Paesi';

  @override
  String get iptvSectionCategories => 'Categorie';

  @override
  String get iptvAlreadyAdded => 'Già aggiunta';

  @override
  String iptvAdding(String name) {
    return 'Aggiunta di \"$name\"…';
  }

  @override
  String iptvAdded(String name) {
    return '\"$name\" aggiunta';
  }

  @override
  String get iptvLoadFailed =>
      'Impossibile caricare il catalogo. Controlla la connessione.';

  @override
  String get iptvKindLanguage => 'Lingua';

  @override
  String get iptvAddedBadge => 'Aggiunta';

  @override
  String get iptvAllSpanish => 'Tutto in spagnolo';

  @override
  String get iptvCatNews => 'Notizie';

  @override
  String get iptvCatSports => 'Sport';

  @override
  String get iptvCatKids => 'Bambini';

  @override
  String get iptvCatMovies => 'Film';

  @override
  String get iptvCatMusic => 'Musica';

  @override
  String get iptvCatDocumentary => 'Documentari';
}

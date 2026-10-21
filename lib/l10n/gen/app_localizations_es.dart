// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonPlay => 'Reproducir';

  @override
  String get commonOn => 'Activado';

  @override
  String get commonOff => 'Desactivado';

  @override
  String get navChannels => 'Canales';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navMyLists => 'Mis listas';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get linkChannelUnavailable => 'Ese canal ya no está disponible';

  @override
  String get channelUnavailable => 'Este canal ya no está disponible';

  @override
  String get bootstrapPreparing => 'Preparando canales…';

  @override
  String get bootstrapFailed => 'No se pudo descargar la lista de canales';

  @override
  String get agoMoment => 'hace un momento';

  @override
  String agoMinutes(int n) {
    return 'hace $n min';
  }

  @override
  String agoHours(int n) {
    return 'hace $n h';
  }

  @override
  String agoDays(int n) {
    return 'hace $n d';
  }

  @override
  String get browserAllChannels => 'Todos los canales';

  @override
  String get browserRecents => 'Recientes';

  @override
  String get browserFooterHint =>
      'OK Reproducir  ·  Mantén OK Opciones  ·  ← Menú';

  @override
  String get browserEmptyFavorites =>
      'Aún no tienes favoritos. Mantén presionado OK sobre un canal para agregarlo.';

  @override
  String get browserEmptyGroup => 'No hay canales en este grupo';

  @override
  String get favoriteAdded => 'Agregado a favoritos';

  @override
  String get favoriteRemoved => 'Quitado de favoritos';

  @override
  String get deadMarkRemoved => 'Marca quitada';

  @override
  String get deadMarked => 'Marcado como caído';

  @override
  String get menuFavoriteAdd => 'Agregar a favoritos';

  @override
  String get menuFavoriteRemove => 'Quitar de favoritos';

  @override
  String get menuAddToList => 'Agregar a una lista…';

  @override
  String get menuShowGuide => 'Ver programación';

  @override
  String get menuDeadClear => 'Quitar marca de caído';

  @override
  String get menuDeadMark => 'Marcar como caído';

  @override
  String get searchUpdateListsForCountries =>
      'Actualiza las listas para ver los países';

  @override
  String get searchCountryTitle => 'País';

  @override
  String get searchAllCountries => 'Todos los países';

  @override
  String get searchCountryAllShort => 'Todos';

  @override
  String searchCountryChip(String value) {
    return 'País: $value';
  }

  @override
  String get searchLabel => 'Buscar canales';

  @override
  String get searchHint => 'Presiona OK para escribir';

  @override
  String searchStatusIdle(int min) {
    return 'Escribe al menos $min letras o elige un país';
  }

  @override
  String get searchStatusSearching => 'Buscando…';

  @override
  String searchStatusResults(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String get searchStatusNoCountryChannels => 'Sin canales de este país';

  @override
  String searchStatusNoResults(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get searchStatusError => 'Error al buscar. Intenta de nuevo.';

  @override
  String get playlistNew => 'Nueva lista';

  @override
  String get playlistCreate => 'Crear';

  @override
  String get playlistCreateFailed => 'No se pudo crear la lista';

  @override
  String playlistAddedTo(String name) {
    return 'Agregado a «$name»';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Ya está en «$name»';
  }

  @override
  String get playlistRename => 'Renombrar';

  @override
  String get playlistRenameFailed => 'No se pudo renombrar';

  @override
  String playlistDeleteConfirm(String name) {
    return '¿Eliminar la lista «$name»?';
  }

  @override
  String get playlistAddChannelByUrl => 'Agregar canal por URL';

  @override
  String get playlistChannelNameLabel => 'Nombre del canal';

  @override
  String get playlistStreamUrlLabel => 'URL del stream';

  @override
  String get playlistAddChannelFailed => 'No se pudo agregar el canal';

  @override
  String get playlistMoveUp => 'Mover antes';

  @override
  String get playlistMoveDown => 'Mover después';

  @override
  String get playlistRemoveFromList => 'Quitar de la lista';

  @override
  String get playlistDeleteChannel => 'Eliminar canal';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canales',
      one: '1 canal',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst => 'Crea tu primera lista con «Nueva lista».';

  @override
  String get playlistEmptyList =>
      'Esta lista está vacía. Mantén OK sobre cualquier canal y elige «Agregar a una lista…».';

  @override
  String get keyboardDone => 'Listo';

  @override
  String get keyboardSearch => 'Buscar';

  @override
  String get keyboardShift => 'Mayús';

  @override
  String get keyboardSpace => 'Espacio';

  @override
  String get keyboardBackspace => '⌫ Borrar';

  @override
  String get keyboardClear => 'Limpiar';

  @override
  String get keyboardSystem => 'Voz / sistema';

  @override
  String get guideToday => 'Hoy';

  @override
  String get guideTomorrow => 'Mañana';

  @override
  String get guideWeekdaysShort => 'lun|mar|mié|jue|vie|sáb|dom';

  @override
  String get guidePrevious => 'Anterior';

  @override
  String get guideNext => 'Siguiente';

  @override
  String get guideNowBadge => 'AHORA';

  @override
  String get guideLoadFailed => 'No se pudo cargar la guía';

  @override
  String get guideEmptyDay => 'Sin programación para este día';

  @override
  String get playerSetCameraFirst => 'Primero define la cámara en Ajustes';

  @override
  String get playerMenuAudio => 'Audio';

  @override
  String get playerMenuSubtitles => 'Subtítulos';

  @override
  String get playerMenuLast => 'Volver al canal anterior';

  @override
  String get playerMenuFit => 'Ajustar imagen';

  @override
  String get playerMenuToMpv => 'Usar mpv en este canal (audio y subtítulos)';

  @override
  String get playerMenuToExo => 'Usar ExoPlayer en este canal';

  @override
  String get playerCamShow => 'Mostrar cámara';

  @override
  String get playerCamHide => 'Ocultar cámara';

  @override
  String get playerCamInBox => 'Cámara en el recuadro (canal en grande)';

  @override
  String get playerCamFull => 'Cámara en pantalla grande';

  @override
  String get playerCamZoom => 'Zoom de la cámara';

  @override
  String get playerCamRetry => 'Reintentar cámara';

  @override
  String get playerLoading => 'Cargando…';

  @override
  String get playerPaused => 'Pausado';

  @override
  String get playerLive => 'En vivo';

  @override
  String get playerKeyHintLive =>
      '↑↓ Cambiar canal  ·  OK Info  ·  Mantén OK Opciones  ·  Atrás Salir';

  @override
  String get playerKeyHintVod =>
      '←→ 10 s  ·  OK Pausa  ·  Mantén OK Opciones  ·  Atrás Salir';

  @override
  String get playerCamNoSignal => 'Cámara sin señal';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Mover  ·  OK Cambiar zoom  ·  Atrás Terminar';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Canal $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Ahora: $title';
  }

  @override
  String get playerErrorTitle => 'No se pudo reproducir este canal';

  @override
  String get playerNextChannel => 'Siguiente canal';

  @override
  String get playerBack => 'Volver';

  @override
  String get settingsAddFromIptvOrg => 'Agregar desde iptv-org';

  @override
  String get settingsAddM3u => 'Agregar lista M3U por URL';

  @override
  String get settingsRefreshNow => 'Actualizar listas ahora';

  @override
  String get settingsAutoRefresh => 'Actualización automática (cada 24 h)';

  @override
  String get settingsAutoOn => 'Activada';

  @override
  String get settingsAutoOff => 'Desactivada';

  @override
  String get settingsBuffer => 'Buffer de reproducción';

  @override
  String get settingsBufferHint =>
      'Más segundos = menos tirones; empieza algo más tarde';

  @override
  String get settingsEngine => 'Motor de video';

  @override
  String get settingsEngineAutoHint => 'ExoPlayer y, si falla, mpv';

  @override
  String get settingsEngineMpvHint => 'Solo mpv (el más compatible)';

  @override
  String get engineModeAuto => 'Automático';

  @override
  String get engineModeMpv => 'Solo mpv';

  @override
  String get settingsDecoding => 'Decodificación de video (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'Si un canal 1080p va a tirones con mpv, prueba \"Sin copia\"';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Experimental: sin copiar fotogramas; si no da imagen, vuelve a la automática';

  @override
  String get settingsDecodingZeroCopy => 'Sin copia';

  @override
  String get settingsDecodingAuto => 'Automática';

  @override
  String get settingsTextSize => 'Tamaño de letra';

  @override
  String get settingsTextSizeHint => 'Agranda los textos de toda la interfaz';

  @override
  String get settingsHighContrast => 'Alto contraste';

  @override
  String get settingsHighContrastHint =>
      'Texto más claro y borde de foco amarillo más grueso';

  @override
  String get settingsHideDead => 'Ocultar canales caídos';

  @override
  String get settingsHideDeadHint =>
      'En Canales y Búsqueda (Favoritos siempre los muestra)';

  @override
  String get settingsDeadChannels => 'Canales caídos';

  @override
  String get settingsDeadChannelsHint =>
      'Se saltan al cambiar de canal. OK para limpiar las marcas';

  @override
  String get settingsDeadNone => 'Ninguno';

  @override
  String settingsDeadCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n marcados',
      one: '1 marcado',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideAdult => 'Ocultar contenido adulto';

  @override
  String get settingsHideAdultHintPin => 'Desactivarlo exige el PIN';

  @override
  String get settingsHideAdultHintNoPin => 'Crea un PIN para protegerlo';

  @override
  String get settingsPin => 'PIN de control parental';

  @override
  String get settingsPinHint => 'De 4 dígitos; protege el filtro de adultos';

  @override
  String get settingsPinSet => 'Configurado';

  @override
  String get settingsPinNone => 'Sin PIN';

  @override
  String get settingsBackup => 'Copia de seguridad';

  @override
  String get settingsBackupHint =>
      'Exporta o importa favoritos, listas propias y ajustes';

  @override
  String get settingsEpg => 'Guía personalizada (XMLTV)';

  @override
  String get settingsEpgHint =>
      'Más canales con guía; se suma a la de tus países';

  @override
  String get settingsEpgSet => 'Definida';

  @override
  String get settingsEpgUnset => 'Sin definir';

  @override
  String get settingsCamera => 'Cámara de seguridad';

  @override
  String get settingsCameraHint =>
      'Se ve como canal y en un recuadro (mantén OK en un canal)';

  @override
  String get settingsCameraSet => 'Configurada';

  @override
  String get settingsCameraUnset => 'Sin cámara';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageHint => 'Idioma de la interfaz de TV';

  @override
  String get settingsLanguageAuto => 'Automático (sistema)';

  @override
  String get settingsMySources => 'Mis fuentes';

  @override
  String get settingsAlreadyRefreshing => 'Ya se están actualizando las listas';

  @override
  String get settingsRefreshing => 'Actualizando listas…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listas no se pudieron actualizar',
      one: '1 lista no se pudo actualizar',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Listas actualizadas';

  @override
  String get settingsRefreshFailed => 'No se pudieron actualizar las listas';

  @override
  String get pinWrong => 'PIN incorrecto';

  @override
  String get pinNew => 'Nuevo PIN';

  @override
  String get pinRepeat => 'Repite el PIN';

  @override
  String get pinMismatch => 'Los PIN no coinciden';

  @override
  String get pinEnter => 'Introduce el PIN';

  @override
  String get pinEnterCurrent => 'Introduce el PIN actual';

  @override
  String get pinSaved => 'PIN guardado';

  @override
  String get pinRemoved => 'PIN quitado';

  @override
  String get pinChange => 'Cambiar PIN';

  @override
  String get pinRemove => 'Quitar PIN';

  @override
  String get backupExport => 'Exportar copia';

  @override
  String get backupImportMenu => 'Importar copia…';

  @override
  String backupSavedTo(String path) {
    return 'Copia guardada en $path';
  }

  @override
  String get backupSaveFailed => 'No se pudo guardar la copia';

  @override
  String get backupImportTitle => 'Importar copia';

  @override
  String get backupFromUrl => 'Desde una URL…';

  @override
  String get backupFromPicker => 'Desde un archivo del dispositivo…';

  @override
  String get backupImportFromUrlTitle => 'Importar desde una URL';

  @override
  String get backupUrlLabel => 'Dirección de la copia (.json)';

  @override
  String get backupImportConfirm => 'Importar';

  @override
  String get backupNoFile => 'No se eligió ningún archivo';

  @override
  String get backupImporting => 'Importando…';

  @override
  String backupImported(String summary) {
    return 'Copia importada: $summary';
  }

  @override
  String get backupImportFailed => 'No se pudo importar la copia';

  @override
  String backupSummaryLists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listas',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryFavorites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favoritos',
      one: '1 favorito',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listas propias nuevas',
      one: '1 lista propia nueva',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canales en listas',
      one: '1 canal en listas',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canales propios',
      one: '1 canal propio',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ajustes',
      one: '1 ajuste',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Nada nuevo que importar';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favoritos sin canal',
      one: '1 favorito sin canal',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'La dirección no es válida';

  @override
  String backupErrDownload(int code) {
    return 'No se pudo descargar (HTTP $code)';
  }

  @override
  String get backupErrNotBackup => 'El archivo no es una copia válida';

  @override
  String get backupErrNotFred => 'El archivo no es una copia de Fred TV';

  @override
  String get backupErrNoVersion => 'La copia no indica su versión';

  @override
  String get backupErrNewer => 'La copia es de una versión más nueva de la app';

  @override
  String get epgUrlLabel => 'Dirección (.xml o .xml.gz); vacío para quitarla';

  @override
  String get cameraUrlLabel => 'Dirección RTSP; vacío para quitarla';

  @override
  String get cameraRemoved => 'Cámara quitada';

  @override
  String cameraSaved(String name) {
    return 'Cámara guardada: búscala como canal «$name» en Favoritos';
  }

  @override
  String get deadClearConfirm => '¿Limpiar las marcas de canales caídos?';

  @override
  String get deadClearAction => 'Limpiar';

  @override
  String get sourceRefresh => 'Actualizar';

  @override
  String get sourceDisable => 'Desactivar';

  @override
  String get sourceEnable => 'Activar';

  @override
  String sourceDeleteConfirm(String name) {
    return '¿Eliminar la fuente «$name» y sus canales?';
  }

  @override
  String get sourceDisabled => 'Desactivada';

  @override
  String get sourceNeverRefreshed => 'Nunca actualizada';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Actualizada $ago';
  }

  @override
  String get playlistNameLabel => 'Nombre de la lista';

  @override
  String get playlistDuplicate => 'Ya existe una lista con ese nombre';

  @override
  String get addM3uTitle => 'Agregar lista M3U';

  @override
  String get addM3uUrlLabel => 'URL de la lista M3U';

  @override
  String get addM3uButton => 'Agregar lista';

  @override
  String get addM3uFillAll => 'Completa todos los campos';

  @override
  String get addM3uAdding => 'Agregando lista…';

  @override
  String get addM3uAdded => 'Lista agregada correctamente';

  @override
  String get urlMustBeHttp => 'La URL debe empezar con http:// o https://';

  @override
  String get sourceErrUnavailable => 'Esta lista no está disponible';

  @override
  String get sourceErrGeneric => 'No se pudo agregar la lista';

  @override
  String get iptvTitle => 'Listas de iptv-org';

  @override
  String get iptvSectionRecommended => 'Recomendados';

  @override
  String get iptvSectionCountries => 'Países';

  @override
  String get iptvSectionCategories => 'Categorías';

  @override
  String get iptvAlreadyAdded => 'Ya agregada';

  @override
  String iptvAdding(String name) {
    return 'Agregando «$name»…';
  }

  @override
  String iptvAdded(String name) {
    return '«$name» agregada';
  }

  @override
  String get iptvLoadFailed =>
      'No se pudo cargar el catálogo. Revisa tu conexión.';

  @override
  String get iptvKindLanguage => 'Idioma';

  @override
  String get iptvAddedBadge => 'Agregada';

  @override
  String get iptvAllSpanish => 'Todo en español';

  @override
  String get iptvCatNews => 'Noticias';

  @override
  String get iptvCatSports => 'Deportes';

  @override
  String get iptvCatKids => 'Infantil';

  @override
  String get iptvCatMovies => 'Películas';

  @override
  String get iptvCatMusic => 'Música';

  @override
  String get iptvCatDocumentary => 'Documentales';
}

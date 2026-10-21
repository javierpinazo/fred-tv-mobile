import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt')
  ];

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// No description provided for @commonPlay.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get commonPlay;

  /// No description provided for @commonOn.
  ///
  /// In es, this message translates to:
  /// **'Activado'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In es, this message translates to:
  /// **'Desactivado'**
  String get commonOff;

  /// No description provided for @navChannels.
  ///
  /// In es, this message translates to:
  /// **'Canales'**
  String get navChannels;

  /// No description provided for @navFavorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get navFavorites;

  /// No description provided for @navMyLists.
  ///
  /// In es, this message translates to:
  /// **'Mis listas'**
  String get navMyLists;

  /// No description provided for @navSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @linkChannelUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Ese canal ya no está disponible'**
  String get linkChannelUnavailable;

  /// No description provided for @channelUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este canal ya no está disponible'**
  String get channelUnavailable;

  /// No description provided for @bootstrapPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando canales…'**
  String get bootstrapPreparing;

  /// No description provided for @bootstrapFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar la lista de canales'**
  String get bootstrapFailed;

  /// No description provided for @agoMoment.
  ///
  /// In es, this message translates to:
  /// **'hace un momento'**
  String get agoMoment;

  /// No description provided for @agoMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n} d'**
  String agoDays(int n);

  /// No description provided for @browserAllChannels.
  ///
  /// In es, this message translates to:
  /// **'Todos los canales'**
  String get browserAllChannels;

  /// No description provided for @browserRecents.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get browserRecents;

  /// No description provided for @browserFooterHint.
  ///
  /// In es, this message translates to:
  /// **'OK Reproducir  ·  Mantén OK Opciones  ·  ← Menú'**
  String get browserFooterHint;

  /// No description provided for @browserEmptyFavorites.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes favoritos. Mantén presionado OK sobre un canal para agregarlo.'**
  String get browserEmptyFavorites;

  /// No description provided for @browserEmptyGroup.
  ///
  /// In es, this message translates to:
  /// **'No hay canales en este grupo'**
  String get browserEmptyGroup;

  /// No description provided for @favoriteAdded.
  ///
  /// In es, this message translates to:
  /// **'Agregado a favoritos'**
  String get favoriteAdded;

  /// No description provided for @favoriteRemoved.
  ///
  /// In es, this message translates to:
  /// **'Quitado de favoritos'**
  String get favoriteRemoved;

  /// No description provided for @deadMarkRemoved.
  ///
  /// In es, this message translates to:
  /// **'Marca quitada'**
  String get deadMarkRemoved;

  /// No description provided for @deadMarked.
  ///
  /// In es, this message translates to:
  /// **'Marcado como caído'**
  String get deadMarked;

  /// No description provided for @menuFavoriteAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar a favoritos'**
  String get menuFavoriteAdd;

  /// No description provided for @menuFavoriteRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get menuFavoriteRemove;

  /// No description provided for @menuAddToList.
  ///
  /// In es, this message translates to:
  /// **'Agregar a una lista…'**
  String get menuAddToList;

  /// No description provided for @menuShowGuide.
  ///
  /// In es, this message translates to:
  /// **'Ver programación'**
  String get menuShowGuide;

  /// No description provided for @menuDeadClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar marca de caído'**
  String get menuDeadClear;

  /// No description provided for @menuDeadMark.
  ///
  /// In es, this message translates to:
  /// **'Marcar como caído'**
  String get menuDeadMark;

  /// No description provided for @searchUpdateListsForCountries.
  ///
  /// In es, this message translates to:
  /// **'Actualiza las listas para ver los países'**
  String get searchUpdateListsForCountries;

  /// No description provided for @searchCountryTitle.
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get searchCountryTitle;

  /// No description provided for @searchAllCountries.
  ///
  /// In es, this message translates to:
  /// **'Todos los países'**
  String get searchAllCountries;

  /// No description provided for @searchCountryAllShort.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get searchCountryAllShort;

  /// No description provided for @searchCountryChip.
  ///
  /// In es, this message translates to:
  /// **'País: {value}'**
  String searchCountryChip(String value);

  /// No description provided for @searchLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar canales'**
  String get searchLabel;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Presiona OK para escribir'**
  String get searchHint;

  /// No description provided for @searchStatusIdle.
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos {min} letras o elige un país'**
  String searchStatusIdle(int min);

  /// No description provided for @searchStatusSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get searchStatusSearching;

  /// No description provided for @searchStatusResults.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 resultado} other{{n} resultados}}'**
  String searchStatusResults(int n);

  /// No description provided for @searchStatusNoCountryChannels.
  ///
  /// In es, this message translates to:
  /// **'Sin canales de este país'**
  String get searchStatusNoCountryChannels;

  /// No description provided for @searchStatusNoResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para \"{query}\"'**
  String searchStatusNoResults(String query);

  /// No description provided for @searchStatusError.
  ///
  /// In es, this message translates to:
  /// **'Error al buscar. Intenta de nuevo.'**
  String get searchStatusError;

  /// No description provided for @playlistNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva lista'**
  String get playlistNew;

  /// No description provided for @playlistCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get playlistCreate;

  /// No description provided for @playlistCreateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la lista'**
  String get playlistCreateFailed;

  /// No description provided for @playlistAddedTo.
  ///
  /// In es, this message translates to:
  /// **'Agregado a «{name}»'**
  String playlistAddedTo(String name);

  /// No description provided for @playlistAlreadyIn.
  ///
  /// In es, this message translates to:
  /// **'Ya está en «{name}»'**
  String playlistAlreadyIn(String name);

  /// No description provided for @playlistRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get playlistRename;

  /// No description provided for @playlistRenameFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo renombrar'**
  String get playlistRenameFailed;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la lista «{name}»?'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistAddChannelByUrl.
  ///
  /// In es, this message translates to:
  /// **'Agregar canal por URL'**
  String get playlistAddChannelByUrl;

  /// No description provided for @playlistChannelNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del canal'**
  String get playlistChannelNameLabel;

  /// No description provided for @playlistStreamUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'URL del stream'**
  String get playlistStreamUrlLabel;

  /// No description provided for @playlistAddChannelFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo agregar el canal'**
  String get playlistAddChannelFailed;

  /// No description provided for @playlistMoveUp.
  ///
  /// In es, this message translates to:
  /// **'Mover antes'**
  String get playlistMoveUp;

  /// No description provided for @playlistMoveDown.
  ///
  /// In es, this message translates to:
  /// **'Mover después'**
  String get playlistMoveDown;

  /// No description provided for @playlistRemoveFromList.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la lista'**
  String get playlistRemoveFromList;

  /// No description provided for @playlistDeleteChannel.
  ///
  /// In es, this message translates to:
  /// **'Eliminar canal'**
  String get playlistDeleteChannel;

  /// No description provided for @playlistChannelCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 canal} other{{n} canales}}'**
  String playlistChannelCount(int n);

  /// No description provided for @playlistEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primera lista con «Nueva lista».'**
  String get playlistEmptyFirst;

  /// No description provided for @playlistEmptyList.
  ///
  /// In es, this message translates to:
  /// **'Esta lista está vacía. Mantén OK sobre cualquier canal y elige «Agregar a una lista…».'**
  String get playlistEmptyList;

  /// No description provided for @keyboardDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get keyboardDone;

  /// No description provided for @keyboardSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get keyboardSearch;

  /// No description provided for @keyboardShift.
  ///
  /// In es, this message translates to:
  /// **'Mayús'**
  String get keyboardShift;

  /// No description provided for @keyboardSpace.
  ///
  /// In es, this message translates to:
  /// **'Espacio'**
  String get keyboardSpace;

  /// No description provided for @keyboardBackspace.
  ///
  /// In es, this message translates to:
  /// **'⌫ Borrar'**
  String get keyboardBackspace;

  /// No description provided for @keyboardClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get keyboardClear;

  /// No description provided for @keyboardSystem.
  ///
  /// In es, this message translates to:
  /// **'Voz / sistema'**
  String get keyboardSystem;

  /// No description provided for @guideToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get guideToday;

  /// No description provided for @guideTomorrow.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get guideTomorrow;

  /// No description provided for @guideWeekdaysShort.
  ///
  /// In es, this message translates to:
  /// **'lun|mar|mié|jue|vie|sáb|dom'**
  String get guideWeekdaysShort;

  /// No description provided for @guidePrevious.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get guidePrevious;

  /// No description provided for @guideNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get guideNext;

  /// No description provided for @guideNowBadge.
  ///
  /// In es, this message translates to:
  /// **'AHORA'**
  String get guideNowBadge;

  /// No description provided for @guideLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la guía'**
  String get guideLoadFailed;

  /// No description provided for @guideEmptyDay.
  ///
  /// In es, this message translates to:
  /// **'Sin programación para este día'**
  String get guideEmptyDay;

  /// No description provided for @playerSetCameraFirst.
  ///
  /// In es, this message translates to:
  /// **'Primero define la cámara en Ajustes'**
  String get playerSetCameraFirst;

  /// No description provided for @playerMenuAudio.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get playerMenuAudio;

  /// No description provided for @playerMenuSubtitles.
  ///
  /// In es, this message translates to:
  /// **'Subtítulos'**
  String get playerMenuSubtitles;

  /// No description provided for @playerMenuLast.
  ///
  /// In es, this message translates to:
  /// **'Volver al canal anterior'**
  String get playerMenuLast;

  /// No description provided for @playerMenuFit.
  ///
  /// In es, this message translates to:
  /// **'Ajustar imagen'**
  String get playerMenuFit;

  /// No description provided for @playerMenuToMpv.
  ///
  /// In es, this message translates to:
  /// **'Usar mpv en este canal (audio y subtítulos)'**
  String get playerMenuToMpv;

  /// No description provided for @playerMenuToExo.
  ///
  /// In es, this message translates to:
  /// **'Usar ExoPlayer en este canal'**
  String get playerMenuToExo;

  /// No description provided for @playerCamShow.
  ///
  /// In es, this message translates to:
  /// **'Mostrar cámara'**
  String get playerCamShow;

  /// No description provided for @playerCamHide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar cámara'**
  String get playerCamHide;

  /// No description provided for @playerCamInBox.
  ///
  /// In es, this message translates to:
  /// **'Cámara en el recuadro (canal en grande)'**
  String get playerCamInBox;

  /// No description provided for @playerCamFull.
  ///
  /// In es, this message translates to:
  /// **'Cámara en pantalla grande'**
  String get playerCamFull;

  /// No description provided for @playerCamZoom.
  ///
  /// In es, this message translates to:
  /// **'Zoom de la cámara'**
  String get playerCamZoom;

  /// No description provided for @playerCamRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar cámara'**
  String get playerCamRetry;

  /// No description provided for @playerLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get playerLoading;

  /// No description provided for @playerPaused.
  ///
  /// In es, this message translates to:
  /// **'Pausado'**
  String get playerPaused;

  /// No description provided for @playerLive.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get playerLive;

  /// No description provided for @playerKeyHintLive.
  ///
  /// In es, this message translates to:
  /// **'↑↓ Cambiar canal  ·  OK Info  ·  Mantén OK Opciones  ·  Atrás Salir'**
  String get playerKeyHintLive;

  /// No description provided for @playerKeyHintVod.
  ///
  /// In es, this message translates to:
  /// **'←→ 10 s  ·  OK Pausa  ·  Mantén OK Opciones  ·  Atrás Salir'**
  String get playerKeyHintVod;

  /// No description provided for @playerCamNoSignal.
  ///
  /// In es, this message translates to:
  /// **'Cámara sin señal'**
  String get playerCamNoSignal;

  /// No description provided for @playerZoomHint.
  ///
  /// In es, this message translates to:
  /// **'Zoom {zoom}  ·  ←↑↓→ Mover  ·  OK Cambiar zoom  ·  Atrás Terminar'**
  String playerZoomHint(String zoom);

  /// No description provided for @playerChannelNumber.
  ///
  /// In es, this message translates to:
  /// **'Canal {number}'**
  String playerChannelNumber(String number);

  /// No description provided for @playerGuideNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora: {title}'**
  String playerGuideNow(String title);

  /// No description provided for @playerErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir este canal'**
  String get playerErrorTitle;

  /// No description provided for @playerNextChannel.
  ///
  /// In es, this message translates to:
  /// **'Siguiente canal'**
  String get playerNextChannel;

  /// No description provided for @playerBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get playerBack;

  /// No description provided for @settingsAddFromIptvOrg.
  ///
  /// In es, this message translates to:
  /// **'Agregar desde iptv-org'**
  String get settingsAddFromIptvOrg;

  /// No description provided for @settingsAddM3u.
  ///
  /// In es, this message translates to:
  /// **'Agregar lista M3U por URL'**
  String get settingsAddM3u;

  /// No description provided for @settingsRefreshNow.
  ///
  /// In es, this message translates to:
  /// **'Actualizar listas ahora'**
  String get settingsRefreshNow;

  /// No description provided for @settingsAutoRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualización automática (cada 24 h)'**
  String get settingsAutoRefresh;

  /// No description provided for @settingsAutoOn.
  ///
  /// In es, this message translates to:
  /// **'Activada'**
  String get settingsAutoOn;

  /// No description provided for @settingsAutoOff.
  ///
  /// In es, this message translates to:
  /// **'Desactivada'**
  String get settingsAutoOff;

  /// No description provided for @settingsBuffer.
  ///
  /// In es, this message translates to:
  /// **'Buffer de reproducción'**
  String get settingsBuffer;

  /// No description provided for @settingsBufferHint.
  ///
  /// In es, this message translates to:
  /// **'Más segundos = menos tirones; empieza algo más tarde'**
  String get settingsBufferHint;

  /// No description provided for @settingsEngine.
  ///
  /// In es, this message translates to:
  /// **'Motor de video'**
  String get settingsEngine;

  /// No description provided for @settingsEngineAutoHint.
  ///
  /// In es, this message translates to:
  /// **'ExoPlayer y, si falla, mpv'**
  String get settingsEngineAutoHint;

  /// No description provided for @settingsEngineMpvHint.
  ///
  /// In es, this message translates to:
  /// **'Solo mpv (el más compatible)'**
  String get settingsEngineMpvHint;

  /// No description provided for @engineModeAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático'**
  String get engineModeAuto;

  /// No description provided for @engineModeMpv.
  ///
  /// In es, this message translates to:
  /// **'Solo mpv'**
  String get engineModeMpv;

  /// No description provided for @settingsDecoding.
  ///
  /// In es, this message translates to:
  /// **'Decodificación de video (mpv)'**
  String get settingsDecoding;

  /// No description provided for @settingsDecodingAutoHint.
  ///
  /// In es, this message translates to:
  /// **'Si un canal 1080p va a tirones con mpv, prueba \"Sin copia\"'**
  String get settingsDecodingAutoHint;

  /// No description provided for @settingsDecodingZeroCopyHint.
  ///
  /// In es, this message translates to:
  /// **'Experimental: sin copiar fotogramas; si no da imagen, vuelve a la automática'**
  String get settingsDecodingZeroCopyHint;

  /// No description provided for @settingsDecodingZeroCopy.
  ///
  /// In es, this message translates to:
  /// **'Sin copia'**
  String get settingsDecodingZeroCopy;

  /// No description provided for @settingsDecodingAuto.
  ///
  /// In es, this message translates to:
  /// **'Automática'**
  String get settingsDecodingAuto;

  /// No description provided for @settingsTextSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de letra'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeHint.
  ///
  /// In es, this message translates to:
  /// **'Agranda los textos de toda la interfaz'**
  String get settingsTextSizeHint;

  /// No description provided for @settingsHighContrast.
  ///
  /// In es, this message translates to:
  /// **'Alto contraste'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastHint.
  ///
  /// In es, this message translates to:
  /// **'Texto más claro y borde de foco amarillo más grueso'**
  String get settingsHighContrastHint;

  /// No description provided for @settingsHideDead.
  ///
  /// In es, this message translates to:
  /// **'Ocultar canales caídos'**
  String get settingsHideDead;

  /// No description provided for @settingsHideDeadHint.
  ///
  /// In es, this message translates to:
  /// **'En Canales y Búsqueda (Favoritos siempre los muestra)'**
  String get settingsHideDeadHint;

  /// No description provided for @settingsDeadChannels.
  ///
  /// In es, this message translates to:
  /// **'Canales caídos'**
  String get settingsDeadChannels;

  /// No description provided for @settingsDeadChannelsHint.
  ///
  /// In es, this message translates to:
  /// **'Se saltan al cambiar de canal. OK para limpiar las marcas'**
  String get settingsDeadChannelsHint;

  /// No description provided for @settingsDeadNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguno'**
  String get settingsDeadNone;

  /// No description provided for @settingsDeadCount.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 marcado} other{{n} marcados}}'**
  String settingsDeadCount(int n);

  /// No description provided for @settingsHideAdult.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contenido adulto'**
  String get settingsHideAdult;

  /// No description provided for @settingsHideAdultHintPin.
  ///
  /// In es, this message translates to:
  /// **'Desactivarlo exige el PIN'**
  String get settingsHideAdultHintPin;

  /// No description provided for @settingsHideAdultHintNoPin.
  ///
  /// In es, this message translates to:
  /// **'Crea un PIN para protegerlo'**
  String get settingsHideAdultHintNoPin;

  /// No description provided for @settingsPin.
  ///
  /// In es, this message translates to:
  /// **'PIN de control parental'**
  String get settingsPin;

  /// No description provided for @settingsPinHint.
  ///
  /// In es, this message translates to:
  /// **'De 4 dígitos; protege el filtro de adultos'**
  String get settingsPinHint;

  /// No description provided for @settingsPinSet.
  ///
  /// In es, this message translates to:
  /// **'Configurado'**
  String get settingsPinSet;

  /// No description provided for @settingsPinNone.
  ///
  /// In es, this message translates to:
  /// **'Sin PIN'**
  String get settingsPinNone;

  /// No description provided for @settingsBackup.
  ///
  /// In es, this message translates to:
  /// **'Copia de seguridad'**
  String get settingsBackup;

  /// No description provided for @settingsBackupHint.
  ///
  /// In es, this message translates to:
  /// **'Exporta o importa favoritos, listas propias y ajustes'**
  String get settingsBackupHint;

  /// No description provided for @settingsEpg.
  ///
  /// In es, this message translates to:
  /// **'Guía personalizada (XMLTV)'**
  String get settingsEpg;

  /// No description provided for @settingsEpgHint.
  ///
  /// In es, this message translates to:
  /// **'Más canales con guía; se suma a la de tus países'**
  String get settingsEpgHint;

  /// No description provided for @settingsEpgSet.
  ///
  /// In es, this message translates to:
  /// **'Definida'**
  String get settingsEpgSet;

  /// No description provided for @settingsEpgUnset.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get settingsEpgUnset;

  /// No description provided for @settingsCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara de seguridad'**
  String get settingsCamera;

  /// No description provided for @settingsCameraHint.
  ///
  /// In es, this message translates to:
  /// **'Se ve como canal y en un recuadro (mantén OK en un canal)'**
  String get settingsCameraHint;

  /// No description provided for @settingsCameraSet.
  ///
  /// In es, this message translates to:
  /// **'Configurada'**
  String get settingsCameraSet;

  /// No description provided for @settingsCameraUnset.
  ///
  /// In es, this message translates to:
  /// **'Sin cámara'**
  String get settingsCameraUnset;

  /// No description provided for @settingsLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la interfaz de TV'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In es, this message translates to:
  /// **'Automático (sistema)'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsMySources.
  ///
  /// In es, this message translates to:
  /// **'Mis fuentes'**
  String get settingsMySources;

  /// No description provided for @settingsAlreadyRefreshing.
  ///
  /// In es, this message translates to:
  /// **'Ya se están actualizando las listas'**
  String get settingsAlreadyRefreshing;

  /// No description provided for @settingsRefreshing.
  ///
  /// In es, this message translates to:
  /// **'Actualizando listas…'**
  String get settingsRefreshing;

  /// No description provided for @settingsRefreshFailedSome.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 lista no se pudo actualizar} other{{n} listas no se pudieron actualizar}}'**
  String settingsRefreshFailedSome(int n);

  /// No description provided for @settingsRefreshDone.
  ///
  /// In es, this message translates to:
  /// **'Listas actualizadas'**
  String get settingsRefreshDone;

  /// No description provided for @settingsRefreshFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar las listas'**
  String get settingsRefreshFailed;

  /// No description provided for @pinWrong.
  ///
  /// In es, this message translates to:
  /// **'PIN incorrecto'**
  String get pinWrong;

  /// No description provided for @pinNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo PIN'**
  String get pinNew;

  /// No description provided for @pinRepeat.
  ///
  /// In es, this message translates to:
  /// **'Repite el PIN'**
  String get pinRepeat;

  /// No description provided for @pinMismatch.
  ///
  /// In es, this message translates to:
  /// **'Los PIN no coinciden'**
  String get pinMismatch;

  /// No description provided for @pinEnter.
  ///
  /// In es, this message translates to:
  /// **'Introduce el PIN'**
  String get pinEnter;

  /// No description provided for @pinEnterCurrent.
  ///
  /// In es, this message translates to:
  /// **'Introduce el PIN actual'**
  String get pinEnterCurrent;

  /// No description provided for @pinSaved.
  ///
  /// In es, this message translates to:
  /// **'PIN guardado'**
  String get pinSaved;

  /// No description provided for @pinRemoved.
  ///
  /// In es, this message translates to:
  /// **'PIN quitado'**
  String get pinRemoved;

  /// No description provided for @pinChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar PIN'**
  String get pinChange;

  /// No description provided for @pinRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar PIN'**
  String get pinRemove;

  /// No description provided for @backupExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar copia'**
  String get backupExport;

  /// No description provided for @backupImportMenu.
  ///
  /// In es, this message translates to:
  /// **'Importar copia…'**
  String get backupImportMenu;

  /// No description provided for @backupSavedTo.
  ///
  /// In es, this message translates to:
  /// **'Copia guardada en {path}'**
  String backupSavedTo(String path);

  /// No description provided for @backupSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la copia'**
  String get backupSaveFailed;

  /// No description provided for @backupImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar copia'**
  String get backupImportTitle;

  /// No description provided for @backupFromUrl.
  ///
  /// In es, this message translates to:
  /// **'Desde una URL…'**
  String get backupFromUrl;

  /// No description provided for @backupFromPicker.
  ///
  /// In es, this message translates to:
  /// **'Desde un archivo del dispositivo…'**
  String get backupFromPicker;

  /// No description provided for @backupImportFromUrlTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar desde una URL'**
  String get backupImportFromUrlTitle;

  /// No description provided for @backupUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección de la copia (.json)'**
  String get backupUrlLabel;

  /// No description provided for @backupImportConfirm.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get backupImportConfirm;

  /// No description provided for @backupNoFile.
  ///
  /// In es, this message translates to:
  /// **'No se eligió ningún archivo'**
  String get backupNoFile;

  /// No description provided for @backupImporting.
  ///
  /// In es, this message translates to:
  /// **'Importando…'**
  String get backupImporting;

  /// No description provided for @backupImported.
  ///
  /// In es, this message translates to:
  /// **'Copia importada: {summary}'**
  String backupImported(String summary);

  /// No description provided for @backupImportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar la copia'**
  String get backupImportFailed;

  /// No description provided for @backupSummaryLists.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 lista} other{{n} listas}}'**
  String backupSummaryLists(int n);

  /// No description provided for @backupSummaryFavorites.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 favorito} other{{n} favoritos}}'**
  String backupSummaryFavorites(int n);

  /// No description provided for @backupSummaryPlaylists.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 lista propia nueva} other{{n} listas propias nuevas}}'**
  String backupSummaryPlaylists(int n);

  /// No description provided for @backupSummaryPlaylistItems.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 canal en listas} other{{n} canales en listas}}'**
  String backupSummaryPlaylistItems(int n);

  /// No description provided for @backupSummaryCustom.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 canal propio} other{{n} canales propios}}'**
  String backupSummaryCustom(int n);

  /// No description provided for @backupSummarySettings.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, =1{1 ajuste} other{{n} ajustes}}'**
  String backupSummarySettings(int n);

  /// No description provided for @backupSummaryNothing.
  ///
  /// In es, this message translates to:
  /// **'Nada nuevo que importar'**
  String get backupSummaryNothing;

  /// No description provided for @backupSummaryMissing.
  ///
  /// In es, this message translates to:
  /// **'{base} ({n, plural, =1{1 favorito sin canal} other{{n} favoritos sin canal}})'**
  String backupSummaryMissing(String base, int n);

  /// No description provided for @backupErrInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'La dirección no es válida'**
  String get backupErrInvalidUrl;

  /// No description provided for @backupErrDownload.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar (HTTP {code})'**
  String backupErrDownload(int code);

  /// No description provided for @backupErrNotBackup.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es una copia válida'**
  String get backupErrNotBackup;

  /// No description provided for @backupErrNotFred.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es una copia de Fred TV'**
  String get backupErrNotFred;

  /// No description provided for @backupErrNoVersion.
  ///
  /// In es, this message translates to:
  /// **'La copia no indica su versión'**
  String get backupErrNoVersion;

  /// No description provided for @backupErrNewer.
  ///
  /// In es, this message translates to:
  /// **'La copia es de una versión más nueva de la app'**
  String get backupErrNewer;

  /// No description provided for @epgUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección (.xml o .xml.gz); vacío para quitarla'**
  String get epgUrlLabel;

  /// No description provided for @cameraUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección RTSP; vacío para quitarla'**
  String get cameraUrlLabel;

  /// No description provided for @cameraRemoved.
  ///
  /// In es, this message translates to:
  /// **'Cámara quitada'**
  String get cameraRemoved;

  /// No description provided for @cameraSaved.
  ///
  /// In es, this message translates to:
  /// **'Cámara guardada: búscala como canal «{name}» en Favoritos'**
  String cameraSaved(String name);

  /// No description provided for @deadClearConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Limpiar las marcas de canales caídos?'**
  String get deadClearConfirm;

  /// No description provided for @deadClearAction.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get deadClearAction;

  /// No description provided for @sourceRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get sourceRefresh;

  /// No description provided for @sourceDisable.
  ///
  /// In es, this message translates to:
  /// **'Desactivar'**
  String get sourceDisable;

  /// No description provided for @sourceEnable.
  ///
  /// In es, this message translates to:
  /// **'Activar'**
  String get sourceEnable;

  /// No description provided for @sourceDeleteConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la fuente «{name}» y sus canales?'**
  String sourceDeleteConfirm(String name);

  /// No description provided for @sourceDisabled.
  ///
  /// In es, this message translates to:
  /// **'Desactivada'**
  String get sourceDisabled;

  /// No description provided for @sourceNeverRefreshed.
  ///
  /// In es, this message translates to:
  /// **'Nunca actualizada'**
  String get sourceNeverRefreshed;

  /// No description provided for @sourceRefreshedAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizada {ago}'**
  String sourceRefreshedAgo(String ago);

  /// No description provided for @playlistNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la lista'**
  String get playlistNameLabel;

  /// No description provided for @playlistDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una lista con ese nombre'**
  String get playlistDuplicate;

  /// No description provided for @addM3uTitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar lista M3U'**
  String get addM3uTitle;

  /// No description provided for @addM3uUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'URL de la lista M3U'**
  String get addM3uUrlLabel;

  /// No description provided for @addM3uButton.
  ///
  /// In es, this message translates to:
  /// **'Agregar lista'**
  String get addM3uButton;

  /// No description provided for @addM3uFillAll.
  ///
  /// In es, this message translates to:
  /// **'Completa todos los campos'**
  String get addM3uFillAll;

  /// No description provided for @addM3uAdding.
  ///
  /// In es, this message translates to:
  /// **'Agregando lista…'**
  String get addM3uAdding;

  /// No description provided for @addM3uAdded.
  ///
  /// In es, this message translates to:
  /// **'Lista agregada correctamente'**
  String get addM3uAdded;

  /// No description provided for @urlMustBeHttp.
  ///
  /// In es, this message translates to:
  /// **'La URL debe empezar con http:// o https://'**
  String get urlMustBeHttp;

  /// No description provided for @sourceErrUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta lista no está disponible'**
  String get sourceErrUnavailable;

  /// No description provided for @sourceErrGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo agregar la lista'**
  String get sourceErrGeneric;

  /// No description provided for @iptvTitle.
  ///
  /// In es, this message translates to:
  /// **'Listas de iptv-org'**
  String get iptvTitle;

  /// No description provided for @iptvSectionRecommended.
  ///
  /// In es, this message translates to:
  /// **'Recomendados'**
  String get iptvSectionRecommended;

  /// No description provided for @iptvSectionCountries.
  ///
  /// In es, this message translates to:
  /// **'Países'**
  String get iptvSectionCountries;

  /// No description provided for @iptvSectionCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get iptvSectionCategories;

  /// No description provided for @iptvAlreadyAdded.
  ///
  /// In es, this message translates to:
  /// **'Ya agregada'**
  String get iptvAlreadyAdded;

  /// No description provided for @iptvAdding.
  ///
  /// In es, this message translates to:
  /// **'Agregando «{name}»…'**
  String iptvAdding(String name);

  /// No description provided for @iptvAdded.
  ///
  /// In es, this message translates to:
  /// **'«{name}» agregada'**
  String iptvAdded(String name);

  /// No description provided for @iptvLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el catálogo. Revisa tu conexión.'**
  String get iptvLoadFailed;

  /// No description provided for @iptvKindLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get iptvKindLanguage;

  /// No description provided for @iptvAddedBadge.
  ///
  /// In es, this message translates to:
  /// **'Agregada'**
  String get iptvAddedBadge;

  /// No description provided for @iptvAllSpanish.
  ///
  /// In es, this message translates to:
  /// **'Todo en español'**
  String get iptvAllSpanish;

  /// No description provided for @iptvCatNews.
  ///
  /// In es, this message translates to:
  /// **'Noticias'**
  String get iptvCatNews;

  /// No description provided for @iptvCatSports.
  ///
  /// In es, this message translates to:
  /// **'Deportes'**
  String get iptvCatSports;

  /// No description provided for @iptvCatKids.
  ///
  /// In es, this message translates to:
  /// **'Infantil'**
  String get iptvCatKids;

  /// No description provided for @iptvCatMovies.
  ///
  /// In es, this message translates to:
  /// **'Películas'**
  String get iptvCatMovies;

  /// No description provided for @iptvCatMusic.
  ///
  /// In es, this message translates to:
  /// **'Música'**
  String get iptvCatMusic;

  /// No description provided for @iptvCatDocumentary.
  ///
  /// In es, this message translates to:
  /// **'Documentales'**
  String get iptvCatDocumentary;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'pt'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

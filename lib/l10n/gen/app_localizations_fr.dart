// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonPlay => 'Lire';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get navChannels => 'Chaînes';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navMyLists => 'Mes listes';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navSettings => 'Réglages';

  @override
  String get linkChannelUnavailable => 'Cette chaîne n\'est plus disponible';

  @override
  String get channelUnavailable => 'Cette chaîne n\'est plus disponible';

  @override
  String get bootstrapPreparing => 'Préparation des chaînes…';

  @override
  String get bootstrapFailed =>
      'Impossible de télécharger la liste des chaînes';

  @override
  String get agoMoment => 'à l\'instant';

  @override
  String agoMinutes(int n) {
    return 'il y a $n min';
  }

  @override
  String agoHours(int n) {
    return 'il y a $n h';
  }

  @override
  String agoDays(int n) {
    return 'il y a $n j';
  }

  @override
  String get browserAllChannels => 'Toutes les chaînes';

  @override
  String get browserRecents => 'Récentes';

  @override
  String get browserFooterHint => 'OK Lire  ·  Maintenir OK Options  ·  ← Menu';

  @override
  String get browserEmptyFavorites =>
      'Vous n\'avez pas encore de favoris. Maintenez OK sur une chaîne pour l\'ajouter.';

  @override
  String get browserEmptyGroup => 'Aucune chaîne dans ce groupe';

  @override
  String get favoriteAdded => 'Ajouté aux favoris';

  @override
  String get favoriteRemoved => 'Retiré des favoris';

  @override
  String get deadMarkRemoved => 'Marque retirée';

  @override
  String get deadMarked => 'Marquée comme hors service';

  @override
  String get menuFavoriteAdd => 'Ajouter aux favoris';

  @override
  String get menuFavoriteRemove => 'Retirer des favoris';

  @override
  String get menuAddToList => 'Ajouter à une liste…';

  @override
  String get menuShowGuide => 'Voir le programme';

  @override
  String get menuDeadClear => 'Retirer la marque hors service';

  @override
  String get menuDeadMark => 'Marquer comme hors service';

  @override
  String get searchUpdateListsForCountries =>
      'Mettez à jour les listes pour voir les pays';

  @override
  String get searchCountryTitle => 'Pays';

  @override
  String get searchAllCountries => 'Tous les pays';

  @override
  String get searchCountryAllShort => 'Tous';

  @override
  String searchCountryChip(String value) {
    return 'Pays : $value';
  }

  @override
  String get searchLabel => 'Rechercher des chaînes';

  @override
  String get searchHint => 'Appuyez sur OK pour saisir';

  @override
  String searchStatusIdle(int min) {
    return 'Saisissez au moins $min lettres ou choisissez un pays';
  }

  @override
  String get searchStatusSearching => 'Recherche en cours…';

  @override
  String searchStatusResults(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n résultats',
      one: '1 résultat',
    );
    return '$_temp0';
  }

  @override
  String get searchStatusNoCountryChannels => 'Aucune chaîne de ce pays';

  @override
  String searchStatusNoResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get searchStatusError => 'Erreur de recherche. Réessayez.';

  @override
  String get playlistNew => 'Nouvelle liste';

  @override
  String get playlistCreate => 'Créer';

  @override
  String get playlistCreateFailed => 'Impossible de créer la liste';

  @override
  String playlistAddedTo(String name) {
    return 'Ajouté à « $name »';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Déjà dans « $name »';
  }

  @override
  String get playlistRename => 'Renommer';

  @override
  String get playlistRenameFailed => 'Impossible de renommer';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Supprimer la liste « $name » ?';
  }

  @override
  String get playlistAddChannelByUrl => 'Ajouter une chaîne par URL';

  @override
  String get playlistChannelNameLabel => 'Nom de la chaîne';

  @override
  String get playlistStreamUrlLabel => 'URL du flux';

  @override
  String get playlistAddChannelFailed => 'Impossible d\'ajouter la chaîne';

  @override
  String get playlistMoveUp => 'Déplacer avant';

  @override
  String get playlistMoveDown => 'Déplacer après';

  @override
  String get playlistRemoveFromList => 'Retirer de la liste';

  @override
  String get playlistDeleteChannel => 'Supprimer la chaîne';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n chaînes',
      one: '1 chaîne',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst =>
      'Créez votre première liste avec « Nouvelle liste ».';

  @override
  String get playlistEmptyList =>
      'Cette liste est vide. Maintenez OK sur une chaîne et choisissez « Ajouter à une liste… ».';

  @override
  String get keyboardDone => 'Terminé';

  @override
  String get keyboardSearch => 'Rechercher';

  @override
  String get keyboardShift => 'Maj';

  @override
  String get keyboardSpace => 'Espace';

  @override
  String get keyboardBackspace => '⌫ Effacer';

  @override
  String get keyboardClear => 'Vider';

  @override
  String get keyboardSystem => 'Voix / système';

  @override
  String get guideToday => 'Aujourd\'hui';

  @override
  String get guideTomorrow => 'Demain';

  @override
  String get guideWeekdaysShort => 'lun|mar|mer|jeu|ven|sam|dim';

  @override
  String get guidePrevious => 'Précédent';

  @override
  String get guideNext => 'Suivant';

  @override
  String get guideNowBadge => 'EN COURS';

  @override
  String get guideLoadFailed => 'Impossible de charger le guide';

  @override
  String get guideEmptyDay => 'Aucun programme pour ce jour';

  @override
  String get playerSetCameraFirst =>
      'Définissez d\'abord la caméra dans les Réglages';

  @override
  String get playerMenuAudio => 'Audio';

  @override
  String get playerMenuSubtitles => 'Sous-titres';

  @override
  String get playerMenuLast => 'Revenir à la chaîne précédente';

  @override
  String get playerMenuFit => 'Ajuster l\'image';

  @override
  String get playerMenuToMpv =>
      'Utiliser mpv sur cette chaîne (audio et sous-titres)';

  @override
  String get playerMenuToExo => 'Utiliser ExoPlayer sur cette chaîne';

  @override
  String get playerCamShow => 'Afficher la caméra';

  @override
  String get playerCamHide => 'Masquer la caméra';

  @override
  String get playerCamInBox => 'Caméra dans le cadre (chaîne en grand)';

  @override
  String get playerCamFull => 'Caméra en plein écran';

  @override
  String get playerCamZoom => 'Zoom de la caméra';

  @override
  String get playerCamRetry => 'Réessayer la caméra';

  @override
  String get playerLoading => 'Chargement…';

  @override
  String get playerPaused => 'En pause';

  @override
  String get playerLive => 'En direct';

  @override
  String get playerKeyHintLive =>
      '↑↓ Changer de chaîne  ·  OK Infos  ·  Maintenir OK Options  ·  Retour Quitter';

  @override
  String get playerKeyHintVod =>
      '←→ 10 s  ·  OK Pause  ·  Maintenir OK Options  ·  Retour Quitter';

  @override
  String get playerCamNoSignal => 'Caméra sans signal';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Déplacer  ·  OK Changer le zoom  ·  Retour Terminer';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Chaîne $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Maintenant : $title';
  }

  @override
  String get playerErrorTitle => 'Impossible de lire cette chaîne';

  @override
  String get playerNextChannel => 'Chaîne suivante';

  @override
  String get playerBack => 'Retour';

  @override
  String get settingsAddFromIptvOrg => 'Ajouter depuis iptv-org';

  @override
  String get settingsAddM3u => 'Ajouter une liste M3U par URL';

  @override
  String get settingsRefreshNow => 'Actualiser les listes maintenant';

  @override
  String get settingsAutoRefresh =>
      'Actualisation automatique (toutes les 24 h)';

  @override
  String get settingsAutoOn => 'Activée';

  @override
  String get settingsAutoOff => 'Désactivée';

  @override
  String get settingsBuffer => 'Mémoire tampon de lecture';

  @override
  String get settingsBufferHint =>
      'Plus de secondes = moins de saccades ; démarre un peu plus tard';

  @override
  String get settingsEngine => 'Moteur vidéo';

  @override
  String get settingsEngineAutoHint => 'ExoPlayer puis, en cas d\'échec, mpv';

  @override
  String get settingsEngineMpvHint => 'mpv uniquement (le plus compatible)';

  @override
  String get engineModeAuto => 'Automatique';

  @override
  String get engineModeMpv => 'mpv uniquement';

  @override
  String get settingsDecoding => 'Décodage vidéo (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'Si une chaîne 1080p saccade avec mpv, essayez « Sans copie »';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Expérimental : sans copie des images ; sans image, retour au mode automatique';

  @override
  String get settingsDecodingZeroCopy => 'Sans copie';

  @override
  String get settingsDecodingAuto => 'Automatique';

  @override
  String get settingsTextSize => 'Taille du texte';

  @override
  String get settingsTextSizeHint =>
      'Agrandit les textes de toute l\'interface';

  @override
  String get settingsHighContrast => 'Contraste élevé';

  @override
  String get settingsHighContrastHint =>
      'Texte plus clair et bordure de focus jaune plus épaisse';

  @override
  String get settingsHideDead => 'Masquer les chaînes hors service';

  @override
  String get settingsHideDeadHint =>
      'Dans Chaînes et Recherche (Favoris les affiche toujours)';

  @override
  String get settingsDeadChannels => 'Chaînes hors service';

  @override
  String get settingsDeadChannelsHint =>
      'Elles sont ignorées lors du changement de chaîne. OK pour effacer les marques';

  @override
  String get settingsDeadNone => 'Aucune';

  @override
  String settingsDeadCount(int n) {
    return '$n marquées';
  }

  @override
  String get settingsHideAdult => 'Masquer le contenu adulte';

  @override
  String get settingsHideAdultHintPin => 'La désactivation exige le code PIN';

  @override
  String get settingsHideAdultHintNoPin => 'Créez un code PIN pour le protéger';

  @override
  String get settingsPin => 'Code PIN du contrôle parental';

  @override
  String get settingsPinHint => '4 chiffres ; protège le filtre adulte';

  @override
  String get settingsPinSet => 'Défini';

  @override
  String get settingsPinNone => 'Aucun PIN';

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get settingsBackupHint =>
      'Exportez ou importez les favoris, vos listes et les réglages';

  @override
  String get settingsEpg => 'Guide personnalisé (XMLTV)';

  @override
  String get settingsEpgHint =>
      'Plus de chaînes avec guide ; s\'ajoute à celui de vos pays';

  @override
  String get settingsEpgSet => 'Définie';

  @override
  String get settingsEpgUnset => 'Non définie';

  @override
  String get settingsCamera => 'Caméra de sécurité';

  @override
  String get settingsCameraHint =>
      'S\'affiche comme chaîne et dans un cadre (maintenez OK sur une chaîne)';

  @override
  String get settingsCameraSet => 'Configurée';

  @override
  String get settingsCameraUnset => 'Aucune caméra';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageHint => 'Langue de l\'interface TV';

  @override
  String get settingsLanguageAuto => 'Automatique (système)';

  @override
  String get settingsMySources => 'Mes sources';

  @override
  String get settingsAlreadyRefreshing =>
      'Les listes sont déjà en cours d\'actualisation';

  @override
  String get settingsRefreshing => 'Actualisation des listes…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listes n\'ont pas pu être actualisées',
      one: '1 liste n\'a pas pu être actualisée',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Listes actualisées';

  @override
  String get settingsRefreshFailed => 'Impossible d\'actualiser les listes';

  @override
  String get pinWrong => 'Code PIN incorrect';

  @override
  String get pinNew => 'Nouveau code PIN';

  @override
  String get pinRepeat => 'Répétez le code PIN';

  @override
  String get pinMismatch => 'Les codes PIN ne correspondent pas';

  @override
  String get pinEnter => 'Saisissez le code PIN';

  @override
  String get pinEnterCurrent => 'Saisissez le code PIN actuel';

  @override
  String get pinSaved => 'Code PIN enregistré';

  @override
  String get pinRemoved => 'Code PIN supprimé';

  @override
  String get pinChange => 'Changer le code PIN';

  @override
  String get pinRemove => 'Supprimer le code PIN';

  @override
  String get backupExport => 'Exporter la sauvegarde';

  @override
  String get backupImportMenu => 'Importer une sauvegarde…';

  @override
  String backupSavedTo(String path) {
    return 'Sauvegarde enregistrée dans $path';
  }

  @override
  String get backupSaveFailed => 'Impossible d\'enregistrer la sauvegarde';

  @override
  String get backupImportTitle => 'Importer une sauvegarde';

  @override
  String get backupFromUrl => 'Depuis une URL…';

  @override
  String get backupFromPicker => 'Depuis un fichier de l\'appareil…';

  @override
  String get backupImportFromUrlTitle => 'Importer depuis une URL';

  @override
  String get backupUrlLabel => 'Adresse de la sauvegarde (.json)';

  @override
  String get backupImportConfirm => 'Importer';

  @override
  String get backupNoFile => 'Aucun fichier n\'a été choisi';

  @override
  String get backupImporting => 'Importation…';

  @override
  String backupImported(String summary) {
    return 'Sauvegarde importée : $summary';
  }

  @override
  String get backupImportFailed => 'Impossible d\'importer la sauvegarde';

  @override
  String backupSummaryLists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listes',
      one: '1 liste',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryFavorites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favoris',
      one: '1 favori',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nouvelles listes perso',
      one: '1 nouvelle liste perso',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n chaînes dans les listes',
      one: '1 chaîne dans les listes',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n chaînes perso',
      one: '1 chaîne perso',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n réglages',
      one: '1 réglage',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Rien de nouveau à importer';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favoris sans chaîne',
      one: '1 favori sans chaîne',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'L\'adresse n\'est pas valide';

  @override
  String backupErrDownload(int code) {
    return 'Téléchargement impossible (HTTP $code)';
  }

  @override
  String get backupErrNotBackup =>
      'Le fichier n\'est pas une sauvegarde valide';

  @override
  String get backupErrNotFred =>
      'Le fichier n\'est pas une sauvegarde de Fred TV';

  @override
  String get backupErrNoVersion => 'La sauvegarde n\'indique pas sa version';

  @override
  String get backupErrNewer =>
      'La sauvegarde provient d\'une version plus récente de l\'application';

  @override
  String get epgUrlLabel =>
      'Adresse (.xml ou .xml.gz) ; vide pour la supprimer';

  @override
  String get cameraUrlLabel => 'Adresse RTSP ; vide pour la supprimer';

  @override
  String get cameraRemoved => 'Caméra supprimée';

  @override
  String cameraSaved(String name) {
    return 'Caméra enregistrée : retrouvez-la comme chaîne « $name » dans Favoris';
  }

  @override
  String get deadClearConfirm =>
      'Effacer les marques des chaînes hors service ?';

  @override
  String get deadClearAction => 'Effacer';

  @override
  String get sourceRefresh => 'Actualiser';

  @override
  String get sourceDisable => 'Désactiver';

  @override
  String get sourceEnable => 'Activer';

  @override
  String sourceDeleteConfirm(String name) {
    return 'Supprimer la source « $name » et ses chaînes ?';
  }

  @override
  String get sourceDisabled => 'Désactivée';

  @override
  String get sourceNeverRefreshed => 'Jamais actualisée';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Actualisée $ago';
  }

  @override
  String get playlistNameLabel => 'Nom de la liste';

  @override
  String get playlistDuplicate => 'Une liste porte déjà ce nom';

  @override
  String get addM3uTitle => 'Ajouter une liste M3U';

  @override
  String get addM3uUrlLabel => 'URL de la liste M3U';

  @override
  String get addM3uButton => 'Ajouter la liste';

  @override
  String get addM3uFillAll => 'Remplissez tous les champs';

  @override
  String get addM3uAdding => 'Ajout de la liste…';

  @override
  String get addM3uAdded => 'Liste ajoutée avec succès';

  @override
  String get urlMustBeHttp => 'L\'URL doit commencer par http:// ou https://';

  @override
  String get sourceErrUnavailable => 'Cette liste n\'est pas disponible';

  @override
  String get sourceErrGeneric => 'Impossible d\'ajouter la liste';

  @override
  String get iptvTitle => 'Listes iptv-org';

  @override
  String get iptvSectionRecommended => 'Recommandées';

  @override
  String get iptvSectionCountries => 'Pays';

  @override
  String get iptvSectionCategories => 'Catégories';

  @override
  String get iptvAlreadyAdded => 'Déjà ajoutée';

  @override
  String iptvAdding(String name) {
    return 'Ajout de « $name »…';
  }

  @override
  String iptvAdded(String name) {
    return '« $name » ajoutée';
  }

  @override
  String get iptvLoadFailed =>
      'Impossible de charger le catalogue. Vérifiez votre connexion.';

  @override
  String get iptvKindLanguage => 'Langue';

  @override
  String get iptvAddedBadge => 'Ajoutée';

  @override
  String get iptvAllSpanish => 'Tout en espagnol';

  @override
  String get iptvCatNews => 'Actualités';

  @override
  String get iptvCatSports => 'Sports';

  @override
  String get iptvCatKids => 'Jeunesse';

  @override
  String get iptvCatMovies => 'Films';

  @override
  String get iptvCatMusic => 'Musique';

  @override
  String get iptvCatDocumentary => 'Documentaires';
}

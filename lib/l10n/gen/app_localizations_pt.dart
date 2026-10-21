// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonPlay => 'Reproduzir';

  @override
  String get commonOn => 'Ativado';

  @override
  String get commonOff => 'Desativado';

  @override
  String get navChannels => 'Canais';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navMyLists => 'Minhas listas';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navSettings => 'Configurações';

  @override
  String get linkChannelUnavailable => 'Esse canal não está mais disponível';

  @override
  String get channelUnavailable => 'Este canal não está mais disponível';

  @override
  String get bootstrapPreparing => 'Preparando canais…';

  @override
  String get bootstrapFailed => 'Não foi possível baixar a lista de canais';

  @override
  String get agoMoment => 'agora mesmo';

  @override
  String agoMinutes(int n) {
    return 'há $n min';
  }

  @override
  String agoHours(int n) {
    return 'há $n h';
  }

  @override
  String agoDays(int n) {
    return 'há $n d';
  }

  @override
  String get browserAllChannels => 'Todos os canais';

  @override
  String get browserRecents => 'Recentes';

  @override
  String get browserFooterHint =>
      'OK Reproduzir  ·  Segure OK Opções  ·  ← Menu';

  @override
  String get browserEmptyFavorites =>
      'Você ainda não tem favoritos. Segure OK sobre um canal para adicioná-lo.';

  @override
  String get browserEmptyGroup => 'Não há canais neste grupo';

  @override
  String get favoriteAdded => 'Adicionado aos favoritos';

  @override
  String get favoriteRemoved => 'Removido dos favoritos';

  @override
  String get deadMarkRemoved => 'Marca removida';

  @override
  String get deadMarked => 'Marcado como fora do ar';

  @override
  String get menuFavoriteAdd => 'Adicionar aos favoritos';

  @override
  String get menuFavoriteRemove => 'Remover dos favoritos';

  @override
  String get menuAddToList => 'Adicionar a uma lista…';

  @override
  String get menuShowGuide => 'Ver programação';

  @override
  String get menuDeadClear => 'Remover marca de fora do ar';

  @override
  String get menuDeadMark => 'Marcar como fora do ar';

  @override
  String get searchUpdateListsForCountries =>
      'Atualize as listas para ver os países';

  @override
  String get searchCountryTitle => 'País';

  @override
  String get searchAllCountries => 'Todos os países';

  @override
  String get searchCountryAllShort => 'Todos';

  @override
  String searchCountryChip(String value) {
    return 'País: $value';
  }

  @override
  String get searchLabel => 'Buscar canais';

  @override
  String get searchHint => 'Pressione OK para digitar';

  @override
  String searchStatusIdle(int min) {
    return 'Digite pelo menos $min letras ou escolha um país';
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
  String get searchStatusNoCountryChannels => 'Sem canais deste país';

  @override
  String searchStatusNoResults(String query) {
    return 'Sem resultados para \"$query\"';
  }

  @override
  String get searchStatusError => 'Erro na busca. Tente novamente.';

  @override
  String get playlistNew => 'Nova lista';

  @override
  String get playlistCreate => 'Criar';

  @override
  String get playlistCreateFailed => 'Não foi possível criar a lista';

  @override
  String playlistAddedTo(String name) {
    return 'Adicionado a \"$name\"';
  }

  @override
  String playlistAlreadyIn(String name) {
    return 'Já está em \"$name\"';
  }

  @override
  String get playlistRename => 'Renomear';

  @override
  String get playlistRenameFailed => 'Não foi possível renomear';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Excluir a lista \"$name\"?';
  }

  @override
  String get playlistAddChannelByUrl => 'Adicionar canal por URL';

  @override
  String get playlistChannelNameLabel => 'Nome do canal';

  @override
  String get playlistStreamUrlLabel => 'URL do stream';

  @override
  String get playlistAddChannelFailed => 'Não foi possível adicionar o canal';

  @override
  String get playlistMoveUp => 'Mover para antes';

  @override
  String get playlistMoveDown => 'Mover para depois';

  @override
  String get playlistRemoveFromList => 'Remover da lista';

  @override
  String get playlistDeleteChannel => 'Excluir canal';

  @override
  String playlistChannelCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canais',
      one: '1 canal',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyFirst =>
      'Crie sua primeira lista com \"Nova lista\".';

  @override
  String get playlistEmptyList =>
      'Esta lista está vazia. Segure OK sobre qualquer canal e escolha \"Adicionar a uma lista…\".';

  @override
  String get keyboardDone => 'Pronto';

  @override
  String get keyboardSearch => 'Buscar';

  @override
  String get keyboardShift => 'Maiús';

  @override
  String get keyboardSpace => 'Espaço';

  @override
  String get keyboardBackspace => '⌫ Apagar';

  @override
  String get keyboardClear => 'Limpar';

  @override
  String get keyboardSystem => 'Voz / sistema';

  @override
  String get guideToday => 'Hoje';

  @override
  String get guideTomorrow => 'Amanhã';

  @override
  String get guideWeekdaysShort => 'seg|ter|qua|qui|sex|sáb|dom';

  @override
  String get guidePrevious => 'Anterior';

  @override
  String get guideNext => 'Seguinte';

  @override
  String get guideNowBadge => 'AGORA';

  @override
  String get guideLoadFailed => 'Não foi possível carregar o guia';

  @override
  String get guideEmptyDay => 'Sem programação para este dia';

  @override
  String get playerSetCameraFirst =>
      'Primeiro defina a câmera em Configurações';

  @override
  String get playerMenuAudio => 'Áudio';

  @override
  String get playerMenuSubtitles => 'Legendas';

  @override
  String get playerMenuLast => 'Voltar ao canal anterior';

  @override
  String get playerMenuFit => 'Ajustar imagem';

  @override
  String get playerMenuToMpv => 'Usar mpv neste canal (áudio e legendas)';

  @override
  String get playerMenuToExo => 'Usar ExoPlayer neste canal';

  @override
  String get playerCamShow => 'Mostrar câmera';

  @override
  String get playerCamHide => 'Ocultar câmera';

  @override
  String get playerCamInBox => 'Câmera no quadro (canal em tela cheia)';

  @override
  String get playerCamFull => 'Câmera em tela cheia';

  @override
  String get playerCamZoom => 'Zoom da câmera';

  @override
  String get playerCamRetry => 'Tentar a câmera novamente';

  @override
  String get playerLoading => 'Carregando…';

  @override
  String get playerPaused => 'Pausado';

  @override
  String get playerLive => 'Ao vivo';

  @override
  String get playerKeyHintLive =>
      '↑↓ Trocar canal  ·  OK Info  ·  Segure OK Opções  ·  Voltar Sair';

  @override
  String get playerKeyHintVod =>
      '←→ 10 s  ·  OK Pausa  ·  Segure OK Opções  ·  Voltar Sair';

  @override
  String get playerCamNoSignal => 'Câmera sem sinal';

  @override
  String playerZoomHint(String zoom) {
    return 'Zoom $zoom  ·  ←↑↓→ Mover  ·  OK Alterar zoom  ·  Voltar Concluir';
  }

  @override
  String playerChannelNumber(String number) {
    return 'Canal $number';
  }

  @override
  String playerGuideNow(String title) {
    return 'Agora: $title';
  }

  @override
  String get playerErrorTitle => 'Não foi possível reproduzir este canal';

  @override
  String get playerNextChannel => 'Próximo canal';

  @override
  String get playerBack => 'Voltar';

  @override
  String get settingsAddFromIptvOrg => 'Adicionar do iptv-org';

  @override
  String get settingsAddM3u => 'Adicionar lista M3U por URL';

  @override
  String get settingsRefreshNow => 'Atualizar listas agora';

  @override
  String get settingsAutoRefresh => 'Atualização automática (a cada 24 h)';

  @override
  String get settingsAutoOn => 'Ativada';

  @override
  String get settingsAutoOff => 'Desativada';

  @override
  String get settingsBuffer => 'Buffer de reprodução';

  @override
  String get settingsBufferHint =>
      'Mais segundos = menos travamentos; começa um pouco depois';

  @override
  String get settingsEngine => 'Motor de vídeo';

  @override
  String get settingsEngineAutoHint => 'ExoPlayer e, se falhar, mpv';

  @override
  String get settingsEngineMpvHint => 'Somente mpv (o mais compatível)';

  @override
  String get engineModeAuto => 'Automático';

  @override
  String get engineModeMpv => 'Somente mpv';

  @override
  String get settingsDecoding => 'Decodificação de vídeo (mpv)';

  @override
  String get settingsDecodingAutoHint =>
      'Se um canal 1080p travar com o mpv, experimente \"Sem cópia\"';

  @override
  String get settingsDecodingZeroCopyHint =>
      'Experimental: sem copiar quadros; se não houver imagem, volta ao automático';

  @override
  String get settingsDecodingZeroCopy => 'Sem cópia';

  @override
  String get settingsDecodingAuto => 'Automática';

  @override
  String get settingsTextSize => 'Tamanho da letra';

  @override
  String get settingsTextSizeHint => 'Aumenta os textos de toda a interface';

  @override
  String get settingsHighContrast => 'Alto contraste';

  @override
  String get settingsHighContrastHint =>
      'Texto mais claro e borda de foco amarela mais grossa';

  @override
  String get settingsHideDead => 'Ocultar canais fora do ar';

  @override
  String get settingsHideDeadHint =>
      'Em Canais e Busca (Favoritos sempre os mostra)';

  @override
  String get settingsDeadChannels => 'Canais fora do ar';

  @override
  String get settingsDeadChannelsHint =>
      'São ignorados ao trocar de canal. OK para limpar as marcas';

  @override
  String get settingsDeadNone => 'Nenhum';

  @override
  String settingsDeadCount(int n) {
    return '$n marcados';
  }

  @override
  String get settingsHideAdult => 'Ocultar conteúdo adulto';

  @override
  String get settingsHideAdultHintPin => 'Desativar exige o PIN';

  @override
  String get settingsHideAdultHintNoPin => 'Crie um PIN para protegê-lo';

  @override
  String get settingsPin => 'PIN do controle dos pais';

  @override
  String get settingsPinHint => '4 dígitos; protege o filtro de adultos';

  @override
  String get settingsPinSet => 'Configurado';

  @override
  String get settingsPinNone => 'Sem PIN';

  @override
  String get settingsBackup => 'Cópia de segurança';

  @override
  String get settingsBackupHint =>
      'Exporte ou importe favoritos, listas próprias e configurações';

  @override
  String get settingsEpg => 'Guia personalizado (XMLTV)';

  @override
  String get settingsEpgHint =>
      'Mais canais com guia; soma-se ao dos seus países';

  @override
  String get settingsEpgSet => 'Definida';

  @override
  String get settingsEpgUnset => 'Não definida';

  @override
  String get settingsCamera => 'Câmera de segurança';

  @override
  String get settingsCameraHint =>
      'Aparece como canal e em um quadro (segure OK em um canal)';

  @override
  String get settingsCameraSet => 'Configurada';

  @override
  String get settingsCameraUnset => 'Sem câmera';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageHint => 'Idioma da interface da TV';

  @override
  String get settingsLanguageAuto => 'Automático (sistema)';

  @override
  String get settingsMySources => 'Minhas fontes';

  @override
  String get settingsAlreadyRefreshing =>
      'As listas já estão sendo atualizadas';

  @override
  String get settingsRefreshing => 'Atualizando listas…';

  @override
  String settingsRefreshFailedSome(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listas não puderam ser atualizadas',
      one: '1 lista não pôde ser atualizada',
    );
    return '$_temp0';
  }

  @override
  String get settingsRefreshDone => 'Listas atualizadas';

  @override
  String get settingsRefreshFailed => 'Não foi possível atualizar as listas';

  @override
  String get pinWrong => 'PIN incorreto';

  @override
  String get pinNew => 'Novo PIN';

  @override
  String get pinRepeat => 'Repita o PIN';

  @override
  String get pinMismatch => 'Os PINs não coincidem';

  @override
  String get pinEnter => 'Digite o PIN';

  @override
  String get pinEnterCurrent => 'Digite o PIN atual';

  @override
  String get pinSaved => 'PIN salvo';

  @override
  String get pinRemoved => 'PIN removido';

  @override
  String get pinChange => 'Alterar PIN';

  @override
  String get pinRemove => 'Remover PIN';

  @override
  String get backupExport => 'Exportar cópia';

  @override
  String get backupImportMenu => 'Importar cópia…';

  @override
  String backupSavedTo(String path) {
    return 'Cópia salva em $path';
  }

  @override
  String get backupSaveFailed => 'Não foi possível salvar a cópia';

  @override
  String get backupImportTitle => 'Importar cópia';

  @override
  String get backupFromUrl => 'De uma URL…';

  @override
  String get backupFromPicker => 'De um arquivo do dispositivo…';

  @override
  String get backupImportFromUrlTitle => 'Importar de uma URL';

  @override
  String get backupUrlLabel => 'Endereço da cópia (.json)';

  @override
  String get backupImportConfirm => 'Importar';

  @override
  String get backupNoFile => 'Nenhum arquivo foi escolhido';

  @override
  String get backupImporting => 'Importando…';

  @override
  String backupImported(String summary) {
    return 'Cópia importada: $summary';
  }

  @override
  String get backupImportFailed => 'Não foi possível importar a cópia';

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
      other: '$n listas próprias novas',
      one: '1 lista própria nova',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryPlaylistItems(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canais em listas',
      one: '1 canal em listas',
    );
    return '$_temp0';
  }

  @override
  String backupSummaryCustom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canais próprios',
      one: '1 canal próprio',
    );
    return '$_temp0';
  }

  @override
  String backupSummarySettings(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n configurações',
      one: '1 configuração',
    );
    return '$_temp0';
  }

  @override
  String get backupSummaryNothing => 'Nada novo para importar';

  @override
  String backupSummaryMissing(String base, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n favoritos sem canal',
      one: '1 favorito sem canal',
    );
    return '$base ($_temp0)';
  }

  @override
  String get backupErrInvalidUrl => 'O endereço não é válido';

  @override
  String backupErrDownload(int code) {
    return 'Não foi possível baixar (HTTP $code)';
  }

  @override
  String get backupErrNotBackup => 'O arquivo não é uma cópia válida';

  @override
  String get backupErrNotFred => 'O arquivo não é uma cópia do Fred TV';

  @override
  String get backupErrNoVersion => 'A cópia não indica a sua versão';

  @override
  String get backupErrNewer => 'A cópia é de uma versão mais nova do app';

  @override
  String get epgUrlLabel => 'Endereço (.xml ou .xml.gz); vazio para removê-lo';

  @override
  String get cameraUrlLabel => 'Endereço RTSP; vazio para removê-lo';

  @override
  String get cameraRemoved => 'Câmera removida';

  @override
  String cameraSaved(String name) {
    return 'Câmera salva: procure-a como canal \"$name\" em Favoritos';
  }

  @override
  String get deadClearConfirm => 'Limpar as marcas de canais fora do ar?';

  @override
  String get deadClearAction => 'Limpar';

  @override
  String get sourceRefresh => 'Atualizar';

  @override
  String get sourceDisable => 'Desativar';

  @override
  String get sourceEnable => 'Ativar';

  @override
  String sourceDeleteConfirm(String name) {
    return 'Excluir a fonte \"$name\" e seus canais?';
  }

  @override
  String get sourceDisabled => 'Desativada';

  @override
  String get sourceNeverRefreshed => 'Nunca atualizada';

  @override
  String sourceRefreshedAgo(String ago) {
    return 'Atualizada $ago';
  }

  @override
  String get playlistNameLabel => 'Nome da lista';

  @override
  String get playlistDuplicate => 'Já existe uma lista com esse nome';

  @override
  String get addM3uTitle => 'Adicionar lista M3U';

  @override
  String get addM3uUrlLabel => 'URL da lista M3U';

  @override
  String get addM3uButton => 'Adicionar lista';

  @override
  String get addM3uFillAll => 'Preencha todos os campos';

  @override
  String get addM3uAdding => 'Adicionando lista…';

  @override
  String get addM3uAdded => 'Lista adicionada com sucesso';

  @override
  String get urlMustBeHttp => 'A URL deve começar com http:// ou https://';

  @override
  String get sourceErrUnavailable => 'Esta lista não está disponível';

  @override
  String get sourceErrGeneric => 'Não foi possível adicionar a lista';

  @override
  String get iptvTitle => 'Listas do iptv-org';

  @override
  String get iptvSectionRecommended => 'Recomendados';

  @override
  String get iptvSectionCountries => 'Países';

  @override
  String get iptvSectionCategories => 'Categorias';

  @override
  String get iptvAlreadyAdded => 'Já adicionada';

  @override
  String iptvAdding(String name) {
    return 'Adicionando \"$name\"…';
  }

  @override
  String iptvAdded(String name) {
    return '\"$name\" adicionada';
  }

  @override
  String get iptvLoadFailed =>
      'Não foi possível carregar o catálogo. Verifique sua conexão.';

  @override
  String get iptvKindLanguage => 'Idioma';

  @override
  String get iptvAddedBadge => 'Adicionada';

  @override
  String get iptvAllSpanish => 'Tudo em espanhol';

  @override
  String get iptvCatNews => 'Notícias';

  @override
  String get iptvCatSports => 'Esportes';

  @override
  String get iptvCatKids => 'Infantil';

  @override
  String get iptvCatMovies => 'Filmes';

  @override
  String get iptvCatMusic => 'Música';

  @override
  String get iptvCatDocumentary => 'Documentários';
}

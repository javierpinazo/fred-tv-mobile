import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/backend/user_playlists_sql.dart';

/// Ajuste que marca que los canales de YouTube iniciales ya se crearon (para
/// no recrear los que el usuario borre).
const youtubeSeedSettingKey = 'tvYoutubeSeeded';

/// Lista propia que agrupa los canales de YouTube iniciales.
const youtubePlaylistName = 'YouTube';

/// Canales de YouTube que trae la app, en el orden en que se muestran.
const List<({String name, String url})> defaultYoutubeChannels = [
  (
    name: 'La Encerrona',
    url: 'https://www.youtube.com/channel/UCP0AJJeNkFBYzegTTVbKhPg',
  ),
  (
    name: 'La República',
    url: 'https://www.youtube.com/channel/UC-B7Xv56uNRDkj0vC3QW8Cg',
  ),
  (
    name: 'Curwen',
    url: 'https://www.youtube.com/channel/UCHUD6A_lv3OXbzgVXwomtkw',
  ),
  (
    name: 'Paolo Benza',
    url: 'https://www.youtube.com/channel/UCIpXj6C68YhT8Px3DGCafYA',
  ),
  (
    name: 'Carlos León Moya',
    url: 'https://www.youtube.com/channel/UCw2gXKyj0RcW2qcohj7Gqtg',
  ),
];

/// Crea, una sola vez, los canales de YouTube iniciales (como canales
/// manuales) y la lista propia «YouTube» que los contiene. Reutiliza la lista
/// y los canales de ese nombre que ya existan.
Future<void> ensureYoutubeChannels() async {
  if (await Sql.getSetting(youtubeSeedSettingKey) == '1') return;

  final existing = (await UserPlaylistsSql.all())
      .where((p) => p.name.toLowerCase() == youtubePlaylistName.toLowerCase())
      .firstOrNull;
  final playlistId =
      existing?.id ?? await UserPlaylistsSql.create(youtubePlaylistName);

  for (final c in defaultYoutubeChannels) {
    final channel =
        await Sql.channelByName(c.name, sourceName: customSourceName) ??
            await UserPlaylistsSql.addManualChannel(name: c.name, url: c.url);
    await UserPlaylistsSql.add(playlistId, channel);
  }
  await Sql.setSetting(youtubeSeedSettingKey, '1');
}

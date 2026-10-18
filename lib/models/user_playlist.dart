/// Lista de canales creada por el usuario.
class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.channelCount,
  });

  final int id;
  final String name;

  /// Canales de la lista que existen hoy en alguna fuente.
  final int channelCount;
}

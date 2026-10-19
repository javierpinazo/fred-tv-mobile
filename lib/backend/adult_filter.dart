/// Patrones `LIKE` (sin distinguir mayúsculas en ASCII) de grupos para adultos.
const List<String> adultGroupPatterns = [
  '%xxx%',
  '%adult%',
  '%18+%',
  '%+18%',
  '%nsfw%',
  '%porn%',
  '%erotic%',
  '%erótic%',
];

/// Fragmento SQL "el grupo NO es para adultos" (un `?` por patrón).
String notAdultSql([String column = 'group_name']) =>
    '($column IS NULL OR NOT (${adultGroupPatterns.map((_) => '$column LIKE ?').join(' OR ')}))';

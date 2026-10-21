# Fred TV Mobile

Fred TV for Android and iOS

<a href="https://apps.apple.com/ca/app/open-tv-open-source-iptv/id6742751800">
  <img src="https://raw.githubusercontent.com/Fredolx/open-tv/refs/heads/main/readme_imgs/app-store.svg" width=300 />
</a>
<a href="https://play.google.com/store/apps/details?id=dev.fredol.open_tv">
  <img src="https://raw.githubusercontent.com/Fredolx/open-tv/refs/heads/main/readme_imgs/gplay.png" width=330>
</a>

# Please consider donating on [Github](https://github.com/sponsors/Fredolx), [Patreon](https://www.patreon.com/fredol), [Paypal](https://paypal.me/fredolx) or directly by [crypto](#crypto)

![Screenshot 2025-07-07 at 7 36 14 AM](https://github.com/user-attachments/assets/baf0c53b-a33a-4bb7-bf48-24b8dd20fb20)

---

## Fork: Android TV improvements

This fork adds a remote-friendly interface and makes the app stable on Android TV. On phones and tablets the original mobile interface is still used. Full guide to controls and installation (in Spanish): [ANDROID_TV_README.md](ANDROID_TV_README.md).

**Stable playback**
- **ExoPlayer as the main engine with mpv as a fallback**: if a channel shows no picture, it is retried with hardware mpv and then software mpv. mpv can be forced for all channels or for a single one.
- **Automatic reconnection** on live streams and retries with clear error messages (*Retry*, *Next channel*, *Back*).
- **Configurable buffer** and mpv options that prevent HLS dropouts; fixed audio for HLS streams that declare video only; zero-copy decoding (experimental) with automatic fallback if it fails.
- **Dead channels**: flagged after two consecutive failures, skipped when channel surfing, and can be hidden or cleaned up.

**D-pad control**
- Native focus on every screen, a collapsible side menu and five tabs: Channels, Favorites, My lists, Search and Settings.
- **Built-in keyboard** that works with the remote (with an option to use the system keyboard or voice input).
- **Hold OK** opens the channel options; channel surfing by number, a last-channel key and a *Recent* group.

**Channels and data**
- Add playlists from the **iptv-org** catalog or by M3U URL, with **automatic refresh** every 24 h.
- Your own **lists** (with manually added channels), **country** filter, and exportable/importable **backup**.
- **Program guide (EPG)**: TV Peru and per-country XMLTV, with an optional custom URL.
- **Parental control** with a PIN, **font size** and **high contrast**.
- Android TV integration: a *Favorites* row on the home screen, `fredtv://` links and system search.
- **Multi-language TV interface**: Spanish, English, Portuguese, French, German and Italian. It follows the system language (English if yours isn't available) and can be changed in *Settings → Language*.

**Security camera in a picture-in-picture box**
- Set the RTSP address in *Settings → Security camera* and it shows up as one more channel.
- With any channel on screen, *Hold OK → Show camera* opens it in a small box, without audio; you can **swap it with the channel** on the big screen, **zoom** (1x to 4x with panning) and hide it. It uses its own mpv over TCP and reconnects on its own.

The TV interface is covered by more than 410 automated tests.

**Adding a language:** copy `lib/l10n/app_en.arb` to `app_<code>.arb`, translate the values, add the language name to `languageNativeNames` in `lib/l10n/l10n.dart` and its country names to `lib/backend/country_names_l10n.dart`, then run `flutter gen-l10n`. The phone/tablet interface (original upstream UI) is still English only.

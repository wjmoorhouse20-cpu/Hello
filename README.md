# BigScreen — true full-screen on an external monitor for iPad (A16)

## Why the monitor has black bars

The iPad (A16) **doesn't support extended displays**. When you plug in a monitor,
iPadOS can only *mirror* the iPad's own screen, which is close to 4:3. A 16:9 monitor
then shows black bars on the sides. Apps can't change how iPadOS mirrors.

What an app **can** do is take over the monitor as a real second screen. When
BigScreen is open and a monitor is connected, the monitor stops mirroring and shows
BigScreen's content **edge to edge at the monitor's native resolution** (for example
1920×1080 or 4K). The iPad becomes the remote control.

## What it does

* **No monitor:** a normal web browser on the iPad.
* **Monitor plugged in:** the web page moves onto the monitor and fills it, and the
  iPad turns into:
  * a **trackpad**: drag one finger to move a pointer on the monitor, tap to click,
    drag two fingers to scroll (the pointer hides itself after 3 seconds)
  * an **address bar** with back, forward, reload and quick links
  * a **keyboard box**: click a text field on the monitor, type on the iPad, press Send
    and then ⏎
  * **Fill screen with video**: stretches the main video on any page across the whole
    monitor. Site full-screen buttons, such as YouTube's, also fill the monitor.
  * **Zoom** and **pointer speed** sliders
* The iPad doesn't go to sleep while a monitor is connected.

## Install it

The project is a Swift app package (`BigScreen.swiftpm`).

### Option A — on the iPad itself, with Swift Playgrounds (free)
1. Install **Swift Playgrounds** from the App Store on the iPad.
2. Get the `BigScreen.swiftpm` folder onto the iPad: download this repo as a ZIP from
   GitHub, unzip it in the Files app, and put the folder in *iCloud Drive → Playgrounds*.
3. Open it in Swift Playgrounds and tap **▶ Run**.
4. Plug in the monitor.

> Running an app *inside* Playgrounds may not always take over the external display.
> If the monitor keeps mirroring, use Option B. Option B installs BigScreen as its
> own app.

### Option B — from a Mac with Xcode (free Apple ID works)
1. Open `BigScreen.swiftpm` in Xcode.
2. Under *Signing & Capabilities*, choose your Apple ID team and change the bundle ID
   (for example `com.yourname.bigscreen`).
3. Connect the iPad, select it as the run destination, and press **Run**.
   (On the iPad you may need to trust the developer in *Settings → General → VPN &
   Device Management*, and turn on *Developer Mode*. With a free Apple ID the app
   must be reinstalled every 7 days.)

## Tips and limits

* Many video apps already fill the monitor without black bars once a video is
  playing: YouTube, Netflix, Prime Video, Disney+, Apple TV and Plex.
  Use BigScreen for everything else on the web.
* Some streaming sites block playback of protected video in in‑app browsers.
* The pointer can't click inside embedded frames from other websites.
* Only `https://` sites load.

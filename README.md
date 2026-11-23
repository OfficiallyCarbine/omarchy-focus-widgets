# Focus Widgets for Omarchy

Focus Widgets adds a timer to the top of your screen and puts a few helpful cards on your desktop. It works with Omarchy Linux.

## What you get

- **Focus timer.** Pick how long you want to work and how long you want to rest. One work timer is called a Pomodoro.
- **Timer buttons.** Hover over the timer to find **Start**, **Pause**, **Stop**, **Reset**, and **Skip**. If you're on a break and ready to work again, click **Skip**.
- **Rain sound and a chime.** Play gentle rain while you work, adjust its volume, or turn it off. An optional chime tells you when time is up.
- **Desktop cards.** See the time, calendar, quote of the day, and how long you've focused today and this month.

## How to install

1. On this GitHub page, click **Code**, then **Download ZIP**.
2. Open the ZIP and extract the folder inside.
3. Open a terminal in that folder. Copy this line into the terminal and press Enter.

   ```bash
   bash install.sh
   ```

4. Look near the clock at the top of your screen for the timer. Look at your desktop to see the cards.

Use a running Omarchy desktop with Quickshell plugins. The bundle was prepared for Omarchy 4.5.0-3. You can use it without an administrator password. Rain playback uses `mpv`. The chime uses `paplay`.

## Try your first session

1. Hover over the timer near the clock.
2. Set **Focus duration** to 10 minutes and **Break duration** to 2 minutes.
3. Click **Start** and work on one task.
4. When the timer ends, click **Start** for your break. Click **Skip** if you'd rather go straight to the next focus session.

The timer saves your settings on your computer. The bundled rain sound works offline.

## Want the shared top-bar layout too?

Open a terminal in the same folder and run:

```bash
bash install.sh --bar-layout
```

This puts a see-through bar at the top and arranges the clock, timer, and system icons. It may turn on Omarchy's weather widget, which gets forecasts online. The installer saves a copy of your old shell settings before it makes changes.

## How to turn it off

```bash
omarchy plugin disable local.pomodoro
omarchy plugin disable local.desktop-widgets
```

If you tried the shared bar layout, your old layout is in a backup named `shell.json.focus-widgets.*` in `~/.config/omarchy/`.

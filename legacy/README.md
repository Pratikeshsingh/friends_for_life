# Legacy app

`oldapp/` is the previous VriendTime meetup app (commit e2c4e08, July 2026),
served at https://vriendtime.com/oldapp/. It is a prebuilt Flutter web bundle
made with `--base-href /oldapp/`. The `canvaskit/` folder is left out because
the app loads CanvasKit from Google's CDN.

To rebuild it:

    git worktree add --detach /tmp/oldapp e2c4e08
    cd /tmp/oldapp && flutter pub get
    flutter build web --release --pwa-strategy=none --base-href /oldapp/ \
      --dart-define=SUPABASE_URL=https://sageyiqyvzgoayehahyq.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key from lib/src/core/supabase_config.dart>
    rsync -a --delete --exclude canvaskit --exclude _redirects.txt build/web/ <repo>/legacy/oldapp/

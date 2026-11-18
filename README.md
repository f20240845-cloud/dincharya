# Dincharya

Voice-first daily planner for Android (Flutter, so an iPhone build is possible later).

## What it does

- **Calendar** in the style of Google Calendar: day, 3-day, week and month views with a time grid.
  Timetable classes repeat every week; tasks sit on top, colour-coded by type.
- **Mic to tasks**: speak in English, Hindi or Hinglish. Dates, times, the type of task
  (quiz, lab test, midsem, compre, assignment, or non-study) and the course are picked out
  by on-phone rules. No AI key, no cost.
- **Three marks per task**: tick = 70–100% done, `~` = 20–70%, cross = 0–20%.
- **Add to other days** from any task, and an **evening review** that asks where unfinished tasks go.
- **Study tasks before exams**: a quiz, test, exam or assignment adds a study task some days
  earlier with a reminder at a time you choose.
- **Surprise quiz**: say "DD surprise quiz this week" and every DD class that week is marked.
- **Courses and abbreviations** (Digital Design = DD) and **My words** to correct speech-to-text.
- **Journal**: speak about your day; it is sorted into My day, Interactions, Learnings,
  Keep in mind next time (highlighted) and How I will improve. Share to WhatsApp, ChatGPT, anywhere.
- **Progress**: a GitHub-style grid where days get greener as you finish more.
- **Manifestations**, dark theme by default, local reminders, backup export.

All data stays on the phone in one file.

## Getting the app

Every push to `main` builds an APK with GitHub Actions and publishes it under
**Releases → latest** as `dincharya.apk`. Open that file on the phone to install.
New builds are signed with the same key, so they install over the old one and keep your data.

## Layout

| Path | Purpose |
| --- | --- |
| `lib/parser.dart` | Speech text → task drafts (rules for English, Hindi, Hinglish) |
| `lib/journal_rules.dart` | Journal text → sections |
| `lib/store.dart` | Data, saving, reminders planning |
| `lib/ui/` | Screens |
| `tool/patch_android.py` | Permissions and settings applied to the generated Android project |
| `.github/workflows/build.yml` | The APK build |

The `android/` folder is generated during the build (`flutter create`) and then patched,
so it is not kept in the repository.

## Building on your own computer

```
flutter create --platforms=android --org com.arnav --project-name dincharya /tmp/gen
cp -r /tmp/gen/android ./android
python3 tool/patch_android.py
flutter pub get
flutter test
flutter build apk --release
```

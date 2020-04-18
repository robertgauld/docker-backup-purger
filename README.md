# backup-purger
Purge backups based on a retention policy of latest daily from the last x days, y dailies per week and z weeklies per month.

## To use:
1. Create a configuration JSON file, containing an array of hashes containing the following keys:
  * required:
    * glob STRING - what files/folders should be considered for purging (e.g. "/media/target/my-backups/*")
    * all_from_last_days POSITIVE INTEGER - keep all backups from the last n days
    * dailies POSITIVE INTEGER - keep the earliest backup of the day from the last n days
    * weeklies POSITIVE INTEGER - keep the earliest backup of the week from the last n weeks
    * monthlies POSITIVE INTEGER - keep the earliest backup of the month from the last n months
  * optional:
    * week_start_on POSITIVE INTEGER (default 1) - what day the week starts on (0, Sunday -> 6, Saturday)
    * regexp  STRING default (.*(?<when>\d{4}-\d{2}-\d{2}).*) - a regular expression used to extract the date (with optional time) from a globbed file path, the date/time should be in a capture group named "when". Any poath which doesn't match the regexp will be ignored.
    * strptime STRING default ("%Y-%m-%d") - used by ruby's DateTime strptime method to extract date (and optionally time) from what regexp extracted
2. Connect the following to the mount points:
  * /app/config.json - your configuration
  * /media/target - the folder to store the backups in
3. The following environemtn variables can be used:
  * DRY_RUN - if set to any value will result in nothing happening but a list of which files will be kepf and which deleted being output instead

## Example shell command (replace the stuff in all capitals starting YOUR_):
```bash
docker run --rm --env DRY_RUN=1 --volume="YOUR_PATH_FOR_BACKUPS:/media/target" --volume="TOUR_CONFIG_JSON:/app/config.json" robertgauld/backup-purger:latest

docker run --rm --volume="YOUR_PATH_FOR_BACKUPS:/media/target" --volume="TOUR_CONFIG_JSON:/app/config.json" robertgauld/backup-purger:latest
```

## Example JSON config file:
```json
[
  {
    "glob":"/media/target/my-backups/main-*.tar.gz",
    "regexp":".*main-(?<when>\\d{2}-\\d{2}-\\d{4})\\.tar\\.gz",
    "strptime":"%d-%m-%Y",
    "week_start_on":0,
    "all_from_last_days":4,
    "dailies":7,
    "weeklies":4,
    "monthlies":2
  },
  {
    "glob":"/media/target/other-backups/*.tar.gz",
    "week_start_on":0,
    "all_from_last_days":2,
    "dailies":4,
    "weeklies":2,
    "monthlies":0
  }
]
```

# backup-purger
Purge backups based on a retention policy of latest daily from the last x days, y dailies per week and z weeklies per month.

## To use:
1. Set the following environment variables:
  * ALL_FROM_LAST_DAYS - Keep everything from the last N days (defaults to 7)
  * DAILIES - Keep the latest dailiy from the last N days (defaults to 7)
  * WEEKLIES - Keep the earliest weekly from the last N weeks (defaults to 5)
  * MONTHLIES - Keep the earliest monthly from the last N months (defaults to 6)
  * WEEKLY_ON - The weekly backup is done on day N (0=Sunday defaults to 1)
  * DEBUG - if present then the container runs in debug mode
  * DRY_RUN - if present then the container will say what it would do instead of doing it
2. Connect the following to the mount points:
  * /media/target - the folder to store the backups in

## Example shell commands (replace the stuff in all capitals starting YOUR_):
```
docker run --rm --volume="YOUR_PATH_FOR_BACKUPS:/media/target" robertgauld/backup-purger:latest

docker run --rm --volume="YOUR_PATH_FOR_BACKUPS:/media/target" --env-file="ENV-FILE" robertgauld/backup-purger:latest
```

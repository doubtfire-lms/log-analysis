# To run...

1: Download the production.log file
2: Run script in `extract_ontrack_data.rb` in rails console on production server

  - Download to local folder
    Steps:
    - Move to home on server
    - scp to local machine
      - tasks.csv
      - users.csv
      - units.csv
      - projects.csv
      - tutorials.csv

3: Extract only assessment related activities: 
  - Identify only relevant lines - beware changes of date location
    `sed -nE '/.* assessing task|Started PUT .*projects|Started GET .*portfolio|Started GET "\/api\/units\/.*tasks.inbox|Started GET "\/api\/projects\/.*task_def_id.*submission_details/p' production.log > stage1.log`
  - Strip date from before "Started"
    `cat stage1.log | gawk 'match($0, /^20.*INFO: (.*)$|^(.*)$/, a) {print a[1]a[2]}' > stage2.log`
  - `cat stage2.log | gawk 'match($0, /Started (PUT) .*\/projects\/([0-9]+)["?].* for (.*) at (.*)(\+|-)[0-9].*$|Started (GET) .*\/([0-9]+)\/.*\/(inbox).* for (.*) at (.*)(\+|-)[0-9].*$|Started (GET|PUT) .*\/([0-9]+)\/.*\/([0-9]+)["/?].* for (.*) at (.*)(\+|\-)[0-9].*$|^(.*) (assessing) task ([0-9]+) to (.*)$/, a) {print a[1] a[6] a[12] a[19] "," a[2] a[7] a[13] a[18] "," a[8] a[14] a[20] "," a[3] a[9] a[15] "," a[4] a[10] a[16]}' > ontrack-time-data-3.csv`
4: Run `bundle exec ruby assessment_time.rb`
5: Copy formulas from other xlsx versions


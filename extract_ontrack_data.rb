# Run from rails console.

# Extract project data
CSV.open("#{Dir.home}/projects.csv", "wb") do |csv|
  csv << ["project_id", "unit_id", "user_id"]
  Project.all.each {|p| csv << [p.id, p.unit_id, p.user_id]}
  true
end

# Extract unit data
CSV.open("#{Dir.home}/units.csv", "wb") do |csv|
  csv << ["unit_id", "name", "code", "student_count"]
  Unit.all.each {|u| csv << [u.id,u.name,u.code,u.active_projects.count]}
  true
end

# Extract unit data
CSV.open("#{Dir.home}/tutorials.csv", "wb") do |csv|
  csv << ["unit_id", "user_id", "code", "student_count", "stream"]
  Tutorial.all.each {|t| csv << [t.unit_id,(t.tutor.id unless t.tutor.nil?),t.abbreviation,t.num_students, t.tutorial_stream.id unless t.tutorial_stream.nil?]}
  true
end

# Extract Users
roles = {}

Role.all.each {|r| roles[r.id] = r.name }

CSV.open("#{Dir.home}/users.csv", "wb") do |csv|
  csv << ["id","username","name","role"]
  User.all.each {|u| csv << [u.id, u.username, u.name, roles[u.role_id]]}
  true
end

# Extract Tasks
CSV.open("#{Dir.home}/tasks.csv", "wb") do |csv|
  csv << ["id","project_id","task_def_id","stream"]
  Task.all.each {|t| csv << [t.id,t.project_id,t.task_definition_id,t.tutorial_stream_id]}
  true
end

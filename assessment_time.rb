require 'csv'
require 'date'
require 'byebug'

# The number of minutes we can accept for a single student assessment
THRESHOLD = 15

class User
  def initialize
    @username = nil
    @name = nil
    @role = nil
    @id = nil
  end

  def id
    @id
  end

  def id= value
    @id = value
  end

  def username
    @username
  end

  def username= value
    @username = value
  end

  def name
    @name
  end

  def name= value
    @name = value
  end

  def role
    @role
  end

  def role= value
    @role = value
  end
end

class TaskDefinition
  @id

  def id
    @id
  end

  def id= value
    @id = value
  end
end

class Task
  def initialize
    @task_def = nil
    @id = nil
    @project = nil
    @activity = []
  end

  def task_def
    @task_def
  end

  def task_def= value
    @task_def = value
  end

  def id
    @id
  end

  def id= value
    @id = value
  end

  def project
    @project
  end

  def project= value
    @project = value

    @project.add_task self
  end

  def activity
    @activity
  end

  def add_activity value
    @activity << value
  end

  def last_put_activity
    @activity.length.times do |i|
      result = @activity[@activity.length - i - 1]
      return result if result.action == 'PUT'
    end
    nil
  end
end

class Tutorial
  @unit = nil
  @tutor = nil
  @code = nil
  @student_count = 0

  def initialize unit, tutor, code, count
    @unit = unit
    @tutor = tutor
    @code = code
    @student_count = count
  end

  def tutor
    @tutor
  end

  def code
    @code
  end

  def student_count
    @student_count
  end
end

class Unit
  @id = nil
  @name = nil
  @projects = []
  @code = nil
  @student_count = 0
  @task_defs = {}

  @sessions = []
  @markers = {}

  @tutorials = []

  def initialize
    @projects = []
    @sessions = []
    @task_defs = {}
    @markers = {}
    @tutorials = []
  end

  def name
    @name
  end

  def name= value
    @name = value
  end

  def id
    @id
  end

  def id= value
    @id = value
  end

  def code
    @code
  end

  def code= value
    @code = value
  end

  def student_count
    @student_count
  end

  def student_count= value
    @student_count = value.to_i
  end

  def add_project project
    @projects << project
  end

  def add_tutorial tutorial
    @tutorials << tutorial
  end

  def task_def_for_id task_id
    return @task_defs[task_id] if @task_defs.has_key? task_id
    result = TaskDefinition.new
    result.id = task_id
    @task_defs[task_id] = result
    result
  end

  def add_session session
    @sessions << session
  end

  def report_summary(stream)
    return if @sessions.length == 0
    # puts "Sessions #{@name} length: #{@sessions.length}"

    total_duration = @sessions.inject(0){|sum,e| sum + e.duration }
    total_assessments = @sessions.inject(0){|sum,e| sum + e.number_assessments }

    stream.write "#{@id},all,#{@code},\"#{@name}\",#{student_count},#{total_duration},#{total_assessments},#{ (total_duration / 60.0) / student_count}\n"

    @sessions.group_by(&:marker).each do |k,v|
      # Get tutorials for marker
      marker_tutorials = @tutorials.select{|t| t.tutor == k }      
      total_students = marker_tutorials.inject(0){|sum,e| sum + e.student_count } unless marker_tutorials.length == 0
      total_students = 1 if total_students.nil? || total_students <= 0
      marker_duration = v.inject(0){|sum,e| sum + e.duration }
      marker_assessments = v.inject(0){|sum,e| sum + e.number_assessments }

      tutor_name = k.nil? ? "none" : k.name

      stream.write "#{@id},#{tutor_name},#{@code},\"#{@name}\",#{total_students},#{marker_duration},#{marker_assessments},#{ (marker_duration / 60.0) / total_students}\n"
    end
  end

  def report_session_details stream
    return if @sessions.length == 0

    stream.write("\nDetails for #{@code} #{@name} (#{@id})\n")
    @sessions.group_by(&:marker).each do |k,v|
      tutor_name = k.nil? ? "none" : k.name

      stream.write("activity for #{tutor_name} in #{@code} #{@name}\n")

      v.each do |session|
        stream.write("  #{session.start_time} - #{session.end_time} (#{session.duration} minutes)\n")
        
        session.activity_log.each do |activity|
          stream.write("    #{activity.action} #{activity.task_def&.id} #{activity.project&.id} #{activity.time_stamp}\n")
        end
      end
    end
  end
end

class MarkingSession
  @start_time = nil
  @marker = nil
  @unit = nil
  @end_time = nil
  @number_assessments = 0
  @duration = nil
  @activity_log = []

  def initialize
    @number_assessments = 0
    @duration = 0
  end

  def number_assessments
    @number_assessments
  end

  def marker
    @marker
  end

  def duration
    @duration
  end

  def activity_log
    @activity_log
  end

  def start_time
    @start_time
  end

  def end_time
    @end_time
  end

  def set_details start_time, marker, unit, end_time, num_assessments, duration, activity_log
    @start_time = start_time
    @marker = marker
    @unit = unit
    @end_time = end_time
    @number_assessments = num_assessments
    @duration = duration
    @activity_log = activity_log

    @unit.add_session self
  end
end

class IPAddressActivity
  def initialize
    @ip_address = nil
    @activity = []
  end

  def add_activity value
    @activity << value
  end

  def record_end_session start_time, marker, unit, end_time, num_assessments, activity_log
    name = marker.name unless marker.nil?
    duration = ((end_time - start_time) * 24 * 60).to_i

    return if duration == 0

    session = MarkingSession.new
    session.set_details start_time, marker, unit, end_time, num_assessments, duration, activity_log

    # puts "#{unit.id},#{unit.code},#{name},#{start_time},#{end_time},#{num_assessments},#{duration}" # if !marker.nil? && marker.id == "13883"
  end

  def record_assessment_activity_to_tasks
    post_inbox = false
    marker = nil
    session_start = nil
    unit = nil
    prev = nil
    num_assessments = 0

    activity_log = []

    # puts "-----------"
    @activity.each do |activity|
      session_start = activity.time_stamp if session_start.nil?

      # look for end conditions first...
      # is after inbox.... and either timeout, or assessed by different user, or change of unit
      if post_inbox && (
          (prev != nil && activity.time_diff(prev) > THRESHOLD) || 
          (activity.action == "assessing" && (activity.user == activity.project.user || marker != nil && activity.user != marker)) || 
          (activity.project != nil && activity.project.unit != unit) )
        # end the session with what we have already recorded
        # puts "NEW SESSION - #{num_assessments}"
        record_end_session session_start, marker, unit, prev.time_stamp, num_assessments, activity_log

        activity_log = []
        post_inbox = false
        marker = nil
        session_start = nil
        unit = nil
        prev = nil
        num_assessments = 0
      end

      activity_log << activity

      # Now read this activity...
      unless post_inbox # if it is not post inbox - we are looking for a start
        # puts activity.action
        # Looking for start or marker activity on this IP address
        if activity.action == 'inbox'
          # inbox request marks start... we wont know who yet
          post_inbox = true
          session_start = activity.time_stamp
          unit = activity.unit
          prev = activity
        elsif (activity.action == "assessing") && activity.user != activity.project.user
          # marker updated task... lets mark start of session here...
          # TODO: Look back for start of session?
          post_inbox = true
          session_start = activity.time_stamp
          unit = activity.project.unit
          prev = activity

          marker = activity.user
          num_assessments = 1 # this was an assessment
        end
      else # this is part of the session...
        # within marking timeframe... assume this is part of the sequence
        prev = activity

        # puts "#{activity.action} ... #{activity.action == "assessing"}"

        if activity.action == "assessing"
          # puts "IN ASSESSING"
          # ASAP get the details of the tutor - from the first assessment post inbox
          if marker.nil? # cant be user as that would end the post inbox
            marker = activity.user
          end

          # we assessed a task -- count this
          num_assessments += 1
          # puts num_assessments
        end
      end 
    end

    # All activities done... do we need to record end of this session?
    if post_inbox
      # puts "POST INBOX - #{num_assessments}"
      record_end_session session_start, marker, unit, prev.time_stamp, num_assessments, activity_log
    end
  end

  def activity
    @activity
  end
end

class AssessmentActivity
  def initialize
    @action = nil
    @project = nil
    @unit = nil
    @user = nil
    @time_stamp = nil
    @ip_address = nil
    @task_def = nil

    @ip_self_idx = 0
    @project_self_idx = 0
  end

  def task_def
    @task_def
  end

  def task_def= value
    @task_def = value
  end

  def unit
    @unit
  end

  def unit= value
    @unit = value
  end

  def project
    @project
  end

  def project= value
    @project = value
  end

  def action
    @action
  end

  def action= value
    @action = value
  end

  def time_stamp
    @time_stamp
  end

  def time_stamp= value
    @time_stamp = value
  end

  def user
    @user
  end

  def user= value
    @user = value
  end

  # def project_self_idx
  #   @project_self_idx
  # end

  # def project_self_idx= value
  #   @project_self_idx = value
  # end

  def ip_address
    @ip_address
  end

  def ip_address= value
    @ip_address = value
  end

  def load csv, projects, tasks, units, ip_addresses, users
    puts csv.inspect
    @action = csv[0]

    if @action =~ /GET|PUT/
      if csv[2] == 'inbox'
        @unit = units[csv[1]]
        @action = 'inbox'
        throw csv if @unit.nil?
      else
        @project = projects[csv[1]]
        @task_def = @project.unit.task_def_for_id csv[2]
      end
      @ip_address = csv[3]
      @time_stamp = DateTime.parse csv[4]
    elsif @action == 'assessing'
      # byebug
      task = tasks[csv[2]] # get task from id
      return if task.nil? # Some old tasks deleted - cannot find matching data

      @user = users[csv[1]]
      @project = task.project
      @task_def = task.task_def
      
      last_put = task.last_put_activity
      if last_put.nil?
        puts "no last put - #{csv.inspect}"
        @ip_address = ''
        @time_stamp = ''
      else
        @ip_address = last_put.ip_address
        @time_stamp = last_put.time_stamp
      end
    end

    unless @project.nil?
      @project_self_idx = @project.add_activity(self)
      unless @task_def.nil?
        # record action against task - enable find activity for task
        td = @project.task_for_task_def(@task_def.id)
        td.add_activity(self) unless td.nil? # Some old tasks deleted - link lost
      end
    end

    ip_addresses[@ip_address] = IPAddressActivity.new unless ip_addresses.has_key? @ip_address
    ip_addresses[@ip_address].add_activity(self)
    @ip_self_idx = ip_addresses[@ip_address].activity.length - 1
  end

  def time_diff other
    ((@time_stamp - other.time_stamp) * 24 * 60).to_i
  end

  # def elapsed_minutes
  #   return 0 if @project_self_idx == 0 # no time for first activity
    
  #   prev_activity = @project.next_activity self, -1
  #   tmp = time_diff prev_activity

  #   return 0 unless tmp < THRESHOLD
  #   tmp
  # end
end

class Project
  def initialize
    @id = nil
    @unit = nil
    @activity = {}
    @user = nil
    @tasks = {}
  end

  def unit
    @unit
  end

  def unit=value
    @unit = value
    @unit.add_project(self)
  end

  def user
    @user
  end

  def user=value
    @user = value
  end

  def id
    @id
  end

  def id=value
    @id = value
  end

  def tasks
    @tasks
  end

  def tasks=value
    @tasks = value
  end

  def add_task value
    @tasks[value.task_def.id] = value
  end

  def task_for_task_def task_def_id
    @tasks[task_def_id]
  end

  def add_activity value
    @activity[value.ip_address] = {} unless @activity.has_key? value.ip_address

    @activity[value.ip_address][value.task_def.id] = [] unless @activity.has_key? value.task_def.id

    @activity[value.ip_address][value.task_def.id] << value
    @activity[value.ip_address][value.task_def.id].length - 1 # return index of assessment activity 
  end

  # Return the activity relative to a given activity (based on offset)
  def next_activity value, offset
    arr = @activity[value.ip_address][value.task_def.id]
    arr_idx = value.project_self_idx + offset
    # Check valid index
    return nil if arr_idx < 0 || arr_idx >= arr.length
    # Return relative value
    arr[arr_idx]
  end
end

class LogFile
  def initialize
    @users_by_id = {}
    @users_by_username = {}
    @units = {}
    @projects = {}
    @ip_addresses = {}
  end

  def load_users
    puts 'loading users'
    CSV.foreach('users.csv', :headers => true) do |csv|
      result = User.new()
      result.id = csv[0]
      result.username = csv[1]
      result.name = csv[2]
      result.role = csv[3]
  
      @users_by_id[csv[0]] = result
      @users_by_username[csv[1]] = result

      # puts "Add user #{result.id} = #{result.name} #{result.role}"
    end
  end

  def load_units
    puts 'loading units'

    CSV.foreach('units.csv', :headers => true) do |csv|
      result = Unit.new()
      result.id = csv[0]
      result.name = csv[1]
      result.code = csv[2]
      result.student_count = csv[3]
  
      @units[csv[0]] = result
      # puts "Add unit #{result.id} = #{result.name}"
    end
  end

  def load_tutorials
    puts 'loading tutorials'

    CSV.foreach('tutorials.csv', :headers => true) do |csv|
      unit = @units[csv[0]]
      tutor = @users_by_id[csv[1]]
      result = Tutorial.new(unit, tutor, csv[2], csv[3].to_i)

      unit.add_tutorial(result)
  
      # puts "Add tutorial #{result.code} = #{result.tutor.name} #{result.student_count}"
    end
  end

  def load_projects
    puts 'loading projects'

    CSV.foreach('projects.csv', :headers => true) do |csv|
      result = Project.new()
      result.id = csv[0]
      result.unit = @units[csv[1]]
      result.user = @users_by_id[csv[2]]
  
      @projects[csv[0]] = result
      # puts csv.inspect
      # puts result.inspect
      # puts "Add project #{result.id} to #{result.unit.code} for #{result.user.name}"
    end
  end
  
  def load_tasks
    puts 'loading tasks'
    @tasks = {}

    CSV.foreach('tasks.csv', :headers => true) do |csv|
      project = @projects[csv[1]]
      result = Task.new()
      result.id = csv[0]
      result.task_def = project.unit.task_def_for_id csv[2]
      result.project = project # must be after loading task def as this links them together

      @tasks[result.id] = result

      # @tasks[csv[0]] = result
      # puts "Add task #{result.id} to #{result.project.unit.code} for #{result.project.user.name}"
    end
  end

  def process file_name
    CSV.foreach(file_name) do |csv|
      result = AssessmentActivity.new
      result.load csv, @projects, @tasks, @units, @ip_addresses, @users_by_username
    end
  end

  def report_time
    # Build the time data from each ip address
    @ip_addresses.values.each do |ip_addr|
      ip_addr.record_assessment_activity_to_tasks
    end

    # Report unit times
    

    date = DateTime.now

    puts
    puts "activity summay"
    File.open("activity_summary_#{date}.log", "w") do |stream|
      stream.write "id,assessor,unit code,unit name,students,minutes,assessments,hours/student\n"
      @units.values.each do |unit|
        print "."
        unit.report_summary(stream)
      end
      puts " done"
    end

    puts
    puts "activity details"
    File.open("activity_details_#{date}.log", "w") do |stream|
      # Report activity details
      @units.values.each do |unit|
        print "."
        unit.report_session_details(stream)
      end
      puts " done"
    end
  end
end

# byebug
log = LogFile.new()
log.load_users()
log.load_units()
log.load_projects()
log.load_tasks()
log.load_tutorials()

log.process('ontrack-time-data-3.csv')

log.report_time()

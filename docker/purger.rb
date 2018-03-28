#!/usr/bin/env ruby

# Purges old backups in a directory.
# Directories named by date and time eg 20101112-0456 for 4:56 AM on 12 Nov 2010

require 'date'
require 'fileutils'
require 'optparse'



class Purger

  attr_reader :dailies, :weeklies, :monthlies, :all_from_last_days, :debug, :dry_run, :weekly_on

  def initialize
    @dailies = 7
    @weeklies = 5
    @monthlies = 6
    @all_from_last_days = 7
    @debug = false
    @dry_run = false
    @weekly_on = 1

    if debug?
      puts "Arguments:\t#{ARGV}"
      puts "Keeping all from the last #{all_from_last_days} days."
      puts "Keeping the latest from each day for #{dailies} days."
      puts "Keeping the earliest for each week for #{weeklies} weeks.."
      puts "Keeping the earliest for each month for #{monthlies} months."
      puts "Weekly backups are the ones done on day #{weekly_on} (#{Date::DAYNAMES[weekly_on]})."
      puts "Doing a dry run." if dry_run?
      puts
    end
  end

  def debug?
    @debug
  end
  def dry_run?
    @dry_run
  end
  def wet_run?
    !@dry_run
  end

  def dailies=(val)
    @dailies = val.to_i
  end
  def weeklies=(val)
    @weeklies = val.to_i
  end
  def monthlies=(val)
    @monthlies = val.to_i
  end
  def all_from_last_days=(val)
    @all_from_last_days = val.to_i
  end
  def weekly_on=(val)
    @weekly_on = val.to_i % 7
  end
  def debug=(val)
    @debug = !!val
  end
  def dry_run=(val)
    @dry_run = !!val
  end


  def run(directory)
    puts "Running in #{directory}" if debug?
    today = Date.today
    daily_from = today - (dailies - 1)
    weekly_from = today - (weeklies * 7)
    monthly_from = today << monthlies
    keep_all_after = today - all_from_last_days

    # Get lists of backups
    files = Dir.entries(directory)
    files.select!{ |i| i.match(/\d{8}-\d{4}/) && File.directory?("#{directory}/#{i}") }
    files.sort!
    files.map! do |file|
      date, time = file.match(/(\d{8})-(\d{4})/).captures
      day = Date.strptime(date, '%Y%m%d')
      week = day - day.wday + weekly_on
      week -= 7 if day.wday < weekly_on
      month = day - day.day + 1
      month = month.strftime('%Y%m')
      {
        file_name: file,
        file_path: "#{directory}/#{file}",
        day: day,
        week: week,
        month: month,
        time: time,
        keep: false,
      }
    end # map files

    # Find which backups to delete
    # We want to keep any backup since config['all_from_last_days']
    puts if debug?
    files.select{ |data| data[:day] >= keep_all_after }.each do |data|
      puts "Keeping #{data[:file_name]} - made in last #{config['all_from_last_days']} days." if debug?
      data[:keep] = true
    end
    # We want to keep the latest of each day for the last config['dailies'] days
    files.select{ |data| data[:day] >= daily_from }.group_by{ |data| data[:day] }.each do |day, datas|
      data = datas[-1]
      puts "Keeping #{data[:file_name]} - daily." if debug?
      data[:keep] = true
    end
    # We want to keep the earliest from each week for the last config['weeklies'] weeks
    files.select{ |data| data[:day] >= weekly_from }.group_by{ |data| data[:week] }.each do |week, datas|
      data = datas[0]
      puts "Keeping #{data[:file_name]} - weekly." if debug?
      data[:keep] = true
    end
    # We want to keep the earliest from each month for the last config['monthlies'] months
    files.select{ |data| data[:day] >= monthly_from }.group_by{ |data| data[:month] }.each do |week, datas|
      data = datas[0]
      puts "Keeping #{data[:file_name]} - monthly." if debug?
      data[:keep] = true
    end

    # List files if debugging
    if debug?
      puts
      files.each do |data|
        puts "#{data[:file_path]}\t#{data[:keep] ? 'KEEP' : 'delete'}"
      end
      puts
    end

    # Delete old backups
    files.select{ |data| !data[:keep] }.each do |data|
      file = data[:file_path]
      if dry_run?
        puts "Would delete #{file}"
      else
        puts "Deleting #{file}" if debug?
        FileUtils.rm_rf(file)
      end
    end

  end # def run
end # class Purger



# Only run the below code if the file is being executed rather than included
if __FILE__ == $0
  directory = nil
  purger = Purger.new
  purger.debug = true if ENV['DEBUG']
  purger.dry_run = true if ENV['DRY_RUN']
  purger.dailes = ENV['DAILES'] if ENV['DAILES']
  purger.weeklies = ENV['WEEKLIES'] if ENV['WEEKLIES']
  purger.monthlies = ENV['MONTHLIES'] if ENV['MONTHLIES']
  purger.all_from_last_days = ENV['ALL_FROM_LAST_DAYS'] if ENV['ALL_FROM_LAST_DAYS']
  purger.weekly_on = ENV['WEEKLY_ON'] if ENV['WEEKLY_ON']

  opt_parser = OptionParser.new do |opt|
    opt.banner = "Usage: #{$0} [OPTIONS]"

    opt.separator ""
    opt.on("--directory=D", 'The directory to work in. MANDATORY') do |d|
      directory = d
    end

    opt.separator "\nWhat to keep"

    opt.on("--all-from-last-days=N", "Keep everything from the last N days (default #{purger.all_from_last_days}).") do |n|
      purger.all_from_last_days = n
    end
    opt.on("--dailies=N", "Keep the latest dailiy from the last N days (default #{purger.dailies}).") do |n|
      purger.dailies = n
    end
    opt.on("--weeklies=N", "Keep the earliest weekly from the last N weeks (default #{purger.weeklies}).") do |n|
      purger.weeklies = n
    end
    opt.on("--monthlies=N", "Keep the earliest monthly from the last N months (default #{purger.monthlies}).") do |n|
      purger.monthlies = n
    end


    opt.separator "\nOptions"

    opt.on("--weekly_on=N", "The weekly backup is done on day N (0=Sunday default #{purger.weekly_on}).") do |n|
      purger.weekly_on = n
    end

    opt.on("--[no-]verbose", "--[no-]debug", "Debug/Verbose mode.") do |v|
      purger.debug = v
    end

    opt.on("--[no-]dry-run", "Dry run mode.") do |v|
      purger.dry_run = v
    end

    opt.on("-?", "-h", "--help", "Display usage instructions and exit.") do
      puts opt_parser
      exit
    end
  end
  opt_parser.parse(ARGV)

  if directory.nil?
    puts "You must provide a directory to work in."
    puts opt_parser
    exit(1)
  end
  unless File.directory?(directory)
    puts "#{directory} is not a directory!"
    puts opt_parser
    exit(1)
  end

  purger.run(directory)
end

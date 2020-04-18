# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'logger'

# Each purger takes the result of a Dir.glob, filters by regexp,
# keeps by passed options and deletes the rest of the filtered files/dirs.
class Purger
  Item = Struct.new(:path, :date_time, :keep)

  def initialize(
    glob:,
    all_from_last_days:,
    dailies:,
    weeklies:,
    monthlies:,
    week_start_on: 1,
    regexp: /.*(?<when>\d{4}-\d{2}-\d{2}).*/,
    strptime: '%Y-%m-%d'
  )
    @glob = glob
    @regexp = regexp
    @strptime = strptime
    @all_from_last_days = all_from_last_days
    @dailies = dailies
    @weeklies = weeklies
    @monthlies = monthlies
    @week_start_on = week_start_on
    @logger = $logger || Logger.new('/dev/null')
    @logger.debug "Initialized purger for #{glob}"
  end

  def run
    logger.info "Starting purge of #{glob}"
    get_items.each { |item| logger.debug "#{item.keep ? 'Keeping' : 'Purging'} #{item.path}" }
             .reject(&:keep)
             .each { |item| logger.info "Removing #{item.path}"; FileUtils.rm_rf item.path }
  end

  def dry_run
    items = get_items.group_by(&:keep)

    puts 'Would keep:'
    items[true]&.each { |item| puts "\t#{item.path}" }

    puts 'Would delete:'
    items[false]&.each { |item| puts "\t#{item.path}" }
  end

  private

  attr_reader :glob, :regexp, :strptime, :week_start_on,
              :all_from_last_days, :dailies, :weeklies, :monthlies,
              :logger

  # rubocop:disable Naming/AccessorMethodName
  def get_items
    items = Dir.glob(glob).map { |item| [item, regexp.match(item)] }
               .reject { |_item, match| match.nil? }
               .map { |item, match| Item.new item, DateTime.strptime(match[:when], strptime), false }
               .sort_by(&:date_time)
    logger.debug "Found items: #{items.inspect}"

    # Mark all items from the last #all_from_last_days days for keeping
    if all_from_last_days.positive?
      since = Date.today - all_from_last_days
      items.select { |item| item.date_time >= since }
           .each { |item| item.keep = true }
    end

    # Keep the earliest of each day for the last #dailies days
    if dailies.positive?
      since = Date.today - dailies
      items.select { |item| item.date_time >= since }
           .group_by { |item| item.date_time.strftime('%Y%m%d') }
           .each { |_day, list| list.first.keep = true }
    end

    # Keep the earliest of each week for the last #weeklies weeks
    if weeklies.positive?
      since = Date.today - (weeklies * 7)
      items.select { |item| item.date_time >= since }
           .group_by { |item| item.date_time.to_date - ((item.date_time.wday - week_start_on) % 7) }
           .each { |_week_start, list| list.first.keep = true }
    end

    # Keep the earliest of each month for the last #monthlies months
    if monthlies.positive?
      since = Date.today << monthlies
      items.select { |item| item.date_time >= since }
           .group_by { |item| item.date_time.strftime('%Y%m') }
           .each { |_month, list| list.first.keep = true }
    end

    items
  end
  # rubocop:enable Naming/AccessorMethodName
end

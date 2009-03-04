require 'rubygems'
require 'activeresource'

HARVEST_CONFIG = {
  :email => "brandon@collectiveidea.com",
  :password   => "…",
  :sub_domain => "collectiveidea"
}
PIVOTAL_TOKEN = '…'

class PivotalReport

  class Story < ActiveResource::Base
    self.site = "http://www.pivotaltracker.com/services/v2/projects/:project_id"
    headers['X-TrackerToken'] = PIVOTAL_TOKEN
  end
  
  def initialize(project_id)
    @project_id = project_id
  end
  
  def begin_at
    iterations.map(&:start).sort.first
  end
  
  def end_at
    iterations.map(&:finish).sort.last
  end
  
  def iterations
    @iterations ||= completed_stories.inject([]) do |iterations,story|
      iterations[story.iteration.number.to_i] = story.iteration
      iterations
    end.compact
  end
  
  def completed_stories
    @completed_stories ||= Story.find(:all, :params => {:filter => 'state:accepted includedone:true type:feature', :project_id => @project_id, :limit => 1000})
  end
  
  def scheduled_stories
    @scheduled_stories ||= Story.find(:all, :params => {:filter => 'state:!accepted includedone:true type:feature', :project_id => @project_id, :limit => 1000})
  end
  
  def completed_points
    completed_stories.sum {|s| s.estimate }
  end
end

require 'harvest'
class HarvestReport
  def initialize(project_id, date_range)
    @harvest = Harvest(HARVEST_CONFIG)

    @project = @harvest.projects.find(project_id)
    @date_range = date_range
  end
  
  def entries
    @entries ||= @project.entries :from => @date_range.first, :to => @date_range.last
  end
  
  def hours
    entries.sum {|e| e.hours }
  end
end

@pivotal = PivotalReport.new(4396)
@harvest = HarvestReport.new(250835, @pivotal.begin_at..@pivotal.end_at)

puts "Completed Story Points: #{@pivotal.completed_points}"
puts "Hours: #{@harvest.hours}"
puts "Hours/Point: %.2f" % (@harvest.hours.to_f/@pivotal.completed_points)

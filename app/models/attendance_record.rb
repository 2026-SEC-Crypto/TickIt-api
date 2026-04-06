require 'json'
require 'securerandom'
require 'fileutils'

module TickIt
  class AttendanceRecord
    attr_reader :id, :student_id, :timestamp, :location, :status

    def initialize(params)
      @id = params[:id] || new_id
      @student_id = params[:student_id]
      @timestamp = params[:timestamp] || Time.now.to_i
      @location = params[:location]
      @status = params[:status]
    end

    def new_id
      SecureRandom.hex(8)
    end

    def to_json(options = {})
      JSON.generate({
        id: @id,
        student_id: @student_id,
        timestamp: @timestamp,
        location: @location,
        status: @status
      })
    end

    def save
      FileUtils.mkdir_p('app/db/store')
      File.write("app/db/store/#{@id}.txt", to_json)
    end

    def self.find(id)
      path = "app/db/store/#{id}.txt"
      return nil unless File.exist?(path)
      data = JSON.parse(File.read(path), symbolize_names: true)
      new(data)
      
    end

    def self.all
      Dir.glob('app/db/store/*.txt').map do |file|
        File.basename(file, ".txt")
      end
    end
  
  end
end
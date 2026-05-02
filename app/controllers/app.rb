# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../../lib/security_log'
require_relative '../models/event'
require_relative '../models/attendance_record'
require_relative '../models/account'
require_relative '../services/event_service'
require_relative '../services/account_service'
require_relative '../services/attendance_record_service'

module TickIt
  class Api < Roda
    plugin :halt
    plugin :multi_route

    # 自動載入 routes 目錄下的所有路由檔案
    Dir.glob(File.expand_path('routes/*.rb', __dir__)).each do |file|
      require file
    end

    route do |r|
      response['Content-Type'] = 'application/json'

      # 強制 SSL (HTTPS) 連線檢查
      if ENV['RACK_ENV'] == 'production' && r.scheme != 'https'
        response.status = 403
        r.halt({ error: 'Secure connection (HTTPS) is required' }.to_json)
      end

      begin
        r.root do
          { message: 'TickIt API is up and running!' }.to_json
        end

        r.on 'api' do
          r.on 'v1' do
            # 將請求分發給對應的子檔案處理
            r.on('events')      { r.route 'events' }
            r.on('attendances') { r.route 'attendances' }
            r.on('students')    { r.route 'students' }
            r.on('accounts')    { r.route 'accounts' }
            r.on('auth')        { r.route 'auth' }
          end
        end

        response.status = 404
        { error: 'Route not found' }.to_json
      rescue StandardError => e
        TickIt::SecurityLog.log_error(e, path: r.path, method: r.request_method)
        response.status = 500
        { error: 'Internal server error' }.to_json
      end
    end
  end
end
